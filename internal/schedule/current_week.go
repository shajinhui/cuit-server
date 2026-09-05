package schedule

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"time"

	"cuit-server/shared/academiccalendar"
)

const calendarURL = "https://jwc.cuit.edu.cn/"

var (
	ErrCurrentWeekUnavailable = errors.New("schedule: current week unavailable")
	weekAnchorPattern         = regexp.MustCompile(`datedifference\s*\(\s*s1\s*,\s*['"](\d{4}-\d{2}-\d{2})['"]\s*\)`)
	chinaLocation             = time.FixedZone("Asia/Shanghai", 8*60*60)
)

type CurrentWeek struct {
	CurrentWeek int
}

// CurrentWeekService 描述 Handler 查询当前教学周所需的唯一能力。
type CurrentWeekService interface {
	GetCurrentWeek(ctx context.Context) (CurrentWeek, error)
}

// CalendarClient 优先使用已核实的公开校历，未知学年再读取教务处主页。
type CalendarClient struct {
	httpClient *http.Client
	now        func() time.Time
}

func NewCalendarClient() *CalendarClient {
	return &CalendarClient{
		httpClient: &http.Client{Timeout: 15 * time.Second},
		now:        time.Now,
	}
}

func (c *CalendarClient) GetCurrentWeek(ctx context.Context) (CurrentWeek, error) {
	now := c.now()
	if week, found, err := publishedCurrentWeek(now); found || err != nil {
		return week, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, calendarURL, nil)
	if err != nil {
		return CurrentWeek{}, fmt.Errorf("%w: build request: %w", ErrCurrentWeekUnavailable, err)
	}
	req.Header.Set("Accept", "text/html")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/131.0 Safari/537.36")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return CurrentWeek{}, fmt.Errorf("%w: GET host=jwc.cuit.edu.cn path=/: %w", ErrCurrentWeekUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return CurrentWeek{}, fmt.Errorf("%w: GET host=jwc.cuit.edu.cn path=/ status=%d", ErrCurrentWeekUnavailable, resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return CurrentWeek{}, fmt.Errorf("%w: read response: %w", ErrCurrentWeekUnavailable, err)
	}
	return currentWeekFromHTML(body, now)
}

func currentWeekFromHTML(body []byte, now time.Time) (CurrentWeek, error) {
	if week, found, err := publishedCurrentWeek(now); found || err != nil {
		return week, err
	}
	match := weekAnchorPattern.FindSubmatch(body)
	if len(match) != 2 {
		return CurrentWeek{}, fmt.Errorf("%w: week anchor not found", ErrCurrentWeekUnavailable)
	}
	anchor, err := time.ParseInLocation(time.DateOnly, string(match[1]), chinaLocation)
	if err != nil {
		return CurrentWeek{}, fmt.Errorf("%w: parse week anchor: %w", ErrCurrentWeekUnavailable, err)
	}

	today := now.In(chinaLocation)
	today = time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, chinaLocation)
	if !anchorMatchesCurrentSemester(anchor, today) {
		return CurrentWeek{}, fmt.Errorf(
			"%w: stale week anchor=%s for date=%s",
			ErrCurrentWeekUnavailable,
			anchor.Format(time.DateOnly),
			today.Format(time.DateOnly),
		)
	}

	// 官网把锚点日记为第 0 天，并用 ceil(相差天数/7) 显示当前周次，这里保持同一规则。
	days := int(today.Sub(anchor).Hours() / 24)
	if days < 0 {
		return CurrentWeek{}, fmt.Errorf(
			"%w: week anchor=%s is after date=%s",
			ErrCurrentWeekUnavailable,
			anchor.Format(time.DateOnly),
			today.Format(time.DateOnly),
		)
	}
	return CurrentWeek{CurrentWeek: (days + 6) / 7}, nil
}

func anchorMatchesCurrentSemester(anchor, today time.Time) bool {
	switch today.Month() {
	case time.September, time.October, time.November, time.December:
		return anchor.Year() == today.Year() &&
			(anchor.Month() == time.August || anchor.Month() == time.September)
	case time.January:
		return anchor.Year() == today.Year()-1 &&
			(anchor.Month() == time.August || anchor.Month() == time.September)
	default:
		return anchor.Year() == today.Year() &&
			(anchor.Month() == time.January || anchor.Month() == time.February || anchor.Month() == time.March)
	}
}

func publishedCurrentWeek(now time.Time) (CurrentWeek, bool, error) {
	today := now.In(chinaLocation)
	today = time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, chinaLocation)
	startYear := today.Year() - 1
	term := "2"
	if today.Month() >= time.September {
		startYear = today.Year()
	}
	if today.Month() == time.January || today.Month() >= time.September {
		term = "1"
	}
	calendars, err := academiccalendar.List()
	if err != nil {
		return CurrentWeek{}, false, fmt.Errorf("%w: read published calendar: %w", ErrCurrentWeekUnavailable, err)
	}
	for _, calendar := range calendars {
		if calendar.SchoolYear != fmt.Sprintf("%d-%d", startYear, startYear+1) || calendar.Term != term {
			continue
		}
		monday, err := time.ParseInLocation(time.DateOnly, calendar.FirstWeekMonday, chinaLocation)
		if err != nil || monday.Weekday() != time.Monday || calendar.WeekCount < 1 {
			return CurrentWeek{}, false, fmt.Errorf("%w: invalid published calendar %s/%s", ErrCurrentWeekUnavailable, calendar.SchoolYear, term)
		}
		days := int(today.Sub(monday).Hours() / 24)
		if days < 0 || days >= calendar.WeekCount*7 {
			return CurrentWeek{CurrentWeek: 0}, true, nil
		}
		return CurrentWeek{CurrentWeek: days/7 + 1}, true, nil
	}
	return CurrentWeek{}, false, nil
}
