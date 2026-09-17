package relay

import (
	"context"
	"testing"
	"time"

	"cuit-server/internal/autorun/store"
)

type fakeHandlerRepository struct {
	schedule *store.Schedule
}

func (f *fakeHandlerRepository) GetSessionByKey(context.Context, string) (*store.Session, error) {
	return nil, nil
}

func (f *fakeHandlerRepository) GetSchedule(context.Context, int64) (*store.Schedule, error) {
	return f.schedule, nil
}

func (f *fakeHandlerRepository) SaveSchedule(_ context.Context, studentID, schoolID int64, sessionKey string, enabled bool, operationTime ...time.Time) (*store.Schedule, error) {
	updatedAt := time.Now()
	if len(operationTime) > 0 {
		updatedAt = operationTime[0]
	}
	f.schedule = &store.Schedule{
		StudentID: studentID, SchoolID: schoolID, SessionKey: sessionKey,
		Enabled: enabled, UpdatedAt: updatedAt,
	}
	return f.schedule, nil
}

func TestScheduleSetStoresOnlyOpaqueSessionIdentity(t *testing.T) {
	repository := &fakeHandlerRepository{}
	handler := NewHandler(repository, " test-internal-secret-with-more-than-32-characters\n")
	enabled := true
	response, err := handler.execute(context.Background(), "schedule_set", internalRequest{
		SessionKey: "worker-session-key-1234567890",
		StudentID:  22,
		SchoolID:   33,
		Enabled:    &enabled,
	})
	if err != nil {
		t.Fatal(err)
	}
	if response == nil || repository.schedule == nil || !repository.schedule.Enabled {
		t.Fatalf("schedule response/state = %#v/%#v", response, repository.schedule)
	}
	if repository.schedule.SessionKey != "worker-session-key-1234567890" {
		t.Fatalf("session key = %q", repository.schedule.SessionKey)
	}
}
