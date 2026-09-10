package autorun

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"cuit-server/internal/autorun/store"
	"cuit-server/internal/autorun/upstream"
)

const (
	appVersion  = "1.8.5"
	deviceBrand = "Xiaomi"
	deviceType  = "1"
	mobileType  = "Mi 11"
	system      = "Android 11"
)

var (
	ErrInvalidInput    = errors.New("autorun: invalid input")
	ErrUnauthenticated = errors.New("autorun: unauthenticated")
)

type sessionRepository interface {
	SaveSession(context.Context, string, store.Session, ...string) (store.Session, error)
	GetSessionByKey(context.Context, string) (*store.Session, error)
	GetSchedule(context.Context, int64) (*store.Schedule, error)
	SaveSchedule(context.Context, int64, int64, string, bool, ...time.Time) (*store.Schedule, error)
}

type upstreamClient interface {
	Login(context.Context, string, string, string, string, string, string, string, string) (upstream.LoginInfo, error)
	GetSchoolBound(context.Context, string, int64) ([]upstream.SchoolBound, error)
	GetRunStandard(context.Context, string, int64) (upstream.RunStandard, error)
	RecordNew(context.Context, string, upstream.NewRecordBody) (string, error)
	GetSignInTf(context.Context, string, int64) (*upstream.SignInTf, error)
	SignInOrSignBack(context.Context, string, upstream.SignRequestBody) (string, error)
	GetClubActivityList(context.Context, string, int64, string, int64) ([]upstream.ClubInfo, error)
	JoinClubActivity(context.Context, string, int64, int64) (string, error)
	CancelClubActivity(context.Context, string, int64, int64) (string, error)
	GetRunInfo(context.Context, string, int64, string) (upstream.RunInfo, error)
	GetClubJoinNum(context.Context, string, int64, int64) (upstream.ClubJoinNum, error)
	GetSchoolActivityTopThree(context.Context, string) ([]upstream.ClubTopActivity, error)
}

// Service 编排浏览器、SQLite 与校园跑上游。浏览器只负责纯计算；所有需要
// APP_SECRET 的签名仍由 upstream.Client 在服务端完成。
type Service struct {
	repository sessionRepository
	upstream   upstreamClient
	now        func() time.Time
}

func NewService(repository sessionRepository, client upstreamClient) *Service {
	return &Service{repository: repository, upstream: client, now: time.Now}
}

type SessionResponse struct {
	UserID     int64  `json:"userId"`
	StudentID  int64  `json:"studentId"`
	SchoolID   int64  `json:"schoolId"`
	TokenSrc   string `json:"tokenSrc"`
	SessionKey string `json:"sessionKey"`
}

type RunData struct {
	RunStandard upstream.RunStandard `json:"runStandard"`
	RunInfo     upstream.RunInfo     `json:"runInfo"`
	TokenSrc    string               `json:"tokenSrc"`
	SessionKey  string               `json:"sessionKey"`
}

type RunPreparation struct {
	UserID      int64                  `json:"userId"`
	SchoolID    int64                  `json:"schoolId"`
	RunStandard upstream.RunStandard   `json:"runStandard"`
	Bounds      []upstream.SchoolBound `json:"bounds"`
	TokenSrc    string                 `json:"tokenSrc"`
	SessionKey  string                 `json:"sessionKey"`
}

type ClubData struct {
	QueryDate    string                     `json:"queryDate"`
	SignTask     *upstream.SignInTf         `json:"signTask"`
	Activities   []upstream.ClubInfo        `json:"activities"`
	JoinProgress upstream.ClubJoinNum       `json:"joinProgress"`
	TopThree     []upstream.ClubTopActivity `json:"topThree"`
	Schedule     PublicSchedule             `json:"schedule"`
	TokenSrc     string                     `json:"tokenSrc"`
	SessionKey   string                     `json:"sessionKey"`
}

type PublicSchedule struct {
	StudentID    int64  `json:"studentId"`
	Enabled      bool   `json:"enabled"`
	LastProbeAt  string `json:"lastProbeAt,omitempty"`
	LastActionAt string `json:"lastActionAt,omitempty"`
	LastMessage  string `json:"lastMessage,omitempty"`
	UpdatedAt    string `json:"updatedAt,omitempty"`
}

