package autorun

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"cuit-server/internal/autorun/store"
	"cuit-server/internal/autorun/upstream"
	"cuit-server/internal/platform/database"
	"cuit-server/migrations"
)

type fakeUpstream struct {
	loginResult upstream.LoginInfo
	loginCalls  int
	recordCalls int
	recordBody  upstream.NewRecordBody
	probeCalls  int
	signCalls   int
	signBody    upstream.SignRequestBody
	signBodies  []upstream.SignRequestBody
	signTask    *upstream.SignInTf
	probeErr    error
	signErr     error
	clubResult  upstream.ClubMembershipResult
	probeCancel context.CancelFunc
	signCancel  context.CancelFunc
}

type fakeSessionKeyRelay struct {
	fakeUpstream
	sessionKeys    []string
	remoteComplete bool
	statusCalls    int
}

func (f *fakeSessionKeyRelay) GetClubActivityListBySessionKey(_ context.Context, sessionKey string, _ int64, _ string, _ int64) ([]upstream.ClubInfo, error) {
	f.sessionKeys = append(f.sessionKeys, sessionKey)
	return nil, nil
}

func (f *fakeSessionKeyRelay) GetSignInTfBySessionKey(_ context.Context, sessionKey string, _ int64) (*upstream.SignInTf, error) {
	f.sessionKeys = append(f.sessionKeys, sessionKey)
	return f.signTask, nil
}

func (f *fakeSessionKeyRelay) IsActionCompleteBySessionKey(_ context.Context, sessionKey string, _ int64, _ string) (bool, error) {
	f.sessionKeys = append(f.sessionKeys, sessionKey)
	f.statusCalls++
	return f.remoteComplete, nil
}

func (f *fakeSessionKeyRelay) SignInOrSignBackWithSessionKey(_ context.Context, sessionKey, _ string, body upstream.SignRequestBody) (string, error) {
	f.sessionKeys = append(f.sessionKeys, sessionKey)
	f.signCalls++
	f.signBody = body
	return `{"code":10000}`, f.signErr
}

func (f *fakeUpstream) Login(context.Context, string, string, string, string, string, string, string, string) (upstream.LoginInfo, error) {
	f.loginCalls++
	return f.loginResult, nil
}
func (f *fakeUpstream) GetSchoolBound(context.Context, string, int64) ([]upstream.SchoolBound, error) {
	return []upstream.SchoolBound{{SiteBound: "30.1,103.9"}}, nil
}
func (f *fakeUpstream) GetRunStandard(context.Context, string, int64) (upstream.RunStandard, error) {
	return upstream.RunStandard{SemesterYear: "2026-2027-1"}, nil
}
func (f *fakeUpstream) RecordNew(_ context.Context, _ string, body upstream.NewRecordBody) (string, error) {
	f.recordCalls++
	f.recordBody = body
	return `{"code":10000}`, nil
}
func (f *fakeUpstream) GetSignInTf(context.Context, string, int64) (*upstream.SignInTf, error) {
	f.probeCalls++
	if f.probeCancel != nil {
		f.probeCancel()
	}
	return f.signTask, f.probeErr
}
func (f *fakeUpstream) SignInOrSignBack(_ context.Context, _ string, body upstream.SignRequestBody) (string, error) {
	f.signCalls++
	f.signBody = body
	f.signBodies = append(f.signBodies, body)
	if f.signCancel != nil {
		f.signCancel()
	}
	return `{"code":10000}`, f.signErr
}
func (f *fakeUpstream) GetClubActivityList(context.Context, string, int64, string, int64) ([]upstream.ClubInfo, error) {
	return nil, nil
}
func (f *fakeUpstream) JoinClubActivity(context.Context, string, int64, int64) (upstream.ClubMembershipResult, error) {
	if f.clubResult == (upstream.ClubMembershipResult{}) {
		return upstream.ClubMembershipResult{Success: true, RawResponse: `{"code":10000}`}, nil
	}
	return f.clubResult, nil
}
func (f *fakeUpstream) CancelClubActivity(context.Context, string, int64, int64) (upstream.ClubMembershipResult, error) {
	if f.clubResult == (upstream.ClubMembershipResult{}) {
		return upstream.ClubMembershipResult{Success: true, RawResponse: `{"code":10000}`}, nil
	}
	return f.clubResult, nil
}
func (f *fakeUpstream) GetRunInfo(context.Context, string, int64, string) (upstream.RunInfo, error) {
	return upstream.RunInfo{}, nil
}
func (f *fakeUpstream) GetClubJoinNum(context.Context, string, int64, int64) (upstream.ClubJoinNum, error) {
	return upstream.ClubJoinNum{}, nil
}
func (f *fakeUpstream) GetSchoolActivityTopThree(context.Context, string) ([]upstream.ClubTopActivity, error) {
	return nil, nil
}

