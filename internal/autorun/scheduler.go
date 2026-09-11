package autorun

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"cuit-server/internal/autorun/store"
	"cuit-server/internal/autorun/upstream"
)

const (
	refreshInterval     = 4 * time.Hour
	refreshRetry        = 30 * time.Minute
	expiredSessionRetry = 6 * time.Hour
	probeRetry          = 2 * time.Minute
	eventWindowGrace    = 3 * time.Minute
)

type schedulerRepository interface {
	ListSchedulesNeedingRefresh(context.Context, string, time.Time, int, ...time.Duration) ([]store.Schedule, error)
	ClaimScheduleRefreshes(context.Context, []int64, string, time.Time, ...time.Duration) ([]int64, error)
	ClaimDueEvents(context.Context, time.Time, int, time.Duration, ...time.Duration) ([]store.Event, error)
	ExpireOverdueEvents(context.Context, time.Time) (int64, error)
	GetSchedule(context.Context, int64) (*store.Schedule, error)
	GetEvent(context.Context, int64, string) (*store.Event, error)
	GetSessionByKey(context.Context, string) (*store.Session, error)
	GetSessionByStudentID(context.Context, int64) (*store.Session, error)
	ReplaceScheduleEvents(context.Context, int64, string, []store.Event, time.Time, time.Time) error
	DeferScheduleRefresh(context.Context, int64, string, time.Time, string, time.Time) error
	DeferScheduleEvent(context.Context, int64, string, time.Time) error
	ExpireEvent(context.Context, int64, string) error
	UpdateScheduleRuntime(context.Context, int64, store.ScheduleRuntimeUpdate) error
	TryClaimAction(context.Context, int64, string, time.Time, ...time.Duration) (bool, error)
	IsActionComplete(context.Context, int64, string) (bool, error)
	CompleteScheduledAction(context.Context, int64, string, store.SignType, time.Time, string) error
}

type scheduledMutationClient interface {
	SignInOrSignBackWithKey(context.Context, string, string, upstream.SignRequestBody) (string, error)
}

type schedulerUpstreamClient interface {
	GetSignInTf(context.Context, string, int64) (*upstream.SignInTf, error)
	SignInOrSignBack(context.Context, string, upstream.SignRequestBody) (string, error)
	GetClubActivityList(context.Context, string, int64, string, int64) ([]upstream.ClubInfo, error)
}

type SchedulerConfig struct {
	Workers       int
	JobsPerSecond int
	BatchSize     int
	TickInterval  time.Duration
}

type schedulerJob struct {
	kind      string
	studentID int64
	actionKey string
}

// Scheduler 是进程内、SQLite 可恢复的定时执行器。SQLite 保存事件和 mutation
// claim；内存 channel 只负责当前进程分发，进程退出后未完成任务会由 stale claim 恢复。
type Scheduler struct {
	repository schedulerRepository
	upstream   schedulerUpstreamClient
	config     SchedulerConfig
	probes     *activityProbeCoordinator

	mu     sync.Mutex
	cancel context.CancelFunc
	done   chan struct{}
}

func NewScheduler(repository schedulerRepository, client schedulerUpstreamClient, config SchedulerConfig) *Scheduler {
	if config.Workers <= 0 {
		config.Workers = 10
	}
	if config.JobsPerSecond <= 0 {
		config.JobsPerSecond = 5
	}
	if config.BatchSize <= 0 {
		config.BatchSize = 100
	}
	if config.TickInterval <= 0 {
		config.TickInterval = time.Second
	}
	return &Scheduler{
		repository: repository,
		upstream:   client,
		config:     config,
		probes:     newActivityProbeCoordinator(),
	}
}

func (s *Scheduler) Start() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.cancel = cancel
	s.done = make(chan struct{})
	go s.run(ctx, s.done)
}

func (s *Scheduler) Stop(ctx context.Context) error {
	s.mu.Lock()
	cancel, done := s.cancel, s.done
	s.mu.Unlock()
	if cancel == nil {
		return nil
	}
	cancel()
	select {
	case <-done:
		s.mu.Lock()
		s.cancel = nil
		s.done = nil
		s.mu.Unlock()
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *Scheduler) run(ctx context.Context, done chan struct{}) {
	defer close(done)
	jobs := make(chan schedulerJob, s.config.BatchSize)
	interval := time.Second / time.Duration(s.config.JobsPerSecond)
	if interval < time.Millisecond {
		interval = time.Millisecond
	}
	pace := time.NewTicker(interval)
	defer pace.Stop()
	var workers sync.WaitGroup
	workers.Add(s.config.Workers)
	for index := 0; index < s.config.Workers; index++ {
		go func() {
			defer workers.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case job := <-jobs:
					select {
					case <-ctx.Done():
						return
					case <-pace.C:
					}
					jobCtx, cancel := context.WithTimeout(ctx, 25*time.Second)
					if err := s.process(jobCtx, job, time.Now()); err != nil {
						log.Printf("AutoRun 定时任务失败: type=%s student_id=%d: %v", job.kind, job.studentID, err)
					}
					cancel()
				}
			}
		}()
	}
	ticker := time.NewTicker(s.config.TickInterval)
	defer ticker.Stop()
	// 启动后立即恢复一次到期任务，不必等待首个 tick。
	s.dispatch(ctx, jobs, time.Now())
	for {
		select {
		case <-ctx.Done():
			workers.Wait()
			return
		case now := <-ticker.C:
			s.dispatch(ctx, jobs, now)
		}
	}
}

