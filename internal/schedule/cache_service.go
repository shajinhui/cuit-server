package schedule

import (
	"context"
	"strconv"
	"strings"
	"time"

	platformcache "cuit-server/internal/platform/cache"
	"cuit-server/pkg/jwxt"
)

const (
	courseTableCacheTTL       = 6 * time.Hour
	classroomOptionsCacheTTL  = 24 * time.Hour
	classroomScheduleCacheTTL = 24 * time.Hour
)

type cachedCourseTableSource interface {
	CourseTableService
	ResolveUserID(ctx context.Context, sessionID string) (int64, error)
}

// CachedCourseTableService 分离个人课表缓存与跨用户共享的教室公共数据缓存。
type CachedCourseTableService struct {
	source cachedCourseTableSource
	cache  *platformcache.Loader
}

func NewCachedCourseTableService(
	source cachedCourseTableSource,
	loader *platformcache.Loader,
) *CachedCourseTableService {
	return &CachedCourseTableService{source: source, cache: loader}
}

func (s *CachedCourseTableService) GetCourseTable(
	ctx context.Context,
	sessionID string,
	semesterID string,
) (jwxt.CourseTable, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return s.source.GetCourseTable(ctx, sessionID, semesterID)
	}
	userID, err := s.source.ResolveUserID(ctx, sessionID)
	if err != nil {
		return jwxt.CourseTable{}, err
	}
	key := "cuit:v1:user:" + strconv.FormatInt(userID, 10) + ":course-table:" + semesterID
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		key,
		courseTableCacheTTL,
		func(ctx context.Context) (jwxt.CourseTable, error) {
			return s.source.GetCourseTable(ctx, sessionID, semesterID)
		},
	)
}

func (s *CachedCourseTableService) GetClassroomOptions(
	ctx context.Context,
	sessionID string,
	semesterID string,
	campusID string,
) (jwxt.ClassroomOptions, error) {
	semesterID = strings.TrimSpace(semesterID)
	campusID = strings.TrimSpace(campusID)
	if semesterID == "" {
		return s.source.GetClassroomOptions(ctx, sessionID, semesterID, campusID)
	}
	// 公共缓存命中时仍先验证应用 Session，不能绕过现有接口权限。
	if _, err := s.source.ResolveUserID(ctx, sessionID); err != nil {
		return jwxt.ClassroomOptions{}, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		classroomCacheKey("options", semesterID, campusID),
		classroomOptionsCacheTTL,
		func(ctx context.Context) (jwxt.ClassroomOptions, error) {
			return s.source.GetClassroomOptions(ctx, sessionID, semesterID, campusID)
		},
	)
}

func (s *CachedCourseTableService) GetAvailableClassrooms(
	ctx context.Context,
	sessionID string,
	query jwxt.AvailableClassroomQuery,
) ([]jwxt.Classroom, error) {
	return s.source.GetAvailableClassrooms(ctx, sessionID, query)
}

func (s *CachedCourseTableService) GetClassroomSchedule(
	ctx context.Context,
	sessionID string,
	semesterID string,
	campusID string,
) (jwxt.ClassroomSchedule, error) {
	semesterID = strings.TrimSpace(semesterID)
	campusID = strings.TrimSpace(campusID)
	if semesterID == "" || campusID == "" {
		return s.source.GetClassroomSchedule(ctx, sessionID, semesterID, campusID)
	}
	if _, err := s.source.ResolveUserID(ctx, sessionID); err != nil {
		return jwxt.ClassroomSchedule{}, err
	}
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		classroomCacheKey("schedule", semesterID, campusID),
		classroomScheduleCacheTTL,
		func(ctx context.Context) (jwxt.ClassroomSchedule, error) {
			return s.source.GetClassroomSchedule(ctx, sessionID, semesterID, campusID)
		},
	)
}

func classroomCacheKey(kind string, semesterID string, campusID string) string {
	if campusID == "" {
		campusID = "all"
	}
	return "cuit:v1:classroom:" + kind + ":" + semesterID + ":" + campusID
}

type CachedCurrentWeekService struct {
	source CurrentWeekService
	cache  *platformcache.Loader
	now    func() time.Time
}

func NewCachedCurrentWeekService(
	source CurrentWeekService,
	loader *platformcache.Loader,
) *CachedCurrentWeekService {
	return &CachedCurrentWeekService{
		source: source,
		cache:  loader,
		now:    time.Now,
	}
}

func (s *CachedCurrentWeekService) GetCurrentWeek(ctx context.Context) (CurrentWeek, error) {
	return platformcache.GetOrLoad(
		ctx,
		s.cache,
		"cuit:v1:current-week",
		untilNextDay(s.now()),
		s.source.GetCurrentWeek,
	)
}

func untilNextDay(now time.Time) time.Duration {
	now = now.In(chinaLocation)
	nextDay := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, chinaLocation)
	return nextDay.Sub(now)
}
