package library

import (
	"bytes"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
)

const (
	KindSeat  = "seat"
	KindStudy = "study"

	SysKindSeat  = 8
	SysKindStudy = 32
)

type UserSession struct {
	AccountNo string
	Token     string
}

type Area struct {
	ID        string `json:"ID"`
	Name      string `json:"Name"`
	Path      string `json:"Path"`
	Available int    `json:"Available"`
	Total     int    `json:"Total"`
	Leaf      bool   `json:"Leaf"`
	Children  []Area `json:"Children,omitempty"`
}

type OpenTime struct {
	Start string `json:"Start"`
	End   string `json:"End"`
	Limit int    `json:"Limit"`
}

type ReservationPeriod struct {
	Start string `json:"Start"`
	End   string `json:"End"`
}

type Rule struct {
	ID              string `json:"ID"`
	EarliestMinutes int    `json:"EarliestMinutes"`
	LatestMinutes   int    `json:"LatestMinutes"`
	MinimumMinutes  int    `json:"MinimumMinutes"`
	MaximumMinutes  int    `json:"MaximumMinutes"`
	CancelMinutes   int    `json:"CancelMinutes"`
	Deadline        string `json:"Deadline"`
	LaterLineTime   string `json:"LaterLineTime"`
}

type Seat struct {
	ID           string              `json:"ID"`
	Number       string              `json:"Number"`
	Name         string              `json:"Name"`
	Building     string              `json:"Building"`
	Room         string              `json:"Room"`
	Coordinate   string              `json:"Coordinate"`
	Status       string              `json:"Status"`
	OnlyView     bool                `json:"OnlyView"`
	OpenStart    string              `json:"OpenStart"`
	OpenEnd      string              `json:"OpenEnd"`
	OpenTimes    []OpenTime          `json:"OpenTimes"`
	Reservations []ReservationPeriod `json:"Reservations"`
	Rule         Rule                `json:"Rule"`
}

type SeatQuery struct {
	Kind      string
	RoomID    string
	StartDate string
	EndDate   string
	StartTime string
	EndTime   string
}

type Reservation struct {
	UUID                string `json:"UUID"`
	ReservationID       string `json:"ReservationID"`
	Kind                string `json:"Kind"`
	Name                string `json:"Name"`
	Building            string `json:"Building"`
	Room                string `json:"Room"`
	Seat                string `json:"Seat"`
	Start               string `json:"Start"`
	End                 string `json:"End"`
	ActualEnd           string `json:"ActualEnd"`
	Status              int    `json:"Status"`
	StatusLabel         string `json:"StatusLabel"`
	CanCancel           bool   `json:"CanCancel"`
	CanTemporaryLeave   bool   `json:"CanTemporaryLeave"`
	CanFinish           bool   `json:"CanFinish"`
	TemporaryLeaveUntil string `json:"TemporaryLeaveUntil"`
	ViolationReason     string `json:"ViolationReason"`
}

type ReservationQuery struct {
	StartDate string
	EndDate   string
}

type CreateReservationRequest struct {
	Kind      string `json:"Kind"`
	RoomID    string `json:"RoomID"`
	SeatID    string `json:"SeatID"`
	StartDate string `json:"StartDate"`
	EndDate   string `json:"EndDate"`
	StartTime string `json:"StartTime"`
	EndTime   string `json:"EndTime"`
	Title     string `json:"Title"`
	Memo      string `json:"Memo"`
	Captcha   string `json:"Captcha"`
}

type Capabilities struct {
	CaptchaMode       string `json:"CaptchaMode"`
	MemoMaximumLength int    `json:"MemoMaximumLength"`
	MemoRequired      bool   `json:"MemoRequired"`
	TemporaryLeave    bool   `json:"TemporaryLeave"`
	FinishEarly       bool   `json:"FinishEarly"`
	OfficialURL       string `json:"OfficialURL"`
}

type OperationResult struct {
	Message string `json:"Message"`
	Detail  string `json:"Detail,omitempty"`
}

type Captcha struct {
	ContentType string
	Data        []byte
}

// Error preserves the upstream message while keeping errors.Is useful for
// callers that need stable error categories.
type Error struct {
	Kind    error
	Message string
}

func (err *Error) Error() string {
	if strings.TrimSpace(err.Message) == "" {
		return err.Kind.Error()
	}
	return err.Kind.Error() + ": " + strings.TrimSpace(err.Message)
}

func (err *Error) Unwrap() error {
	return err.Kind
}

func PublicMessage(err error) string {
	var upstream *Error
	if errors.As(err, &upstream) {
		return strings.TrimSpace(upstream.Message)
	}
	return ""
}

