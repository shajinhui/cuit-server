package academic

import (
	"context"
	"strconv"
	"strings"
	"time"

	platformcache "cuit-server/internal/platform/cache"
	"cuit-server/pkg/jwxt"
)

const (
	semesterCacheTTL       = 24 * time.Hour
	profileCacheTTL        = 24 * time.Hour
	planCompletionCacheTTL = time.Hour
	gradeCacheTTL          = 10 * time.Minute
	examCacheTTL           = 30 * time.Minute
)

type cachedServiceSource interface {
	GradeService
	ResolveUserID(ctx context.Context, sessionID string) (int64, error)
}

// CachedService 只缓存可序列化的查询结果；密码、Cookie 和 JWXT Client 始终不进入 Redis。
type CachedService struct {
	source cachedServiceSource
	cache  *platformcache.Loader
}

func NewCachedService(source cachedServiceSource, loader *platformcache.Loader) *CachedService {
	return &CachedService{source: source, cache: loader}
}

func (s *CachedService) Login(ctx context.Context, username string, password string) (string, error) {
	return s.source.Login(ctx, username, password)
}

func (s *CachedService) GetStudentProfile(
	ctx context.Context,
	sessionID string,
) (jwxt.StudentProfile, error) {
	userID, err := s.source.ResolveUserID(ctx, sessionID)
	if err != nil {
		return jwxt.StudentProfile{}, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		userCacheKey(userID, "profile"),
		profileCacheTTL,
		func(ctx context.Context) (jwxt.StudentProfile, error) {
			return s.source.GetStudentProfile(ctx, sessionID)
		},
	)
}

func (s *CachedService) GetPlanCompletion(
	ctx context.Context,
	sessionID string,
) (jwxt.PlanCompletion, error) {
	userID, err := s.source.ResolveUserID(ctx, sessionID)
	if err != nil {
		return jwxt.PlanCompletion{}, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		userCacheKey(userID, "plan-completion"),
		planCompletionCacheTTL,
		func(ctx context.Context) (jwxt.PlanCompletion, error) {
			return s.source.GetPlanCompletion(ctx, sessionID)
		},
	)
}

func (s *CachedService) ListSemesters(ctx context.Context, sessionID string) ([]jwxt.Semester, error) {
	if _, err := s.source.ResolveUserID(ctx, sessionID); err != nil {
		return nil, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		"cuit:v1:semesters",
		semesterCacheTTL,
		func(ctx context.Context) ([]jwxt.Semester, error) {
			return s.source.ListSemesters(ctx, sessionID)
		},
	)
}

func (s *CachedService) GetGrades(
	ctx context.Context,
	sessionID string,
	semesterID string,
) ([]jwxt.Grade, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return s.source.GetGrades(ctx, sessionID, semesterID)
	}
	userID, err := s.source.ResolveUserID(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		userCacheKey(userID, "grades", semesterID),
		gradeCacheTTL,
		func(ctx context.Context) ([]jwxt.Grade, error) {
			return s.source.GetGrades(ctx, sessionID, semesterID)
		},
	)
}

func (s *CachedService) GetExams(
	ctx context.Context,
	sessionID string,
	semesterID string,
	examType string,
) ([]jwxt.Exam, error) {
	semesterID = strings.TrimSpace(semesterID)
	examType = strings.TrimSpace(examType)
	if semesterID == "" {
		return s.source.GetExams(ctx, sessionID, semesterID, examType)
	}
	userID, err := s.source.ResolveUserID(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		userCacheKey(userID, "exams", semesterID, examType),
		examCacheTTL,
		func(ctx context.Context) ([]jwxt.Exam, error) {
			return s.source.GetExams(ctx, sessionID, semesterID, examType)
		},
	)
}

func (s *CachedService) Authenticated(ctx context.Context, sessionID string) (bool, error) {
	return s.source.Authenticated(ctx, sessionID)
}

func (s *CachedService) ResolveUserID(ctx context.Context, sessionID string) (int64, error) {
	return s.source.ResolveUserID(ctx, sessionID)
}

func (s *CachedService) Logout(ctx context.Context, sessionID string) error {
	return s.source.Logout(ctx, sessionID)
}

func userCacheKey(userID int64, parts ...string) string {
	key := "cuit:v1:user:" + strconv.FormatInt(userID, 10)
	for _, part := range parts {
		key += ":" + part
	}
	return key
}