func TestSubmitRunUsesSessionIdentityAndSendsMutationOnce(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	session, err := repository.SaveSession(ctx, "13800000000", store.Session{Token: "upstream-token", UserID: 11, StudentID: 22, SchoolID: 33})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeUpstream{}
	service := NewService(repository, client)
	body := validRunBody()
	body.UserID = 999
	if _, err := service.SubmitRun(ctx, session.SessionKey, body); err != nil {
		t.Fatal(err)
	}
	if client.recordCalls != 1 {
		t.Fatalf("record mutation calls = %d, want 1", client.recordCalls)
	}
	if client.recordBody.UserID != 11 {
		t.Fatalf("forwarded userId = %d, want session user 11", client.recordBody.UserID)
	}
}

func TestJoinClubReturnsRejectedBusinessResult(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	session, err := repository.SaveSession(ctx, "13800000000", store.Session{
		Token: "upstream-token", UserID: 11, StudentID: 22, SchoolID: 33,
	})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeUpstream{clubResult: upstream.ClubMembershipResult{
		Success: false, Status: "0", Message: "当天已报名并签到，不能再报名其他活动",
	}}
	result, err := NewService(repository, client).JoinClub(ctx, session.SessionKey, 44)
	if err != nil {
		t.Fatal(err)
	}
	if result["success"] != false || result["message"] != "当天已报名并签到，不能再报名其他活动" {
		t.Fatalf("JoinClub() = %#v", result)
	}
}

func TestDirectClubSignUsesSessionStudentIdentity(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	session, err := repository.SaveSession(ctx, "13800000000", store.Session{Token: "upstream-token", UserID: 11, StudentID: 22, SchoolID: 33})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeUpstream{}
	service := NewService(repository, client)
	_, err = service.SignClub(ctx, session.SessionKey, SignClubRequest{ActivityID: 44, Latitude: "30.1", Longitude: "103.9", SignType: "1"})
	if err != nil {
		t.Fatal(err)
	}
	if client.signCalls != 1 || client.signBody.StudentID != 22 {
		t.Fatalf("sign calls/body = %d/%+v", client.signCalls, client.signBody)
	}
}

func TestSchedulerDoesNotRetryUnknownMutationOutcome(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	session, err := repository.SaveSession(ctx, "13800000000", store.Session{Token: "upstream-token", UserID: 11, StudentID: 22, SchoolID: 33})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := repository.SaveSchedule(ctx, 22, 33, session.SessionKey, true, now); err != nil {
		t.Fatal(err)
	}
	event := store.Event{
		StudentID: 22, ActionKey: "2026-09-10:44:1", ActivityID: 44, SignType: store.SignInType,
		EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute), AvailableAt: now.Add(-10 * time.Minute),
	}
	if err := repository.ReplaceScheduleEvents(ctx, 22, "2026-09-10", []store.Event{event}, now, now.Add(4*time.Hour)); err != nil {
		t.Fatal(err)
	}
	client := &fakeUpstream{
		signTask: &upstream.SignInTf{ActivityID: 44, Latitude: "30.1", Longitude: "103.9", SignStatus: "1"},
		signErr:  errors.New("connection closed after request write"),
	}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	if err := scheduler.probe(ctx, 22, event.ActionKey, now); err == nil {
		t.Fatal("expected unknown mutation outcome")
	}
	if err := scheduler.probe(ctx, 22, event.ActionKey, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if client.signCalls != 1 {
		t.Fatalf("sign mutation calls = %d, want exactly 1", client.signCalls)
	}
}