type envelope struct {
	Code    flexInt         `json:"code"`
	Message string          `json:"message"`
	Msg     string          `json:"msg"`
	Data    json.RawMessage `json:"data"`
	Count   flexInt         `json:"count"`
}

type userInfo struct {
	AccountNo flexString `json:"accNo"`
	Token     string     `json:"token"`
}

type configItem struct {
	Key   string     `json:"sysKey"`
	Value flexString `json:"sysValue"`
}

type menuNode struct {
	ID           flexString `json:"id"`
	Name         string     `json:"name"`
	Available    flexInt    `json:"remainCount"`
	AvailableAlt flexInt    `json:"freeCount"`
	Total        flexInt    `json:"totalCount"`
	Children     []menuNode `json:"children"`
}

type upstreamOpenTime struct {
	Start string  `json:"openStartTime"`
	End   string  `json:"openEndTime"`
	Limit flexInt `json:"openLimit"`
}

type upstreamPeriod struct {
	Start string `json:"startTime"`
	End   string `json:"endTime"`
}

type upstreamRule struct {
	ID              flexString `json:"ruleId"`
	EarliestMinutes flexInt    `json:"earliestResvTime"`
	LatestMinutes   flexInt    `json:"latestResvTime"`
	MinimumMinutes  flexInt    `json:"minResvTime"`
	MaximumMinutes  flexInt    `json:"maxResvTime"`
	CancelMinutes   flexInt    `json:"cancelTime"`
	Deadline        flexString `json:"deadlineTime"`
	LaterLineTime   flexString `json:"laterLineTime"`
}

type upstreamSeat struct {
	ID               flexString         `json:"devId"`
	Number           flexString         `json:"devSn"`
	Name             string             `json:"devName"`
	Building         string             `json:"labName"`
	Room             string             `json:"roomName"`
	Coordinate       string             `json:"coordinate"`
	MobileCoordinate string             `json:"msideCoordinate"`
	DeviceProperty   flexInt            `json:"devProp"`
	OnlyView         bool               `json:"onlyView"`
	OpenStart        string             `json:"openStart"`
	OpenEnd          string             `json:"openEnd"`
	OpenTimes        []upstreamOpenTime `json:"openTimes"`
	Reservations     []upstreamPeriod   `json:"resvInfo"`
	Rule             upstreamRule       `json:"resvRule"`
}

type deviceInfo struct {
	ID       flexString `json:"devId"`
	Name     string     `json:"devName"`
	Building string     `json:"labName"`
	Room     string     `json:"roomName"`
	Kind     flexInt    `json:"classKind"`
}

type upstreamReservation struct {
	UUID                string       `json:"uuid"`
	ReservationID       flexString   `json:"resvId"`
	ClassKind           flexInt      `json:"classKind"`
	Property            flexInt      `json:"resvProperty"`
	Name                string       `json:"resvName"`
	Title               string       `json:"testName"`
	Building            string       `json:"labName"`
	Room                string       `json:"roomName"`
	DeviceName          string       `json:"devName"`
	Start               string       `json:"resvBeginTime"`
	End                 string       `json:"resvEndTime"`
	ActualEnd           string       `json:"resvEndRealTime"`
	Status              flexInt      `json:"resvStatus"`
	EndEarly            bool         `json:"endEarly"`
	TemporaryLeaveUntil string       `json:"tempLeaveEndTime"`
	ViolationReason     string       `json:"checkInfo"`
	Devices             []deviceInfo `json:"resvDevInfoList"`
}

type flexString string

func (value *flexString) UnmarshalJSON(data []byte) error {
	if bytes.Equal(data, []byte("null")) || bytes.Equal(data, []byte(`""`)) {
		*value = ""
		return nil
	}
	var text string
	if err := json.Unmarshal(data, &text); err == nil {
		*value = flexString(text)
		return nil
	}
	var number json.Number
	if err := json.Unmarshal(data, &number); err != nil {
		return err
	}
	*value = flexString(number.String())
	return nil
}

type flexInt int

func (value *flexInt) UnmarshalJSON(data []byte) error {
	if bytes.Equal(data, []byte("null")) || bytes.Equal(data, []byte(`""`)) {
		*value = 0
		return nil
	}
	var number int
	if err := json.Unmarshal(data, &number); err == nil {
		*value = flexInt(number)
		return nil
	}
	var text string
	if err := json.Unmarshal(data, &text); err != nil {
		return err
	}
	parsed, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return err
	}
	*value = flexInt(parsed)
	return nil
}