func (s *Service) GetClubSchedule(ctx context.Context, sessionKey string) (map[string]any, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return nil, err
	}
	schedule, err := s.repository.GetSchedule(ctx, session.StudentID)
	if err != nil {
		return nil, fmt.Errorf("autorun read schedule: %w", err)
	}
	return map[string]any{"schedule": publicSchedule(schedule, session.StudentID), "tokenSrc": "local", "sessionKey": session.SessionKey}, nil
}

func (s *Service) Login(ctx context.Context, phone, password string) (SessionResponse, error) {
	phone = strings.TrimSpace(phone)
	if phone == "" || password == "" {
		return SessionResponse{}, fmt.Errorf("%w: 请输入手机号和密码", ErrInvalidInput)
	}
	login, err := s.upstream.Login(ctx, phone, password, appVersion, deviceBrand, "", deviceType, mobileType, system)
	if err != nil {
		return SessionResponse{}, fmt.Errorf("autorun login: %w", err)
	}
	stored, err := s.repository.SaveSession(ctx, phone, store.Session{
		Token: login.Token, UserID: login.UserID, StudentID: login.StudentID, SchoolID: login.SchoolID,
	})
	if err != nil {
		return SessionResponse{}, fmt.Errorf("autorun save login: %w", err)
	}
	return sessionResponse(stored, "login"), nil
}

func (s *Service) Bootstrap(ctx context.Context, sessionKey string) (SessionResponse, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return SessionResponse{}, err
	}
	return sessionResponse(*session, "local"), nil
}

func (s *Service) RunInfo(ctx context.Context, sessionKey string) (RunData, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return RunData{}, err
	}
	standard, err := s.upstream.GetRunStandard(ctx, session.Token, session.SchoolID)
	if err != nil {
		return RunData{}, wrapUpstream("查询跑步标准", err)
	}
	info, err := s.upstream.GetRunInfo(ctx, session.Token, session.UserID, standard.SemesterYear)
	if err != nil {
		return RunData{}, wrapUpstream("查询跑步进度", err)
	}
	return RunData{RunStandard: standard, RunInfo: info, TokenSrc: "local", SessionKey: session.SessionKey}, nil
}

func (s *Service) PrepareRun(ctx context.Context, sessionKey string) (RunPreparation, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return RunPreparation{}, err
	}

	// 标准和围栏互不依赖，并行读取以减少移动网络下的等待时间。
	var standard upstream.RunStandard
	var bounds []upstream.SchoolBound
	var standardErr, boundsErr error
	var wait sync.WaitGroup
	wait.Add(2)
	go func() {
		defer wait.Done()
		standard, standardErr = s.upstream.GetRunStandard(ctx, session.Token, session.SchoolID)
	}()
	go func() {
		defer wait.Done()
		bounds, boundsErr = s.upstream.GetSchoolBound(ctx, session.Token, session.SchoolID)
	}()
	wait.Wait()
	if standardErr != nil {
		return RunPreparation{}, wrapUpstream("查询跑步标准", standardErr)
	}
	if boundsErr != nil {
		return RunPreparation{}, wrapUpstream("查询学校围栏", boundsErr)
	}
	return RunPreparation{
		UserID: session.UserID, SchoolID: session.SchoolID, RunStandard: standard, Bounds: bounds,
		TokenSrc: "local", SessionKey: session.SessionKey,
	}, nil
}

func (s *Service) SubmitRun(ctx context.Context, sessionKey string, body upstream.NewRecordBody) (map[string]any, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return nil, err
	}
	if err := validateRunBody(body); err != nil {
		return nil, err
	}
	// userId 必须来自服务端会话，不能让浏览器替其他用户提交记录。
	body.UserID = session.UserID
	raw, err := s.upstream.RecordNew(ctx, session.Token, body)
	if err != nil {
		return nil, wrapUpstream("提交校园跑记录", err)
	}
	return map[string]any{"rawResponse": raw, "userId": session.UserID, "schoolId": session.SchoolID, "tokenSrc": "local", "sessionKey": session.SessionKey}, nil
}