func TestSchedulerReconcilesCompletedWorkerClaimWithoutResubmitting(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	const sessionKey = "worker-session-key-1234567890"
	if _, err := repository.SaveSchedule(ctx, 22, 33, sessionKey, true, now); err != nil {
		t.Fatal(err)
	}
	event := store.Event{
		StudentID: 22, ActionKey: "2026-09-10:44:1", ActivityID: 44, SignType: store.SignInType,
		EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute), AvailableAt: now,
	}
	if err := repository.ReplaceScheduleEvents(ctx, 22, "2026-09-10", []store.Event{event}, now, now.Add(4*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if claimed, err := repository.TryClaimAction(ctx, 22, event.ActionKey, now); err != nil || !claimed {
		t.Fatalf("TryClaimAction() = (%v, %v)", claimed, err)
	}
	client := &fakeSessionKeyRelay{remoteComplete: true}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	if err := scheduler.probe(ctx, 22, event.ActionKey, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if client.statusCalls != 1 || client.probeCalls != 0 || client.signCalls != 0 {
		t.Fatalf("status/probe/sign calls = %d/%d/%d", client.statusCalls, client.probeCalls, client.signCalls)
	}
	claim, err := repository.GetActionClaim(ctx, 22, event.ActionKey)
	if err != nil || claim == nil || claim.Status != store.ActionDone {
		t.Fatalf("GetActionClaim() = (%+v, %v)", claim, err)
	}
	storedEvent, err := repository.GetEvent(ctx, 22, event.ActionKey)
	if err != nil || storedEvent == nil || storedEvent.Status != store.EventDone {
		t.Fatalf("GetEvent() = (%+v, %v)", storedEvent, err)
	}
}

func TestSchedulerPersistsProbeDeferralAfterJobContextCancellation(t *testing.T) {
	repository := openTestRepository(t)
	ctx, cancel := context.WithCancel(context.Background())
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	session, err := repository.SaveSession(ctx, "13800000000", store.Session{Token: "upstream-token", UserID: 11, StudentID: 22, SchoolID: 33})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := repository.SaveSchedule(ctx, 22, 33, session.SessionKey, true, now); err != nil {
		t.Fatal(err)
	}
	event := store.Event{
		StudentID: 22, ActionKey: "2026-09-10:44:1", ActivityID: 44, SignType: store.SignInType,
		EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute), AvailableAt: now,
	}
	if err := repository.ReplaceScheduleEvents(ctx, 22, "2026-09-10", []store.Event{event}, now, now.Add(4*time.Hour)); err != nil {
		t.Fatal(err)
	}
	client := &fakeUpstream{probeErr: errors.New("upstream timeout"), probeCancel: cancel}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	if err := scheduler.probe(ctx, 22, event.ActionKey, now); err != nil {
		t.Fatal(err)
	}
	storedEvent, err := repository.GetEvent(context.Background(), 22, event.ActionKey)
	if err != nil || storedEvent == nil || !storedEvent.AvailableAt.Equal(now.Add(probeRetry)) {
		t.Fatalf("GetEvent() = (%+v, %v), want deferred event", storedEvent, err)
	}
}

func TestSchedulerCommitsSuccessAfterJobContextCancellation(t *testing.T) {
	repository := openTestRepository(t)
	ctx, cancel := context.WithCancel(context.Background())
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	session, err := repository.SaveSession(ctx, "13800000000", store.Session{Token: "upstream-token", UserID: 11, StudentID: 22, SchoolID: 33})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := repository.SaveSchedule(ctx, 22, 33, session.SessionKey, true, now); err != nil {
		t.Fatal(err)
	}
	event := store.Event{
		StudentID: 22, ActionKey: "2026-09-10:44:1", ActivityID: 44, SignType: store.SignInType,
		EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute), AvailableAt: now,
	}
	if err := repository.ReplaceScheduleEvents(ctx, 22, "2026-09-10", []store.Event{event}, now, now.Add(4*time.Hour)); err != nil {
		t.Fatal(err)
	}
	client := &fakeUpstream{
		signTask:   &upstream.SignInTf{ActivityID: 44, Latitude: "30.1", Longitude: "103.9", SignStatus: "1"},
		signCancel: cancel,
	}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	if err := scheduler.probe(ctx, 22, event.ActionKey, now); err != nil {
		t.Fatal(err)
	}
	claim, err := repository.GetActionClaim(context.Background(), 22, event.ActionKey)
	if err != nil || claim == nil || claim.Status != store.ActionDone {
		t.Fatalf("GetActionClaim() = (%+v, %v)", claim, err)
	}
	storedEvent, err := repository.GetEvent(context.Background(), 22, event.ActionKey)
	if err != nil || storedEvent == nil || storedEvent.Status != store.EventDone {
		t.Fatalf("GetEvent() = (%+v, %v)", storedEvent, err)
	}
}

