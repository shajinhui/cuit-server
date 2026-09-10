// Package upstream contains the small HTTP client used by the campus-run
// feature.  It intentionally has no dependency on the API or persistence
// layers so it can be tested with an in-memory RoundTripper.
package upstream

import (
	"net/http"
	"time"
)

const (
	// BaseURL is the only production upstream endpoint.  A test may provide a
	// different URL through Options.BaseURL together with an httptest server.
	BaseURL = "https://run-lb.tanmasports.com/"

	// UserAgent is the Android client identifier expected by tanmasports.
	UserAgent = "okhttp/4.12.0"

	DefaultTimeout      = 15 * time.Second
	DefaultMaxBodyBytes = 2 * 1024 * 1024
)

// Options configures an upstream Client.  AppKey and AppSecret are supplied
// by the caller (normally environment configuration); no credential is
// embedded in this package.
//
// Transport is a test seam.  When HTTPClient is supplied, it is shallow-copied
// before the no-redirect policy is installed, so the caller's client is not
// mutated.  BaseURL is intended for httptest.Server and defaults to BaseURL.
type Options struct {
	AppKey           string
	AppSecret        string
	HTTPClient       *http.Client
	Transport        http.RoundTripper
	Timeout          time.Duration
	MaxResponseBytes int64
	BaseURL          string
	UserAgent        string
}

// Config is kept as a descriptive alias for callers that prefer configuration
// terminology over constructor options.
type Config = Options

// LoginInfo is the stable identity returned by the password-login endpoint.
type LoginInfo struct {
	Token     string `json:"token"`
	UserID    int64  `json:"userId"`
	StudentID int64  `json:"studentId"`
	SchoolID  int64  `json:"schoolId"`
}

type UserInfo struct {
	UserID     int64 `json:"userId"`
	StudentID  int64 `json:"studentId"`
	SchoolID   int64 `json:"schoolId"`
	OAuthToken struct {
		Token string `json:"token"`
	} `json:"oauthToken"`
}

type SchoolBound struct {
	SiteBound string `json:"siteBound"`
}

type RunStandard struct {
	StandardID          int64  `json:"standardId,omitempty"`
	SchoolID            int64  `json:"schoolId,omitempty"`
	BoyOnceTimeMin      int64  `json:"boyOnceTimeMin,omitempty"`
	BoyOnceTimeMax      int64  `json:"boyOnceTimeMax,omitempty"`
	BoyOnceDistanceMin  int64  `json:"boyOnceDistanceMin,omitempty"`
	BoyOnceDistanceMax  int64  `json:"boyOnceDistanceMax,omitempty"`
	BoyAllRunDistance   int64  `json:"boyAllRunDistance,omitempty"`
	BoyAllRunTime       int64  `json:"boyAllRunTime,omitempty"`
	GirlOnceTimeMin     int64  `json:"girlOnceTimeMin,omitempty"`
	GirlOnceTimeMax     int64  `json:"girlOnceTimeMax,omitempty"`
	GirlOnceDistanceMin int64  `json:"girlOnceDistanceMin,omitempty"`
	GirlOnceDistanceMax int64  `json:"girlOnceDistanceMax,omitempty"`
	GirlAllRunDistance  int64  `json:"girlAllRunDistance,omitempty"`
	GirlAllRunTime      int64  `json:"girlAllRunTime,omitempty"`
	FirstSemesterStart  string `json:"firstSemesterDateStart,omitempty"`
	FirstSemesterEnd    string `json:"firstSemesterDateEnd,omitempty"`
	SecondSemesterStart string `json:"secondSemesterDateStart,omitempty"`
	SecondSemesterEnd   string `json:"secondSemesterDateEnd,omitempty"`
	InstanceSemester    string `json:"instanceSemester,omitempty"`
	SemesterYear        string `json:"semesterYear"`
	BoyRunSpeed         int64  `json:"boyRunSpeed,omitempty"`
	GirlRunSpeed        int64  `json:"girlRunSpeed,omitempty"`
	BoyMaxSpeed         int64  `json:"boyMaxSpeed,omitempty"`
	BoyMinSpeed         int64  `json:"boyMinSpeed,omitempty"`
	GirlMaxSpeed        int64  `json:"girlMaxSpeed,omitempty"`
	GirlMinSpeed        int64  `json:"girlMinSpeed,omitempty"`
	EffectiveRangeType  string `json:"effectiveRangeType,omitempty"`
}

type RunInfo struct {
	SemesterID       int64  `json:"semesterId"`
	YearSemester     int64  `json:"yearSemester"`
	UserID           int64  `json:"userId"`
	StudentID        int64  `json:"studentId"`
	SchoolID         int64  `json:"schoolId"`
	RunCount         int64  `json:"runCount"`
	RunValidCount    int64  `json:"runValidCount"`
	RunDistance      int64  `json:"runDistance"`
	RunValidDistance int64  `json:"runValidDistance"`
	RunDay           int64  `json:"runDay"`
	RunValidDay      int64  `json:"runValidDay"`
	RunCalorie       int64  `json:"runCalorie"`
	RunValidCalorie  int64  `json:"runValidCalorie"`
	InfoStatus       string `json:"infoStatus"`
	CreateTime       string `json:"createTime"`
}

