package cache

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type memoryStore struct {
	mu     sync.Mutex
	values map[string][]byte
}

func newMemoryStore() *memoryStore {
	return &memoryStore{values: make(map[string][]byte)}
}

func (s *memoryStore) Get(_ context.Context, key string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	value, found := s.values[key]
	if !found {
		return nil, ErrMiss
	}
	return append([]byte(nil), value...), nil
}

func (s *memoryStore) Set(_ context.Context, key string, value []byte, _ time.Duration) error {
	s.mu.Lock()
	s.values[key] = append([]byte(nil), value...)
	s.mu.Unlock()
	return nil
}

func (s *memoryStore) Delete(_ context.Context, key string) error {
	s.mu.Lock()
	delete(s.values, key)
	s.mu.Unlock()
	return nil
}

func TestGetOrLoadReadsCachedValue(t *testing.T) {
	store := newMemoryStore()
	loader := NewLoader(store)
	var calls atomic.Int32

	source := func(context.Context) ([]string, error) {
		calls.Add(1)
		return []string{"cached"}, nil
	}
	first, err := GetOrLoad(context.Background(), loader, "test:key", time.Hour, source)
	if err != nil {
		t.Fatal(err)
	}
	second, err := GetOrLoad(context.Background(), loader, "test:key", time.Hour, source)
	if err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 1 || len(first) != 1 || second[0] != "cached" {
		t.Fatalf("cache was not reused: calls=%d first=%v second=%v", calls.Load(), first, second)
	}
	snapshot := loader.Snapshot(context.Background())
	if snapshot.Requests != 2 || snapshot.Hits != 1 || snapshot.SourceLoads != 1 {
		t.Fatalf("unexpected cache snapshot: %+v", snapshot)
	}
}

func TestGetOrLoadCoalescesConcurrentMisses(t *testing.T) {
	loader := NewLoader(newMemoryStore())
	var calls atomic.Int32
	started := make(chan struct{})
	release := make(chan struct{})
	source := func(context.Context) (string, error) {
		if calls.Add(1) == 1 {
			close(started)
		}
		<-release
		return "shared", nil
	}

	const workers = 8
	results := make(chan string, workers)
	errors := make(chan error, workers)
	for range workers {
		go func() {
			value, err := GetOrLoad(context.Background(), loader, "test:shared", time.Hour, source)
			results <- value
			errors <- err
		}()
	}
	<-started
	close(release)

	for range workers {
		if err := <-errors; err != nil {
			t.Fatal(err)
		}
		if value := <-results; value != "shared" {
			t.Fatalf("unexpected shared value: %q", value)
		}
	}
	if calls.Load() != 1 {
		t.Fatalf("source should be called once, got %d", calls.Load())
	}
	snapshot := loader.Snapshot(context.Background())
	if snapshot.Requests != workers ||
		snapshot.SourceLoads != 1 ||
		snapshot.Hits+snapshot.CoalescedRequests != workers-1 {
		t.Fatalf("unexpected coalesced snapshot: %+v", snapshot)
	}
}
