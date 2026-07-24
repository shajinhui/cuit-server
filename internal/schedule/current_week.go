package schedule

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"time"
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

// CalendarClient 从教务处公开主页读取校历周次，不需要教务登录会话。
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
	return currentWeekFromHTML(body, c.now())
}

func currentWeekFromHTML(body []byte, now time.Time) (CurrentWeek, error) {
	match := weekAnchorPattern.FindSubmatch(body)
	if len(match) != 2 {
		return CurrentWeek{}, fmt.Errorf("%w: week anchor not found", ErrCurrentWeekUnavailable)
	}
	anchor, err := time.ParseInLocation(time.DateOnly, string(match[1]), chinaLocation)
	if err != nil {
		return CurrentWeek{}, fmt.Errorf("%w: parse week anchor: %w", ErrCurrentWeekUnavailable, err)
	}

	// 官网把锚点日记为第 0 天，并用 ceil(相差天数/7) 显示当前周次，这里保持同一规则。
	today := now.In(chinaLocation)
	today = time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, chinaLocation)
	days := int(today.Sub(anchor).Hours() / 24)
	if days < 0 {
		days = -days
	}
	return CurrentWeek{CurrentWeek: (days + 6) / 7}, nil
}
