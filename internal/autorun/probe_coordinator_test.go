package autorun

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"cuit-server/internal/autorun/store"
	"cuit-server/internal/autorun/upstream"
)

func TestActivityProbeCoordinatorCoalescesConcurrentCalls(t *testing.T) {
	coordinator := newActivityProbeCoordinator()
	key := activityProbeKey{SchoolID: 33, ActivityID: 88, SignType: store.SignInType}
	started := make(chan struct{})
	release := make(chan struct{})
	startTogether := make(chan struct{})
	var calls atomic.Int32

	const callers = 64
	results := make(chan activityProbeResult, callers)
	errorsFound := make(chan error, callers)
	var wait sync.WaitGroup
	wait.Add(callers)
	for range callers {
		go func() {
			defer wait.Done()
			<-startTogether
			result, err := coordinator.Do(context.Background(), key, func(context.Context) (activityProbeResult, error) {
				if calls.Add(1) == 1 {
					close(started)
				}
				<-release
				return activityProbeResult{Open: true, ActivityID: 88, Latitude: "30.1", Longitude: "104.1"}, nil
			})
			results <- result
			errorsFound <- err
		}()
	}

	close(startTogether)
	<-started
	close(release)
	wait.Wait()
	close(results)
	close(errorsFound)

	if got := calls.Load(); got != 1 {
		t.Fatalf("upstream probe calls = %d, want 1", got)
	}
	for err := range errorsFound {
		if err != nil {
			t.Fatalf("Do() error = %v", err)
		}
	}
	for result := range results {
		if !result.Open || result.ActivityID != 88 {
			t.Fatalf("Do() result = %+v", result)
		}
	}
}

func TestActivityProbeCoordinatorRetriesAfterCandidateError(t *testing.T) {
	coordinator := newActivityProbeCoordinator()
	key := activityProbeKey{SchoolID: 33, ActivityID: 88, SignType: store.SignInType}
	firstStarted := make(chan struct{})
	releaseFirst := make(chan struct{})
	var calls atomic.Int32

	firstResult := make(chan error, 1)
	go func() {
		_, err := coordinator.Do(context.Background(), key, func(context.Context) (activityProbeResult, error) {
			calls.Add(1)
			close(firstStarted)
			<-releaseFirst
			return activityProbeResult{}, errors.New("candidate token expired")
		})
		firstResult <- err
	}()
	<-firstStarted

	secondResult := make(chan activityProbeResult, 1)
	secondError := make(chan error, 1)
	go func() {
		result, err := coordinator.Do(context.Background(), key, func(context.Context) (activityProbeResult, error) {
			calls.Add(1)
			return activityProbeResult{Open: true, ActivityID: 88}, nil
		})
		secondResult <- result
		secondError <- err
	}()

	close(releaseFirst)
	if err := <-firstResult; err == nil {
		t.Fatal("first Do() error = nil, want candidate error")
	}
	if err := <-secondError; err != nil {
		t.Fatalf("second Do() error = %v", err)
	}
	if result := <-secondResult; !result.Open {
		t.Fatalf("second Do() result = %+v", result)
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("upstream probe calls = %d, want 2", got)
	}
}

func TestActivityProbeCoordinatorUsesShortLivedCache(t *testing.T) {
	coordinator := newActivityProbeCoordinator()
	clock := time.Date(2026, time.September, 11, 8, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	coordinator.now = func() time.Time { return clock }
	key := activityProbeKey{SchoolID: 33, ActivityID: 88, SignType: store.SignInType}
	calls := 0
	probe := func(context.Context) (activityProbeResult, error) {
		calls++
		return activityProbeResult{Message: "not open"}, nil
	}

	if _, err := coordinator.Do(context.Background(), key, probe); err != nil {
		t.Fatal(err)
	}
	clock = clock.Add(activityProbeClosedTTL - time.Millisecond)
	if _, err := coordinator.Do(context.Background(), key, probe); err != nil {
		t.Fatal(err)
	}
	if calls != 1 {
		t.Fatalf("calls before cache expiry = %d, want 1", calls)
	}

	clock = clock.Add(2 * time.Millisecond)
	if _, err := coordinator.Do(context.Background(), key, probe); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatalf("calls after cache expiry = %d, want 2", calls)
	}
}

func TestResolveActivityProbeSharesOnlyPublicFields(t *testing.T) {
	event := &store.Event{ActivityID: 88, SignType: store.SignInType}
	task := &upstream.SignInTf{
		ActivityID: 88,
		SignStatus: "1",
		Latitude:   "30.1",
		Longitude:  "104.1",
	}

	result := resolveActivityProbe(event, task)
	if !result.Open || result.ActivityID != 88 || result.Latitude != "30.1" || result.Longitude != "104.1" {
		t.Fatalf("resolveActivityProbe() = %+v", result)
	}
	if result.Message != "" {
		t.Fatalf("resolveActivityProbe() message = %q", result.Message)
	}

	task.SignStatus = "2"
	closed := resolveActivityProbe(event, task)
	if closed.Open || closed.Message == "" {
		t.Fatalf("resolveActivityProbe(closed) = %+v", closed)
	}
}