func (s *Scheduler) dispatch(ctx context.Context, jobs chan<- schedulerJob, now time.Time) {
	if _, err := s.repository.ExpireOverdueEvents(ctx, now.Add(-eventWindowGrace)); err != nil {
		log.Printf("AutoRun 清理过期定时事件失败: %v", err)
		return
	}
	available := cap(jobs) - len(jobs)
	if available <= 0 {
		return
	}
	limit := min(available, s.config.BatchSize)
	events, err := s.repository.ClaimDueEvents(ctx, now, limit, eventWindowGrace)
	if err != nil {
		log.Printf("AutoRun 获取到期事件失败: %v", err)
		return
	}
	for _, event := range events {
		jobs <- schedulerJob{kind: "probe", studentID: event.StudentID, actionKey: event.ActionKey}
	}
	available -= len(events)
	if available <= 0 {
		return
	}

	queryDate := businessDate(now)
	schedules, err := s.repository.ListSchedulesNeedingRefresh(ctx, queryDate, now, min(available, s.config.BatchSize))
	if err != nil {
		log.Printf("AutoRun 获取待刷新定时配置失败: %v", err)
		return
	}
	studentIDs := make([]int64, 0, len(schedules))
	for _, schedule := range schedules {
		studentIDs = append(studentIDs, schedule.StudentID)
	}
	claimed, err := s.repository.ClaimScheduleRefreshes(ctx, studentIDs, queryDate, now)
	if err != nil {
		log.Printf("AutoRun claim 定时刷新失败: %v", err)
		return
	}
	for _, studentID := range claimed {
		jobs <- schedulerJob{kind: "refresh", studentID: studentID}
	}
}

func (s *Scheduler) process(ctx context.Context, job schedulerJob, now time.Time) error {
	if job.kind == "refresh" {
		return s.refresh(ctx, job.studentID, now)
	}
	return s.probe(ctx, job.studentID, job.actionKey, now)
}

func (s *Scheduler) refresh(ctx context.Context, studentID int64, now time.Time) error {
	queryDate := businessDate(now)
	schedule, err := s.repository.GetSchedule(ctx, studentID)
	if err != nil {
		return err
	}
	if schedule == nil || !schedule.Enabled {
		return nil
	}
	session, err := s.scheduledSession(ctx, schedule)
	if err != nil {
		return err
	}
	if session == nil || session.Token == "" {
		return s.repository.DeferScheduleRefresh(ctx, studentID, queryDate, now.Add(expiredSessionRetry), "活动时间同步失败：缺少可用登录态，请重新登录", now)
	}
	schoolID := session.SchoolID
	if schoolID <= 0 {
		schoolID = schedule.SchoolID
	}
	activities, err := s.upstream.GetClubActivityList(ctx, session.Token, session.StudentID, queryDate, schoolID)
	if err != nil {
		retry := refreshRetry
		message := "活动时间同步失败：上游请求失败"
		if upstream.IsTokenExpired(err) {
			retry = expiredSessionRetry
			message = "活动时间同步失败：登录态已过期，请重新登录"
		}
		return s.repository.DeferScheduleRefresh(ctx, studentID, queryDate, now.Add(retry), message, now)
	}
	events := buildScheduleEvents(queryDate, studentID, activities)
	return s.repository.ReplaceScheduleEvents(ctx, studentID, queryDate, events, now, now.Add(refreshInterval))
}

