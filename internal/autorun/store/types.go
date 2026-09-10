// Package store contains the SQLite-backed durable state used by AutoRun.
//
// The package deliberately stores no password.  A Session contains the
// decrypted upstream token only after it has been read by the repository;
// the database column itself always contains an AES-GCM envelope.
package store

import "time"

// Session is the durable upstream login state for one student.
//
// SessionKey is a random, URL-safe application key.  PhoneHash is SHA-256 of
// the trimmed phone number and is used only for ownership/account lookup.
type Session struct {
	Token      string
	UserID     int64
	StudentID  int64
	SchoolID   int64
	SessionKey string
	PhoneHash  string
	UpdatedAt  time.Time
}

// Schedule is the persisted switch and runtime status for one student.
// Nullable timestamps are nil when no probe/action has happened yet.  A zero
// RefreshAfter means that the activity snapshot should be refreshed.
type Schedule struct {
	StudentID       int64
	SchoolID        int64
	SessionKey      string
	Enabled         bool
	LastSignInKey   string
	LastSignBackKey string
	LastProbeAt     *time.Time
	LastActionAt    *time.Time
	LastMessage     string
	UpdatedAt       time.Time
	RefreshDate     string
	RefreshAfter    time.Time
	RefreshQueuedAt *time.Time
}

// EventStatus is the durable lifecycle of a scheduled sign-in/sign-back
// boundary.  Done and expired rows are retained as audit history.
type EventStatus string

const (
	EventPending EventStatus = "pending"
	EventDone    EventStatus = "done"
	EventExpired EventStatus = "expired"
)

// SignType identifies a sign-in (1) or sign-back (2) operation.
type SignType string

const (
	SignInType   SignType = "1"
	SignBackType SignType = "2"
)

// Event is a cached activity boundary.  All timestamps are represented as
// time.Time in Go and persisted as Unix milliseconds to stay compatible with
// the AutoRun-ts D1 schema.
type Event struct {
	StudentID   int64
	ActionKey   string
	ActivityID  int64
	SignType    SignType
	EventAt     time.Time
	WindowStart time.Time
	WindowEnd   time.Time
	AvailableAt time.Time
	Status      EventStatus
	QueuedAt    *time.Time
}

// ScheduleEventDraft is an alias kept for callers ported directly from the
// TypeScript domain.  ReplaceEvents ignores Status and QueuedAt from drafts,
// always inserting a pending event (or preserving an existing done event).
type ScheduleEventDraft = Event

// ActionClaimStatus is the idempotency state for an upstream mutation.
type ActionClaimStatus string

const (
	ActionInFlight ActionClaimStatus = "in_flight"
	ActionDone     ActionClaimStatus = "done"
	ActionFailed   ActionClaimStatus = "failed"
)

// ActionClaim records the claim made before a sign-in/sign-back mutation.
type ActionClaim struct {
	StudentID int64
	ActionKey string
	Status    ActionClaimStatus
	ClaimedAt time.Time
}

// ScheduleRuntimeUpdate contains fields changed by a scheduler tick.
// Zero timestamps are omitted.  String pointers distinguish "set to empty"
// from "leave unchanged".
type ScheduleRuntimeUpdate struct {
	LastProbeAt     time.Time
	LastActionAt    time.Time
	LastMessage     *string
	LastSignInKey   *string
	LastSignBackKey *string
}

// DebugInfo is a non-sensitive storage health snapshot.
type DebugInfo struct {
	Enabled       bool
	Database      string
	SessionCount  int64
	ScheduleCount int64
}
