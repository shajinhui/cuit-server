package analytics

import (
	"context"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/cloudwego/hertz/pkg/app"
)

const defaultFlushInterval = time.Minute

type UserResolver interface {
	ResolveUserID(ctx context.Context, sessionID string) (int64, error)
}

type requestKey struct {
	hour        string
	method      string
	route       string
	statusClass int
}

type activityKey struct {
	day    string
	userID int64
}

type Collector struct {
	repository    *Repository
	userResolver  UserResolver
	sessionCookie string
	flushInterval time.Duration
	now           func() time.Time
	mu            sync.Mutex
	requests      map[requestKey]RequestMetric
	activities    map[activityKey]UserActivity
	devices       map[int64]UserDevice
	stop          chan struct{}
	done          chan struct{}
	startOnce     sync.Once
	stopOnce      sync.Once
}

func NewCollector(
	repository *Repository,
	userResolver UserResolver,
	sessionCookie string,
	flushInterval time.Duration,
) *Collector {
	if flushInterval <= 0 {
		flushInterval = defaultFlushInterval
	}
	return &Collector{
		repository:    repository,
		userResolver:  userResolver,
		sessionCookie: sessionCookie,
		flushInterval: flushInterval,
		now:           time.Now,
		requests:      make(map[requestKey]RequestMetric),
		activities:    make(map[activityKey]UserActivity),
		devices:       make(map[int64]UserDevice),
		stop:          make(chan struct{}),
		done:          make(chan struct{}),
	}
}

func (c *Collector) Start() {
	c.startOnce.Do(func() {
		go c.flushLoop()
	})
}

