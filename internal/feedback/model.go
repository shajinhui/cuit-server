package feedback

import "time"

const (
	TypeSuggestion = "suggestion"
	TypeBug        = "bug"

	PlatformAndroid = "android"
	PlatformIOS     = "ios"

	minContentLength = 10
	maxContentLength = 2000
)

type Submission struct {
	Type      string
	Platform  string
	Content   string
	UserAgent string
}

type Record struct {
	ID        int64
	UserID    int64
	Type      string
	Platform  string
	Content   string
	UserAgent string
	CreatedAt time.Time
}
