package autorun

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"cuit-server/internal/autorun/store"
	"cuit-server/internal/autorun/upstream"
)

const (
	businessTimeZoneOffset = 8 * 60 * 60
	probeWindow            = 10 * time.Minute
)

func businessDate(now time.Time) string {
	location := time.FixedZone("Asia/Shanghai", businessTimeZoneOffset)
	return now.In(location).Format("2006-01-02")
}

func normalizeBusinessDate(value string, now time.Time) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return businessDate(now), nil
	}
	parsed, err := time.ParseInLocation("2006-01-02", value, time.FixedZone("Asia/Shanghai", businessTimeZoneOffset))
	if err != nil || parsed.Format("2006-01-02") != value {
		return "", fmt.Errorf("%w: queryDate 必须是有效的 YYYY-MM-DD 日期", ErrInvalidInput)
	}
	return value, nil
}

// buildScheduleEvents 只为已报名活动建立开始/结束边界。上游未携带时区时，
// 时间按校园跑业务所在地 Asia/Shanghai 解释，与原 Worker 保持一致。
func buildScheduleEvents(queryDate string, studentID int64, activities []upstream.ClubInfo) []store.Event {
	events := make([]store.Event, 0, len(activities)*2)
	for _, activity := range activities {
		if strings.TrimSpace(activity.OptionStatus) != "1" || activity.ClubActivityID <= 0 {
			continue
		}
		for _, boundary := range []struct {
			raw      string
			signType store.SignType
		}{
			{raw: activity.StartTime, signType: store.SignInType},
			{raw: activity.EndTime, signType: store.SignBackType},
		} {
			eventAt, ok := parseClubEventTime(queryDate, boundary.raw)
			if !ok {
				continue
			}
			events = append(events, store.Event{
				StudentID:   studentID,
				ActionKey:   queryDate + ":" + strconv.FormatInt(activity.ClubActivityID, 10) + ":" + string(boundary.signType),
				ActivityID:  activity.ClubActivityID,
				SignType:    boundary.signType,
				EventAt:     eventAt,
				WindowStart: eventAt.Add(-probeWindow),
				WindowEnd:   eventAt.Add(probeWindow),
				AvailableAt: eventAt.Add(-probeWindow),
				Status:      store.EventPending,
			})
		}
	}
	return events
}

func parseClubEventTime(queryDate, value string) (time.Time, bool) {
	value = strings.TrimSpace(value)
	if value == "" || value == "--:--" {
		return time.Time{}, false
	}
	location := time.FixedZone("Asia/Shanghai", businessTimeZoneOffset)
	formats := []struct {
		layout string
		value  string
		zone   bool
	}{
		{layout: time.RFC3339, value: value, zone: true},
		{layout: "2006-01-02T15:04:05", value: value, zone: false},
		{layout: "2006-01-02T15:04", value: value, zone: false},
		{layout: "2006-01-02 15:04:05", value: strings.ReplaceAll(value, "/", "-"), zone: false},
		{layout: "2006-01-02 15:04", value: strings.ReplaceAll(value, "/", "-"), zone: false},
		{layout: "2006-01-02 15:04:05", value: queryDate + " " + value, zone: false},
		{layout: "2006-01-02 15:04", value: queryDate + " " + value, zone: false},
	}
	for _, candidate := range formats {
		var parsed time.Time
		var err error
		if candidate.zone {
			parsed, err = time.Parse(candidate.layout, candidate.value)
		} else {
			parsed, err = time.ParseInLocation(candidate.layout, candidate.value, location)
		}
		if err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

func resolveSignType(task *upstream.SignInTf) store.SignType {
	if task == nil {
		return ""
	}
	if task.SignStatus == "1" {
		return store.SignInType
	}
	if task.SignInStatus == "1" && task.SignStatus == "2" {
		return store.SignBackType
	}
	return ""
}

func isEmptySignTask(task *upstream.SignInTf) bool {
	if task == nil {
		return true
	}
	isZero := func(value string) bool { return value == "" || value == "0" }
	return task.ActivityID == 0 && task.ActivityName == "" && task.StartTime == "" &&
		task.EndTime == "" && task.Latitude == "" && task.Longitude == "" &&
		isZero(task.SignStatus) && isZero(task.SignInStatus) && isZero(task.SignBackStatus)
}

func validCoordinate(value string, minimum, maximum float64) bool {
	value = strings.TrimSpace(value)
	coordinate, err := strconv.ParseFloat(value, 64)
	return value != "" && err == nil && coordinate >= minimum && coordinate <= maximum
}

func signTypeName(signType store.SignType) string {
	if signType == store.SignBackType {
		return "签退"
	}
	return "签到"
}
