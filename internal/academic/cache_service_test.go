package academic

import (
	"context"
	"sync"
	"testing"
	"time"

	platformcache "cuit-server/internal/platform/cache"
	"cuit-server/pkg/jwxt"
)

func TestCachedServiceCachesGradesByUserAndSemester(t *testing.T) {
	repository := newMemoryRepository()
	client := &fakeJWXTClient{grades: []jwxt.Grade{{CourseName: "示例课程"}}}
	service := NewService(
		func() (JWXTClient, error) { return client, nil },
		repository,
		testCredentialCipher(t),
		time.Hour,
	)
	sessionID, err := service.Login(context.Background(), "test-student", "test-password")
	if err != nil {
		t.Fatal(err)
	}
	cached := NewCachedService(service, platformcache.NewLoader(newAcademicCacheStore()))

	for range 2 {
		grades, err := cached.GetGrades(context.Background(), sessionID, "906")
		if err != nil || len(grades) != 1 {
			t.Fatalf("unexpected cached grades: grades=%v err=%v", grades, err)
		}
	}
	if client.gradeCalls != 1 {
		t.Fatalf("same user and semester should query JWXT once, got %d", client.gradeCalls)
	}
	if _, err := cached.GetGrades(context.Background(), sessionID, "905"); err != nil {
		t.Fatal(err)
	}
	if client.gradeCalls != 2 {
		t.Fatalf("different semester should use another cache key, got %d calls", client.gradeCalls)
	}
}

type academicCacheStore struct {
	mu     sync.Mutex
	values map[string][]byte
}

func newAcademicCacheStore() *academicCacheStore {
	return &academicCacheStore{values: make(map[string][]byte)}
}

func (s *academicCacheStore) Get(_ context.Context, key string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	value, found := s.values[key]
	if !found {
		return nil, platformcache.ErrMiss
	}
	return append([]byte(nil), value...), nil
}

func (s *academicCacheStore) Set(
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

func (s *academicCacheStore) Delete(_ context.Context, key string) error {
	s.mu.Lock()
	delete(s.values, key)
	s.mu.Unlock()
	return nil
}