func (c *Collector) Stop(ctx context.Context) error {
	c.Start()
	c.stopOnce.Do(func() {
		close(c.stop)
	})
	select {
	case <-c.done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (c *Collector) Middleware() app.HandlerFunc {
	return func(ctx context.Context, request *app.RequestContext) {
		startedAt := c.now()
		request.Next(ctx)

		route := request.FullPath()
		if !trackRoute(route) {
			return
		}
		status := request.Response.StatusCode()
		if status == 0 {
			status = http.StatusOK
		}
		finishedAt := c.now()
		duration := finishedAt.Sub(startedAt)
		if duration < 0 {
			duration = 0
		}

		var userID int64
		if status >= 200 && status < 400 && c.userResolver != nil {
			sessionID := string(request.Cookie(c.sessionCookie))
			if strings.TrimSpace(sessionID) != "" {
				resolveCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
				userID, _ = c.userResolver.ResolveUserID(resolveCtx, sessionID)
				cancel()
			}
		}
		c.Record(
			finishedAt,
			string(request.Method()),
			route,
			status,
			duration,
			userID,
		)
		c.recordDevice(
			finishedAt,
			userID,
			string(request.GetHeader("X-Client-Platform")),
			string(request.GetHeader("X-Client-Brand")),
		)
	}
}

func (c *Collector) Record(
	at time.Time,
	method string,
	route string,
	status int,
	duration time.Duration,
	userID int64,
) {
	hour := at.UTC().Truncate(time.Hour).Format(time.RFC3339)
	durationMS := duration.Milliseconds()
	key := requestKey{
		hour:        hour,
		method:      method,
		route:       route,
		statusClass: status / 100,
	}
	c.mu.Lock()
	metric := c.requests[key]
	metric.Hour = hour
	metric.Method = method
	metric.Route = route
	metric.StatusClass = status / 100
	metric.RequestCount++
	metric.DurationMSTotal += durationMS
	metric.DurationMSMax = max(metric.DurationMSMax, durationMS)
	c.requests[key] = metric

	if userID > 0 {
		day := at.In(chinaLocation).Format(time.DateOnly)
		key := activityKey{day: day, userID: userID}
		activity := c.activities[key]
		activity.Day = day
		activity.UserID = userID
		activity.RequestCount++
		if activity.FirstSeenAt.IsZero() || at.Before(activity.FirstSeenAt) {
			activity.FirstSeenAt = at
		}
		if activity.LastSeenAt.IsZero() || at.After(activity.LastSeenAt) {
			activity.LastSeenAt = at
		}
		c.activities[key] = activity
	}
	c.mu.Unlock()
}

func (c *Collector) recordDevice(at time.Time, userID int64, platform string, brand string) {
	platform = strings.ToLower(strings.TrimSpace(platform))
	if userID <= 0 || (platform != "ios" && platform != "android") {
		return
	}
	brand = normalizeBrand(platform, brand)

	c.mu.Lock()
	device := c.devices[userID]
	device.UserID = userID
	device.Platform = platform
	device.Brand = brand
	if device.FirstSeenAt.IsZero() || at.Before(device.FirstSeenAt) {
		device.FirstSeenAt = at
	}
	if device.LastSeenAt.IsZero() || at.After(device.LastSeenAt) {
		device.LastSeenAt = at
	}
	c.devices[userID] = device
	c.mu.Unlock()
}

func normalizeBrand(platform string, brand string) string {
	if platform == "ios" {
		return "Apple"
	}
	brand = strings.TrimSpace(brand)
	if brand == "Other" {
		return "其他 Android"
	}
	allowed := map[string]struct{}{
		"ASUS": {}, "Google": {}, "Honor": {}, "Huawei": {}, "iQOO": {}, "Lenovo": {},
		"Meizu": {}, "Motorola": {}, "Nothing": {}, "Nubia": {}, "OnePlus": {},
		"OPPO": {}, "POCO": {}, "realme": {}, "Redmi": {}, "Samsung": {},
		"vivo": {}, "Xiaomi": {}, "ZTE": {}, "其他 Android": {},
	}
	if _, ok := allowed[brand]; ok {
		return brand
	}
	return "其他 Android"
}

func (c *Collector) Flush(ctx context.Context) error {
	c.mu.Lock()
	requests := c.requests
	activities := c.activities
	devices := c.devices
	c.requests = make(map[requestKey]RequestMetric)
	c.activities = make(map[activityKey]UserActivity)
	c.devices = make(map[int64]UserDevice)
	c.mu.Unlock()

	requestBatch := make([]RequestMetric, 0, len(requests))
	for _, metric := range requests {
		requestBatch = append(requestBatch, metric)
	}
	activityBatch := make([]UserActivity, 0, len(activities))
	for _, activity := range activities {
		activityBatch = append(activityBatch, activity)
	}
	deviceBatch := make([]UserDevice, 0, len(devices))
	for _, device := range devices {
		deviceBatch = append(deviceBatch, device)
	}
	if err := c.repository.Flush(ctx, requestBatch, activityBatch, deviceBatch); err != nil {
		c.restore(requests, activities, devices)
		return err
	}
	return nil
}

func (c *Collector) Stats(ctx context.Context, days int) (Stats, error) {
	if err := c.Flush(ctx); err != nil {
		return Stats{}, err
	}
	return c.repository.Stats(ctx, days, c.now())
}

func (c *Collector) flushLoop() {
	defer close(c.done)
	ticker := time.NewTicker(c.flushInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			if err := c.Flush(ctx); err != nil {
				log.Printf("写入统计数据失败: %v", err)
			}
			cancel()
		case <-c.stop:
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			if err := c.Flush(ctx); err != nil {
				log.Printf("关闭前写入统计数据失败: %v", err)
			}
			cancel()
			return
		}
	}
}

func (c *Collector) restore(
	requests map[requestKey]RequestMetric,
	activities map[activityKey]UserActivity,
	devices map[int64]UserDevice,
) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for key, failed := range requests {
		current := c.requests[key]
		failed.RequestCount += current.RequestCount
		failed.DurationMSTotal += current.DurationMSTotal
		failed.DurationMSMax = max(failed.DurationMSMax, current.DurationMSMax)
		c.requests[key] = failed
	}
	for key, failed := range activities {
		current := c.activities[key]
		failed.RequestCount += current.RequestCount
		if failed.FirstSeenAt.IsZero() ||
			(!current.FirstSeenAt.IsZero() && current.FirstSeenAt.Before(failed.FirstSeenAt)) {
			failed.FirstSeenAt = current.FirstSeenAt
		}
		if current.LastSeenAt.After(failed.LastSeenAt) {
			failed.LastSeenAt = current.LastSeenAt
		}
		c.activities[key] = failed
	}
	for userID, failed := range devices {
		current := c.devices[userID]
		if !current.LastSeenAt.IsZero() && current.LastSeenAt.After(failed.LastSeenAt) {
			failed.Platform = current.Platform
			failed.Brand = current.Brand
			failed.LastSeenAt = current.LastSeenAt
		}
		if failed.FirstSeenAt.IsZero() ||
			(!current.FirstSeenAt.IsZero() && current.FirstSeenAt.Before(failed.FirstSeenAt)) {
			failed.FirstSeenAt = current.FirstSeenAt
		}
		c.devices[userID] = failed
	}
}

func trackRoute(route string) bool {
	return strings.HasPrefix(route, "/api/") &&
		route != "/api/v1/health" &&
		route != "/api/v1/admin/stats"
}
