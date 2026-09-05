package academiccalendar

import (
	"testing"
	"time"
)

func TestPublishedCalendarData(t *testing.T) {
	calendars, err := List()
	if err != nil {
		t.Fatal(err)
	}
	if len(calendars) == 0 {
		t.Fatal("empty calendar data")
	}
	seen := make(map[string]bool)
	for _, calendar := range calendars {
		key := calendar.SchoolYear + "/" + calendar.Term
		if seen[key] {
			t.Fatalf("duplicate semester %s", key)
		}
		seen[key] = true
		monday, err := time.Parse(time.DateOnly, calendar.FirstWeekMonday)
		if err != nil || monday.Weekday() != time.Monday || calendar.WeekCount < 1 || calendar.Source == "" {
			t.Fatalf("invalid calendar: %+v", calendar)
		}
	}
}