func TestRelaySchedulerUsesSessionKeyWithoutStoredGoToken(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	const sessionKey = "worker-session-key-1234567890"
	if _, err := repository.SaveSchedule(ctx, 22, 33, sessionKey, true, now); err != nil {
		t.Fatal(err)
	}
	event := store.Event{
		StudentID: 22, ActionKey: "2026-09-10:44:1", ActivityID: 44, SignType: store.SignInType,
		EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute), AvailableAt: now.Add(-10 * time.Minute),
	}
	if err := repository.ReplaceScheduleEvents(ctx, 22, "2026-09-10", []store.Event{event}, now, now.Add(4*time.Hour)); err != nil {
		t.Fatal(err)
	}
	client := &fakeSessionKeyRelay{fakeUpstream: fakeUpstream{
		signTask: &upstream.SignInTf{ActivityID: 44, Latitude: "30.1", Longitude: "103.9", SignStatus: "1"},
	}}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	if err := scheduler.probe(ctx, 22, event.ActionKey, now); err != nil {
		t.Fatal(err)
	}
	if client.signCalls != 1 || len(client.sessionKeys) != 2 {
		t.Fatalf("relay calls/session keys = %d/%v", client.signCalls, client.sessionKeys)
	}
	for _, got := range client.sessionKeys {
		if got != sessionKey {
			t.Fatalf("session key = %q, want %q", got, sessionKey)
		}
	}
}

func TestSchedulerSharesActivityProbeButClaimsEachStudentMutation(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	phones := []string{"13800000000", "13800000001"}
	for index, studentID := range []int64{22, 23} {
		session, err := repository.SaveSession(ctx, phones[index], store.Session{
			Token: "upstream-token", UserID: 11 + int64(index), StudentID: studentID, SchoolID: 33,
		})
		if err != nil {
			t.Fatal(err)
		}
		if _, err := repository.SaveSchedule(ctx, studentID, 33, session.SessionKey, true, now); err != nil {
			t.Fatal(err)
		}
		event := store.Event{
			StudentID: studentID, ActionKey: "2026-09-10:44:1", ActivityID: 44, SignType: store.SignInType,
			EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute), AvailableAt: now.Add(-10 * time.Minute),
		}
		if err := repository.ReplaceScheduleEvents(ctx, studentID, "2026-09-10", []store.Event{event}, now, now.Add(4*time.Hour)); err != nil {
			t.Fatal(err)
		}
	}

	client := &fakeUpstream{
		signTask: &upstream.SignInTf{ActivityID: 44, Latitude: "30.1", Longitude: "103.9", SignStatus: "1"},
	}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	for _, studentID := range []int64{22, 23} {
		if err := scheduler.probe(ctx, studentID, "2026-09-10:44:1", now); err != nil {
			t.Fatal(err)
		}
	}

	if client.probeCalls != 1 {
		t.Fatalf("shared probe calls = %d, want 1", client.probeCalls)
	}
	if client.signCalls != 2 {
		t.Fatalf("student mutation calls = %d, want 2", client.signCalls)
	}
	if len(client.signBodies) != 2 || client.signBodies[0].StudentID == client.signBodies[1].StudentID {
		t.Fatalf("student mutation bodies = %+v", client.signBodies)
	}
	for _, studentID := range []int64{22, 23} {
		complete, err := repository.IsActionComplete(ctx, studentID, "2026-09-10:44:1")
		if err != nil {
			t.Fatal(err)
		}
		if !complete {
			t.Fatalf("student %d action was not completed", studentID)
		}
	}
}