func (s *Scheduler) probe(ctx context.Context, studentID int64, actionKey string, now time.Time) error {
	schedule, err := s.repository.GetSchedule(ctx, studentID)
	if err != nil {
		return err
	}
	event, err := s.repository.GetEvent(ctx, studentID, actionKey)
	if err != nil {
		return err
	}
	if schedule == nil || !schedule.Enabled || event == nil || event.Status != store.EventPending {
		return nil
	}
	if now.After(event.WindowEnd.Add(eventWindowGrace)) {
		if err := s.repository.ExpireEvent(ctx, studentID, actionKey); err != nil {
			return err
		}
		return s.updateMessage(ctx, studentID, now, "已错过自动"+signTypeName(event.SignType)+"窗口")
	}
	completedKey := schedule.LastSignInKey
	if event.SignType == store.SignBackType {
		completedKey = schedule.LastSignBackKey
	}
	complete, err := s.repository.IsActionComplete(ctx, studentID, actionKey)
	if err != nil {
		return err
	}
	if completedKey == actionKey || complete {
		return s.repository.CompleteScheduledAction(ctx, studentID, actionKey, event.SignType, now, "自动"+signTypeName(event.SignType)+"已完成（去重确认）")
	}

	session, err := s.scheduledSession(ctx, schedule)
	if err != nil {
		return err
	}
	if session == nil || session.Token == "" {
		return s.deferProbe(ctx, event, now, "定时任务缺少可用登录态，请重新登录")
	}
	schoolID := session.SchoolID
	if schoolID <= 0 {
		schoolID = schedule.SchoolID
	}
	probeResult, err := s.probes.Do(ctx, activityProbeKey{
		SchoolID:   schoolID,
		ActivityID: event.ActivityID,
		SignType:   event.SignType,
	}, func(probeCtx context.Context) (activityProbeResult, error) {
		task, probeErr := s.upstream.GetSignInTf(probeCtx, session.Token, session.StudentID)
		if probeErr != nil {
			return activityProbeResult{}, probeErr
		}
		return resolveActivityProbe(event, task), nil
	})
	if err != nil {
		message := "试探签到/签退失败：上游请求失败"
		if upstream.IsTokenExpired(err) {
			message = "试探签到/签退失败：登录态已过期，请重新登录"
		}
		return s.deferProbe(ctx, event, now, message)
	}
	if !probeResult.Open {
		return s.deferProbe(ctx, event, now, probeResult.Message)
	}

	// mutation claim 在请求前落盘。请求超时可能代表上游已经成功，因此无论错误
	// 类型都不自动释放 claim，也不在本窗口二次发送。
	claimed, err := s.repository.TryClaimAction(ctx, studentID, actionKey, now, 24*time.Hour)
	if err != nil {
		return err
	}
	if !claimed {
		return s.deferProbe(ctx, event, now, "自动"+signTypeName(event.SignType)+"已提交，等待去重确认")
	}
	request := upstream.SignRequestBody{
		ActivityID: probeResult.ActivityID, Latitude: probeResult.Latitude, Longitude: probeResult.Longitude,
		SignType: string(event.SignType), StudentID: session.StudentID,
	}
	if keyed, ok := s.upstream.(scheduledMutationClient); ok {
		_, err = keyed.SignInOrSignBackWithKey(ctx, session.Token, actionKey, request)
	} else {
		// 仅供旧版直接上游客户端回滚；生产 relay 始终实现带 actionKey 的接口。
		_, err = s.upstream.SignInOrSignBack(ctx, session.Token, request)
	}
	if err != nil {
		_ = s.repository.DeferScheduleEvent(context.WithoutCancel(ctx), studentID, actionKey, event.WindowEnd.Add(eventWindowGrace))
		_ = s.updateMessage(context.WithoutCancel(ctx), studentID, now, "自动"+signTypeName(event.SignType)+"结果未知，为避免重复提交已停止重试")
		return fmt.Errorf("submit scheduled mutation once: %w", err)
	}
	return s.repository.CompleteScheduledAction(ctx, studentID, actionKey, event.SignType, now, "自动"+signTypeName(event.SignType)+"成功")
}

func resolveActivityProbe(event *store.Event, task *upstream.SignInTf) activityProbeResult {
	if isEmptySignTask(task) || resolveSignType(task) != event.SignType {
		return activityProbeResult{Message: "已试探：服务器暂未开放对应签到/签退"}
	}
	if task == nil || (event.ActivityID > 0 && task.ActivityID > 0 && event.ActivityID != task.ActivityID) ||
		task.ActivityID <= 0 || !validCoordinate(task.Latitude, -90, 90) || !validCoordinate(task.Longitude, -180, 180) {
		return activityProbeResult{Message: "已试探：活动编号或签到坐标缺失/不匹配"}
	}
	return activityProbeResult{
		Open:       true,
		ActivityID: task.ActivityID,
		Latitude:   task.Latitude,
		Longitude:  task.Longitude,
	}
}

func (s *Scheduler) scheduledSession(ctx context.Context, schedule *store.Schedule) (*store.Session, error) {
	if schedule.SessionKey != "" {
		session, err := s.repository.GetSessionByKey(ctx, schedule.SessionKey)
		if err != nil || session != nil {
			return session, err
		}
	}
	return s.repository.GetSessionByStudentID(ctx, schedule.StudentID)
}

func (s *Scheduler) deferProbe(ctx context.Context, event *store.Event, now time.Time, message string) error {
	next := now.Add(probeRetry)
	if next.After(event.WindowEnd.Add(eventWindowGrace)) {
		next = event.WindowEnd.Add(eventWindowGrace)
	}
	if err := s.repository.DeferScheduleEvent(ctx, event.StudentID, event.ActionKey, next); err != nil {
		return err
	}
	return s.updateMessage(ctx, event.StudentID, now, message)
}

func (s *Scheduler) updateMessage(ctx context.Context, studentID int64, now time.Time, message string) error {
	return s.repository.UpdateScheduleRuntime(ctx, studentID, store.ScheduleRuntimeUpdate{LastProbeAt: now, LastMessage: &message})
}