func (s *Service) ClubData(ctx context.Context, sessionKey, requestedDate string) (ClubData, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return ClubData{}, err
	}
	queryDate, err := normalizeBusinessDate(requestedDate, s.now())
	if err != nil {
		return ClubData{}, err
	}

	var signTask *upstream.SignInTf
	var activities []upstream.ClubInfo
	var progress upstream.ClubJoinNum
	var top []upstream.ClubTopActivity
	var schedule *store.Schedule
	errs := make([]error, 5)
	var wait sync.WaitGroup
	wait.Add(5)
	go func() {
		defer wait.Done()
		signTask, errs[0] = s.upstream.GetSignInTf(ctx, session.Token, session.StudentID)
	}()
	go func() {
		defer wait.Done()
		activities, errs[1] = s.upstream.GetClubActivityList(ctx, session.Token, session.StudentID, queryDate, session.SchoolID)
	}()
	go func() {
		defer wait.Done()
		progress, errs[2] = s.upstream.GetClubJoinNum(ctx, session.Token, session.SchoolID, session.StudentID)
	}()
	go func() { defer wait.Done(); top, errs[3] = s.upstream.GetSchoolActivityTopThree(ctx, session.Token) }()
	go func() { defer wait.Done(); schedule, errs[4] = s.repository.GetSchedule(ctx, session.StudentID) }()
	wait.Wait()
	labels := []string{"查询签到状态", "查询俱乐部活动", "查询俱乐部进度", "查询推荐活动"}
	for index, callErr := range errs[:4] {
		if callErr != nil {
			return ClubData{}, wrapUpstream(labels[index], callErr)
		}
	}
	if errs[4] != nil {
		return ClubData{}, fmt.Errorf("autorun read schedule: %w", errs[4])
	}
	if activities == nil {
		activities = []upstream.ClubInfo{}
	}
	if top == nil {
		top = []upstream.ClubTopActivity{}
	}
	return ClubData{
		QueryDate: queryDate, SignTask: signTask, Activities: activities, JoinProgress: progress,
		TopThree: top, Schedule: publicSchedule(schedule, session.StudentID), TokenSrc: "local", SessionKey: session.SessionKey,
	}, nil
}

func (s *Service) SetClubSchedule(ctx context.Context, sessionKey string, enabled bool) (map[string]any, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return nil, err
	}
	schedule, err := s.repository.SaveSchedule(ctx, session.StudentID, session.SchoolID, session.SessionKey, enabled, s.now())
	if err != nil {
		return nil, fmt.Errorf("autorun save schedule: %w", err)
	}
	return map[string]any{"schedule": publicSchedule(schedule, session.StudentID), "tokenSrc": "local", "sessionKey": session.SessionKey}, nil
}

func (s *Service) SignClub(ctx context.Context, sessionKey string, request SignClubRequest) (map[string]any, error) {
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return nil, err
	}
	body, task, err := s.prepareClubSign(ctx, session, request)
	if err != nil {
		return nil, err
	}
	if body == nil {
		return map[string]any{"success": false, "signTask": task, "sessionKey": session.SessionKey, "tokenSrc": "local"}, nil
	}
	raw, err := s.upstream.SignInOrSignBack(ctx, session.Token, *body)
	if err != nil {
		return nil, wrapUpstream("提交俱乐部签到/签退", err)
	}
	return map[string]any{"success": true, "signType": body.SignType, "signTask": task, "rawResponse": raw, "sessionKey": session.SessionKey, "tokenSrc": "local"}, nil
}

func (s *Service) JoinClub(ctx context.Context, sessionKey string, activityID int64) (map[string]any, error) {
	return s.mutateClubMembership(ctx, sessionKey, activityID, true)
}

func (s *Service) CancelClub(ctx context.Context, sessionKey string, activityID int64) (map[string]any, error) {
	return s.mutateClubMembership(ctx, sessionKey, activityID, false)
}

func (s *Service) mutateClubMembership(ctx context.Context, sessionKey string, activityID int64, join bool) (map[string]any, error) {
	if activityID <= 0 {
		return nil, fmt.Errorf("%w: 缺少 activityId", ErrInvalidInput)
	}
	session, err := s.authorize(ctx, sessionKey)
	if err != nil {
		return nil, err
	}
	var raw string
	if join {
		raw, err = s.upstream.JoinClubActivity(ctx, session.Token, session.StudentID, activityID)
	} else {
		raw, err = s.upstream.CancelClubActivity(ctx, session.Token, session.StudentID, activityID)
	}
	if err != nil {
		return nil, wrapUpstream("提交俱乐部报名操作", err)
	}
	return map[string]any{"rawResponse": raw, "sessionKey": session.SessionKey, "tokenSrc": "local"}, nil
}

