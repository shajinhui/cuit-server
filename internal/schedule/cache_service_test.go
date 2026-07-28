package schedule

import (
	"context"
	"sync"
	"testing"
	"time"

	platformcache "cuit-server/internal/platform/cache"
	"cuit-server/pkg/jwxt"
)

type cachedCourseSource struct {
	mu            sync.Mutex
	scheduleCalls int
}

func (s *cachedCourseSource) ResolveUserID(context.Context, string) (int64, error) {
	return 1, nil
}

func (s *cachedCourseSource) GetCourseTable(
	context.Context,
	string,
	string,
) (jwxt.CourseTable, error) {
	return jwxt.CourseTable{}, nil
}

func (s *cachedCourseSource) GetClassroomOptions(
	context.Context,
	string,
	string,
	string,
) (jwxt.ClassroomOptions, error) {
	return jwxt.ClassroomOptions{}, nil
}

func (s *cachedCourseSource) GetAvailableClassrooms(
	context.Context,
	string,
	jwxt.AvailableClassroomQuery,
) ([]jwxt.Classroom, error) {
	return nil, nil
}

func (s *cachedCourseSource) GetClassroomSchedule(
	_ context.Context,
	_ string,
	semesterID string,
	campusID string,
) (jwxt.ClassroomSchedule, error) {
	s.mu.Lock()
	s.scheduleCalls++
	s.mu.Unlock()
	return jwxt.ClassroomSchedule{SemesterID: semesterID, CampusID: campusID}, nil
}

func TestCachedCourseTableServiceSharesClassroomScheduleAcrossUsers(t *testing.T) {
	source := &cachedCourseSource{}
	cached := NewCachedCourseTableService(
		source,
		platformcache.NewLoader(newScheduleCacheStore()),
	)

	for _, sessionID := range []string{"session-one", "session-two"} {
		schedule, err := cached.GetClassroomSchedule(context.Background(), sessionID, "905", "1")
		if err != nil || schedule.SemesterID != "905" {
			t.Fatalf("unexpected cached classroom schedule: schedule=%+v err=%v", schedule, err)
		}
	}
	source.mu.Lock()
	defer source.mu.Unlock()
	if source.scheduleCalls != 1 {
		t.Fatalf("same semester and campus should query JWXT once, got %d", source.scheduleCalls)
	}
}

type countingWeekSource struct {
	calls int
}

func (s *countingWeekSource) GetCurrentWeek(context.Context) (CurrentWeek, error) {
	s.calls++
	return CurrentWeek{CurrentWeek: 8}, nil
}

func TestCachedCurrentWeekServiceSharesDailyValue(t *testing.T) {
	source := &countingWeekSource{}
	cached := NewCachedCurrentWeekService(
		source,
		platformcache.NewLoader(newScheduleCacheStore()),
	)
	cached.now = func() time.Time {
		return time.Date(2026, 7, 28, 12, 0, 0, 0, chinaLocation)
	}

	for range 2 {
		week, err := cached.GetCurrentWeek(context.Background())
		if err != nil || week.CurrentWeek != 8 {
			t.Fatalf("unexpected current week: week=%+v err=%v", week, err)
		}
	}
	if source.calls != 1 {
		t.Fatalf("current week should be queried once per cache lifetime, got %d", source.calls)
	}
}

type scheduleCacheStore struct {
	mu     sync.Mutex
	values map[string][]byte
}

func newScheduleCacheStore() *scheduleCacheStore {
	return &scheduleCacheStore{values: make(map[string][]byte)}
}

func (s *scheduleCacheStore) Get(_ context.Context, key string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	value, found := s.values[key]
	if !found {
		return nil, platformcache.ErrMiss
	}
	return append([]byte(nil), value...), nil
}

func (s *scheduleCacheStore) Set(
	_ context.Context,
	key string,
	value []byte,
	_ time.Duration,
) error {
	s.mu.Lock()
	s.values[key] = append([]byte(nil), value...)
	s.mu.Unlock()
	return nil
}

func (s *scheduleCacheStore) Delete(_ context.Context, key string) error {
	s.mu.Lock()
	delete(s.values, key)
	s.mu.Unlock()
	return nil
}