type SignInTask struct {
	ActivityID        int64  `json:"activityId"`
	ActivityName      string `json:"activityName,omitempty"`
	ActivityType      string `json:"activityType,omitempty"`
	Address           string `json:"address,omitempty"`
	ContinueTime      int64  `json:"continueTime,omitempty"`
	StartTime         string `json:"startTime,omitempty"`
	EndTime           string `json:"endTime,omitempty"`
	Longitude         string `json:"longitude"`
	Latitude          string `json:"latitude"`
	SignBackLimitTime int64  `json:"signBackLimitTime,omitempty"`
	SignBackStatus    string `json:"signBackStatus"`
	SignInStatus      string `json:"signInStatus"`
	SignInTime        string `json:"signInTime,omitempty"`
	SignStatus        string `json:"signStatus"`
}

// SignInTf is an old name used by the original TypeScript and Go ports.
type SignInTf = SignInTask

type ClubInfo struct {
	ClubActivityID   int64  `json:"clubActivityId"`
	ActivityName     string `json:"activityName"`
	SignInStudent    int64  `json:"signInStudent"`
	MaxStudent       int64  `json:"maxStudent"`
	CancelSign       string `json:"cancelSign"`
	StartTime        string `json:"startTime"`
	EndTime          string `json:"endTime"`
	AddressDetail    string `json:"addressDetail,omitempty"`
	ClubIntroduction string `json:"clubIntroduction,omitempty"`
	TeacherName      string `json:"teacherName,omitempty"`
	OptionStatus     string `json:"optionStatus,omitempty"`
	FullActivity     string `json:"fullActivity,omitempty"`
	YearSemester     int64  `json:"yearSemester,omitempty"`
	ActivityItemID   int64  `json:"activityItemId,omitempty"`
	SignStatus       string `json:"signStatus,omitempty"`
}

type ClubJoinProgress struct {
	TotalNum    int64 `json:"totalNum"`
	JoinNum     int64 `json:"joinNum"`
	RunTotalNum int64 `json:"runTotalNum"`
	RunJoinNum  int64 `json:"runJoinNum"`
}

// ClubJoinNum is the original method/type spelling.
type ClubJoinNum = ClubJoinProgress

type ClubTopActivity struct {
	ClubActivityID    string `json:"clubActivityId"`
	ActivityItemID    string `json:"activityItemId"`
	ItemName          string `json:"itemName"`
	ActivityName      string `json:"activityName"`
	StartTime         string `json:"startTime"`
	EndTime           string `json:"endTime"`
	AddressDetail     string `json:"addressDetail"`
	MaxStudent        string `json:"maxStudent"`
	ApplyStudentCount string `json:"applyStudentCount"`
}

type SignRequestBody struct {
	ActivityID int64  `json:"activityId"`
	Latitude   string `json:"latitude"`
	Longitude  string `json:"longitude"`
	SignType   string `json:"signType"`
	StudentID  int64  `json:"studentId"`
}

// SignInOrSignBackBody is the original spelling retained for migration code.
type SignInOrSignBackBody = SignRequestBody

// NewRecordBody is deliberately ordered like the TypeScript object literal.
// The exact JSON bytes are part of the upstream signature input.
type NewRecordBody struct {
	AgainRunStatus     string `json:"againRunStatus"`
	AgainRunTime       int    `json:"againRunTime"`
	AppVersions        string `json:"appVersions"`
	Brand              string `json:"brand"`
	MobileType         string `json:"mobileType"`
	SysVersions        string `json:"sysVersions"`
	TrackPoints        string `json:"trackPoints"`
	DistanceTimeStatus string `json:"distanceTimeStatus"`
	InnerSchool        string `json:"innerSchool"`
	RunDistance        int64  `json:"runDistance"`
	RunTime            int    `json:"runTime"`
	UserID             int64  `json:"userId"`
	VocalStatus        string `json:"vocalStatus"`
	YearSemester       string `json:"yearSemester"`
	RecordDate         string `json:"recordDate"`
	RealityTrackPoints string `json:"realityTrackPoints"`
}

// UpstreamEnvelope describes the remote code/msg/response wrapper.  Client
// methods return the decoded response value, while this type is useful to
// callers that need to model a fixture or forward a response.
type UpstreamEnvelope[T any] struct {
	Code     int    `json:"code"`
	Msg      string `json:"msg"`
	Response T      `json:"response"`
}

// Response is the compatibility spelling used by the older Go port.
type Response[T any] struct {
	Code     int    `json:"code"`
	Msg      string `json:"msg"`
	Response T      `json:"response"`
}