func TestSchedulerUsesOneConfirmedStudentToDiscoverSignBackForEveryone(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	studentIDs := []int64{22, 23, 24, 25, 26, 27, 28, 29}
	signBackKey := seedConfirmedSignInSchedules(t, repository, studentIDs, now)
	client := &fakeUpstream{
		signTask: &upstream.SignInTf{
			ActivityID: 44, Latitude: "30.1", Longitude: "103.9",
			SignStatus: "2", SignInStatus: "1", SignBackStatus: "0",
		},
	}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	for _, studentID := range studentIDs {
		if err := scheduler.probe(ctx, studentID, signBackKey, now); err != nil {
			t.Fatal(err)
		}
	}
	if client.probeCalls != 1 {
		t.Fatalf("sign-back probe calls = %d, want 1", client.probeCalls)
	}
	if client.signCalls != len(studentIDs) {
		t.Fatalf("sign-back mutation calls = %d, want %d", client.signCalls, len(studentIDs))
	}
	for _, body := range client.signBodies {
		if body.SignType != string(store.SignBackType) {
			t.Fatalf("mutation sign type = %q, want sign-back", body.SignType)
		}
	}

	// An open result is public activity data, but it must not make a student
	// without a confirmed sign-in eligible for the sign-back mutation.
	session, err := repository.SaveSession(ctx, "13900000000", store.Session{
		Token: "upstream-token", UserID: 199, StudentID: 99, SchoolID: 33,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := repository.SaveSchedule(ctx, 99, 33, session.SessionKey, true, now); err != nil {
		t.Fatal(err)
	}
	unconfirmed := store.Event{
		StudentID: 99, ActionKey: signBackKey, ActivityID: 44, SignType: store.SignBackType,
		EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute),
		AvailableAt: now.Add(-10 * time.Minute),
	}
	if err := repository.ReplaceScheduleEvents(ctx, 99, "2026-09-10", []store.Event{unconfirmed}, now, now.Add(4*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if err := scheduler.probe(ctx, 99, signBackKey, now); err != nil {
		t.Fatal(err)
	}
	if client.probeCalls != 1 || client.signCalls != len(studentIDs) {
		t.Fatalf("unconfirmed student changed probe/sign calls to %d/%d", client.probeCalls, client.signCalls)
	}
}

func TestSchedulerLimitsClosedSignBackProbesToThreeCandidates(t *testing.T) {
	repository := openTestRepository(t)
	ctx := context.Background()
	now := time.Date(2026, 9, 10, 10, 0, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	studentIDs := []int64{22, 23, 24, 25, 26, 27, 28, 29}
	signBackKey := seedConfirmedSignInSchedules(t, repository, studentIDs, now)
	client := &fakeUpstream{}
	scheduler := NewScheduler(repository, client, SchedulerConfig{})
	clock := now
	scheduler.probes.now = func() time.Time { return clock }

	for _, studentID := range studentIDs {
		if err := scheduler.probe(ctx, studentID, signBackKey, now); err != nil {
			t.Fatal(err)
		}
	}
	if client.probeCalls != 1 {
		t.Fatalf("initial sign-back probe calls = %d, want 1 shared call", client.probeCalls)
	}

	clock = clock.Add(activitySignBackClosedTTL + time.Millisecond)
	for _, studentID := range studentIDs[signBackProbeCandidates:] {
		if err := scheduler.probe(ctx, studentID, signBackKey, now.Add(time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	if client.probeCalls != 1 {
		t.Fatalf("non-candidate probe calls = %d, want unchanged", client.probeCalls)
	}
	if err := scheduler.probe(ctx, studentIDs[1], signBackKey, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if client.probeCalls != 2 {
		t.Fatalf("candidate probe calls after cache expiry = %d, want 2", client.probeCalls)
	}
}

func seedConfirmedSignInSchedules(
	t *testing.T,
	repository *store.Repository,
	studentIDs []int64,
	now time.Time,
) string {
	t.Helper()
	ctx := context.Background()
	const signInKey = "2026-09-10:44:1"
	const signBackKey = "2026-09-10:44:2"
	for index, studentID := range studentIDs {
		session, err := repository.SaveSession(ctx, fmt.Sprintf("1380000%04d", index), store.Session{
			Token: "upstream-token", UserID: 100 + int64(index), StudentID: studentID, SchoolID: 33,
		})
		if err != nil {
			t.Fatal(err)
		}
		if _, err := repository.SaveSchedule(ctx, studentID, 33, session.SessionKey, true, now); err != nil {
			t.Fatal(err)
		}
		events := []store.Event{
			{
				StudentID: studentID, ActionKey: signInKey, ActivityID: 44, SignType: store.SignInType,
				EventAt: now.Add(-30 * time.Minute), WindowStart: now.Add(-40 * time.Minute),
				WindowEnd: now.Add(-20 * time.Minute), AvailableAt: now.Add(-40 * time.Minute),
			},
			{
				StudentID: studentID, ActionKey: signBackKey, ActivityID: 44, SignType: store.SignBackType,
				EventAt: now, WindowStart: now.Add(-10 * time.Minute), WindowEnd: now.Add(10 * time.Minute),
				AvailableAt: now.Add(-10 * time.Minute),
			},
		}
		if err := repository.ReplaceScheduleEvents(ctx, studentID, "2026-09-10", events, now, now.Add(4*time.Hour)); err != nil {
			t.Fatal(err)
		}
		if claimed, err := repository.TryClaimAction(ctx, studentID, signInKey, now.Add(-30*time.Minute)); err != nil || !claimed {
			t.Fatalf("TryClaimAction(%d) = (%v, %v)", studentID, claimed, err)
		}
		if err := repository.CompleteScheduledAction(ctx, studentID, signInKey, store.SignInType, now.Add(-30*time.Minute), "自动签到成功"); err != nil {
			t.Fatal(err)
		}
	}
	return signBackKey
}

func TestBuildScheduleEventsUsesShanghaiTimeAndJoinedActivities(t *testing.T) {
	events := buildScheduleEvents("2026-09-10", 22, []upstream.ClubInfo{
		{ClubActivityID: 44, OptionStatus: "1", StartTime: "09:30", EndTime: "10:30"},
		{ClubActivityID: 55, OptionStatus: "0", StartTime: "09:30", EndTime: "10:30"},
	})
	if len(events) != 2 {
		t.Fatalf("events = %d, want 2", len(events))
	}
	if got := events[0].EventAt.UTC().Format(time.RFC3339); got != "2026-09-10T01:30:00Z" {
		t.Fatalf("event UTC = %s", got)
	}
}

func validRunBody() upstream.NewRecordBody {
	return upstream.NewRecordBody{
		AgainRunStatus: "0", AppVersions: appVersion, Brand: deviceBrand, MobileType: mobileType,
		SysVersions: system, TrackPoints: "30,103,1", DistanceTimeStatus: "1", InnerSchool: "1",
		RunDistance: 5000, RunTime: 33, UserID: 11, VocalStatus: "1", YearSemester: "2026-2027-1",
		RecordDate: "2026-09-10", RealityTrackPoints: "30,103--",
	}
}

func openTestRepository(t *testing.T) *store.Repository {
	t.Helper()
	ctx := context.Background()
	db, err := database.OpenSQLite(ctx, filepath.Join(t.TempDir(), "autorun.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := migrations.Apply(ctx, db); err != nil {
		t.Fatal(err)
	}
	return store.NewRepository(db, "test-encryption-key-at-least-16")
}
