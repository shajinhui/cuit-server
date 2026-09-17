package library

import (
	"context"
	"errors"
	"log"
	"strings"
	"sync"
	"time"

	"cuit-server/internal/academic"
	"cuit-server/pkg/jwxt"
)

const (
	defaultAutoRenewalTick       = 15 * time.Second
	defaultAutoRenewalJobTimeout = 90 * time.Second
	defaultAutoRenewalStaleAfter = 5 * time.Minute
)

type AutoRenewalExecutor interface {
	ExecuteLibraryAutoRenewal(context.Context, int64, string, int, string) (jwxt.LibraryOperationResult, error)
}

type AutoRenewalSchedulerConfig struct {
	Workers      int
	BatchSize    int
	TickInterval time.Duration
	JobTimeout   time.Duration
}

type AutoRenewalScheduler struct {
	repository *AutoRenewalRepository
	executor   AutoRenewalExecutor
	config     AutoRenewalSchedulerConfig

	mu     sync.Mutex
	cancel context.CancelFunc
	done   chan struct{}
}

func NewAutoRenewalScheduler(
	repository *AutoRenewalRepository,
	executor AutoRenewalExecutor,
	config AutoRenewalSchedulerConfig,
) *AutoRenewalScheduler {
	if config.Workers <= 0 {
		config.Workers = 2
	}
	if config.BatchSize <= 0 {
		config.BatchSize = 20
	}
	if config.TickInterval <= 0 {
		config.TickInterval = defaultAutoRenewalTick
	}
	if config.JobTimeout <= 0 {
		config.JobTimeout = defaultAutoRenewalJobTimeout
	}
	return &AutoRenewalScheduler{repository: repository, executor: executor, config: config}
}

func (s *AutoRenewalScheduler) Start() {
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

func (s *AutoRenewalScheduler) Stop(ctx context.Context) error {
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

func (s *AutoRenewalScheduler) run(ctx context.Context, done chan struct{}) {
	defer close(done)
	ticker := time.NewTicker(s.config.TickInterval)
	defer ticker.Stop()
	jobs := make(chan AutoRenewal, s.config.BatchSize)
	var workers sync.WaitGroup
	workers.Add(s.config.Workers)
	for index := 0; index < s.config.Workers; index++ {
		go func() {
			defer workers.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case job, ok := <-jobs:
					if !ok {
						return
					}
					s.process(ctx, job)
				}
			}
		}()
	}
	s.dispatch(ctx, jobs, time.Now())
	for {
		select {
		case <-ctx.Done():
			close(jobs)
			workers.Wait()
			return
		case now := <-ticker.C:
			s.dispatch(ctx, jobs, now)
		}
	}
}

func (s *AutoRenewalScheduler) dispatch(ctx context.Context, jobs chan<- AutoRenewal, now time.Time) {
	if err := s.repository.FailStaleRunning(ctx, now, defaultAutoRenewalStaleAfter); err != nil {
		log.Printf("清理状态未知的自动续座任务失败: %v", err)
	}
	if err := s.repository.CancelInactiveSessions(ctx, now); err != nil {
		log.Printf("关闭已退出登录的自动续座任务失败: %v", err)
	}
	claimed, err := s.repository.ClaimDue(ctx, now, s.config.BatchSize)
	if err != nil {
		log.Printf("读取到期自动续座任务失败: %v", err)
		return
	}
	for _, job := range claimed {
		select {
		case <-ctx.Done():
			return
		case jobs <- job:
		}
	}
}

func (s *AutoRenewalScheduler) process(parent context.Context, job AutoRenewal) {
	ctx, cancel := context.WithTimeout(parent, s.config.JobTimeout)
	defer cancel()
	active, sessionErr := s.repository.SessionActive(ctx, job.SessionTokenHash)
	if sessionErr != nil {
		s.complete(job, AutoRenewalFailed, "自动续座执行前无法确认登录状态", sessionErr)
		return
	}
	if !active {
		s.complete(job, AutoRenewalSkipped, "登录已退出，自动续座已跳过", nil)
		return
	}
	result, err := s.executor.ExecuteLibraryAutoRenewal(
		ctx,
		job.UserID,
		job.ReservationID,
		job.DurationMinutes,
		job.ReservationEnd,
	)
	status := AutoRenewalSucceeded
	message := strings.TrimSpace(result.Message)
	if message == "" {
		message = "续座成功"
	}
	if err != nil {
		status = AutoRenewalFailed
		message = "自动续座失败，未自动重试"
		if errors.Is(err, academic.ErrLibraryAutoRenewalSkipped) {
			status = AutoRenewalSkipped
			message = academic.LibraryAutoRenewalSkipReason(err)
		} else if public := jwxt.LibraryErrorMessage(err); public != "" {
			message = public
		}
		log.Printf("自动续座执行失败: user_id=%d reservation_id=%s: %v", job.UserID, job.ReservationID, err)
	}
	if len([]rune(message)) > 160 {
		message = string([]rune(message)[:160])
	}
	s.complete(job, status, message, nil)
}

func (s *AutoRenewalScheduler) complete(job AutoRenewal, status string, message string, cause error) {
	if cause != nil {
		log.Printf("自动续座执行失败: user_id=%d reservation_id=%s: %v", job.UserID, job.ReservationID, cause)
	}
	completeCtx, completeCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer completeCancel()
	if err := s.repository.Complete(completeCtx, job.ID, status, message, time.Now()); err != nil {
		log.Printf("保存自动续座结果失败: id=%d: %v", job.ID, err)
	}
}
