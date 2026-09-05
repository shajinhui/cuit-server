package schedule

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestPublishedCurrentWeek(t *testing.T) {
	for _, tc := range []struct {
		date string
		week int
	}{
		{"2024-09-02", 1}, {"2025-02-24", 1}, {"2025-09-08", 1},
		{"2026-03-02", 1}, {"2026-07-19", 20}, {"2026-07-20", 0},
		{"2026-09-06", 0}, {"2026-09-07", 1}, {"2026-09-13", 1}, {"2026-09-14", 2},
		{"2027-01-17", 19}, {"2027-01-18", 0},
		{"2027-02-21", 0}, {"2027-02-22", 1}, {"2027-02-28", 1}, {"2027-03-01", 2},
		{"2027-07-04", 19}, {"2027-07-05", 0},
	} {
		t.Run(tc.date, func(t *testing.T) {
			now, err := time.ParseInLocation(time.DateOnly, tc.date, chinaLocation)
			if err != nil {
				t.Fatal(err)
			}
			// 不提供 HTTP client，证明已知学年不依赖网络或过期的官网锚点。
			client := &CalendarClient{now: func() time.Time { return now }}
			week, err := client.GetCurrentWeek(context.Background())
			if err != nil || week.CurrentWeek != tc.week {
				t.Fatalf("got %+v, %v; want week %d", week, err, tc.week)
			}
			week, err = currentWeekFromHTML([]byte(`datedifference(s1, '2026-02-28')`), now)
			if err != nil || week.CurrentWeek != tc.week {
				t.Fatalf("stale upstream anchor took precedence: %+v, %v", week, err)
			}
		})
	}
}

func TestPublishedCurrentWeekUsesChinaTimezone(t *testing.T) {
	now := time.Date(2026, time.September, 13, 16, 0, 0, 0, time.UTC)
	week, found, err := publishedCurrentWeek(now)
	if err != nil || !found || week.CurrentWeek != 2 {
		t.Fatalf("unexpected week: %+v, found=%t err=%v", week, found, err)
	}
}

func TestUnknownCalendarRequiresFreshAnchor(t *testing.T) {
	now := time.Date(2030, time.September, 10, 12, 0, 0, 0, chinaLocation)
	for _, html := range []string{
		`<html></html>`,
		`datedifference(s1, '2030-02-28')`,
		`datedifference(s1, '2030-09-31')`,
	} {
		_, err := currentWeekFromHTML([]byte(html), now)
		if !errors.Is(err, ErrCurrentWeekUnavailable) {
			t.Fatalf("unexpected error for %s: %v", html, err)
		}
	}
	week, err := currentWeekFromHTML([]byte(`datedifference(s1, '2030-08-31')`), now)
	if err != nil || week.CurrentWeek != 2 {
		t.Fatalf("unexpected upstream fallback: %+v, %v", week, err)
	}
}