type SignClubRequest struct {
	ActivityID int64
	Latitude   string
	Longitude  string
	SignType   string
}

func (s *Service) prepareClubSign(ctx context.Context, session *store.Session, request SignClubRequest) (*upstream.SignRequestBody, *upstream.SignInTf, error) {
	direct := request.ActivityID > 0 || request.Latitude != "" || request.Longitude != ""
	if direct {
		if request.ActivityID <= 0 || (request.SignType != "1" && request.SignType != "2") ||
			!validCoordinate(request.Latitude, -90, 90) || !validCoordinate(request.Longitude, -180, 180) {
			return nil, nil, fmt.Errorf("%w: 签到参数无效", ErrInvalidInput)
		}
		return &upstream.SignRequestBody{ActivityID: request.ActivityID, Latitude: strings.TrimSpace(request.Latitude), Longitude: strings.TrimSpace(request.Longitude), SignType: request.SignType, StudentID: session.StudentID}, nil, nil
	}
	task, err := s.upstream.GetSignInTf(ctx, session.Token, session.StudentID)
	if err != nil {
		return nil, nil, wrapUpstream("查询签到状态", err)
	}
	if isEmptySignTask(task) {
		return nil, task, nil
	}
	resolved := resolveSignType(task)
	if request.SignType != "" && request.SignType != string(resolved) {
		return nil, task, nil
	}
	if resolved == "" || task == nil || task.ActivityID <= 0 ||
		!validCoordinate(task.Latitude, -90, 90) || !validCoordinate(task.Longitude, -180, 180) {
		return nil, task, nil
	}
	return &upstream.SignRequestBody{ActivityID: task.ActivityID, Latitude: task.Latitude, Longitude: task.Longitude, SignType: string(resolved), StudentID: session.StudentID}, task, nil
}

func (s *Service) authorize(ctx context.Context, sessionKey string) (*store.Session, error) {
	sessionKey = strings.TrimSpace(sessionKey)
	if sessionKey == "" {
		return nil, ErrUnauthenticated
	}
	session, err := s.repository.GetSessionByKey(ctx, sessionKey)
	if err != nil {
		return nil, fmt.Errorf("autorun load session: %w", err)
	}
	if session == nil || session.Token == "" {
		return nil, ErrUnauthenticated
	}
	return session, nil
}

func validateRunBody(body upstream.NewRecordBody) error {
	if body.AppVersions != appVersion || body.Brand != deviceBrand || body.MobileType != mobileType || body.SysVersions != system ||
		body.TrackPoints == "" || len(body.TrackPoints) > 1_000_000 || body.RealityTrackPoints == "" || len(body.RealityTrackPoints) > 100_000 ||
		body.RunDistance <= 0 || body.RunDistance > 100_000 || body.RunTime <= 0 || body.RunTime > 24*60 ||
		strings.TrimSpace(body.YearSemester) == "" {
		return fmt.Errorf("%w: 校园跑记录参数无效", ErrInvalidInput)
	}
	if _, err := time.Parse("2006-01-02", body.RecordDate); err != nil {
		return fmt.Errorf("%w: recordDate 无效", ErrInvalidInput)
	}
	return nil
}

func sessionResponse(session store.Session, source string) SessionResponse {
	return SessionResponse{UserID: session.UserID, StudentID: session.StudentID, SchoolID: session.SchoolID, TokenSrc: source, SessionKey: session.SessionKey}
}

func publicSchedule(schedule *store.Schedule, studentID int64) PublicSchedule {
	result := PublicSchedule{StudentID: studentID}
	if schedule == nil {
		return result
	}
	result.Enabled = schedule.Enabled
	result.LastMessage = schedule.LastMessage
	if schedule.LastProbeAt != nil {
		result.LastProbeAt = schedule.LastProbeAt.Format(time.RFC3339)
	}
	if schedule.LastActionAt != nil {
		result.LastActionAt = schedule.LastActionAt.Format(time.RFC3339)
	}
	if !schedule.UpdatedAt.IsZero() {
		result.UpdatedAt = schedule.UpdatedAt.Format(time.RFC3339)
	}
	return result
}

func wrapUpstream(operation string, err error) error {
	if upstream.IsTokenExpired(err) {
		return fmt.Errorf("%w: 登录态已过期，请重新登录", ErrUnauthenticated)
	}
	return fmt.Errorf("autorun %s: %w", operation, err)
}
