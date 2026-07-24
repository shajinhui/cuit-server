package schedule

import (
	"errors"
	"testing"
	"time"
)

func TestCurrentWeekFromHTML(t *testing.T) {
	html := []byte(`<script>
var day = datedifference(s1, '2026-02-28');
var d = Math.ceil(day / 7);
</script>`)
	now := time.Date(2026, time.July, 22, 16, 0, 0, 0, chinaLocation)

	week, err := currentWeekFromHTML(html, now)
	if err != nil {
		t.Fatal(err)
	}
	if week.CurrentWeek != 21 {
		t.Fatalf("unexpected current week: %d", week.CurrentWeek)
	}
}

func TestCurrentWeekFromHTMLRequiresAnchor(t *testing.T) {
	_, err := currentWeekFromHTML([]byte(`<html></html>`), time.Now())
	if !errors.Is(err, ErrCurrentWeekUnavailable) {
		t.Fatalf("unexpected error: %v", err)
	}
}
