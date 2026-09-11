package autorun

import (
	"context"
	"sync"
	"time"

	"cuit-server/internal/autorun/store"
)

const (
	// 已开放活动的公共编号和坐标在短时间内不会变化。缓存时间不宜过长，
	// 避免跨越活动状态切换边界。
	activityProbeOpenTTL = 30 * time.Second
	// “尚未开放”可能来自候选学生的个人状态，只做很短的抑制，既能合并
	// 同一波请求，也不会让整组学生长时间受单个候选状态影响。
	activityProbeClosedTTL = 5 * time.Second
)

type activityProbeKey struct {
	SchoolID   int64
	ActivityID int64
	SignType   store.SignType
}

// activityProbeResult 只包含可以在同一活动参与者之间共享的字段。学生个人
// 签到状态、token 和 studentID 绝不能进入缓存。
type activityProbeResult struct {
	Open       bool
	ActivityID int64
	Latitude   string
	Longitude  string
	Message    string
}

type activityProbeCacheEntry struct {
	result    activityProbeResult
	expiresAt time.Time
}

type activityProbeCall struct {
	done   chan struct{}
	result activityProbeResult
	err    error
}

// activityProbeCoordinator 将同一活动、同一签到阶段的并发探测折叠为一次
// 上游请求。错误不缓存也不共享：例如候选学生 token 过期时，等待者会改用
// 自己的会话再次竞选 leader，不会把个人认证错误扩散给整组用户。
type activityProbeCoordinator struct {
	mu       sync.Mutex
	cache    map[activityProbeKey]activityProbeCacheEntry
	inflight map[activityProbeKey]*activityProbeCall
	now      func() time.Time
}

func newActivityProbeCoordinator() *activityProbeCoordinator {
	return &activityProbeCoordinator{
		cache:    make(map[activityProbeKey]activityProbeCacheEntry),
		inflight: make(map[activityProbeKey]*activityProbeCall),
		now:      time.Now,
	}
}

func (c *activityProbeCoordinator) Do(
	ctx context.Context,
	key activityProbeKey,
	probe func(context.Context) (activityProbeResult, error),
) (activityProbeResult, error) {
	for {
		if err := ctx.Err(); err != nil {
			return activityProbeResult{}, err
		}

		now := c.now()
		c.mu.Lock()
		if cached, ok := c.cache[key]; ok {
			if now.Before(cached.expiresAt) {
				c.mu.Unlock()
				return cached.result, nil
			}
			delete(c.cache, key)
		}
		if call, ok := c.inflight[key]; ok {
			c.mu.Unlock()
			select {
			case <-ctx.Done():
				return activityProbeResult{}, ctx.Err()
			case <-call.done:
				if call.err != nil {
					// 上一次失败通常只代表 leader 的个人会话不可用。
					// 重新进入循环，让一个等待者使用自己的会话探测。
					continue
				}
				return call.result, nil
			}
		}

		call := &activityProbeCall{done: make(chan struct{})}
		c.inflight[key] = call
		c.mu.Unlock()

		result, err := probe(ctx)
		c.mu.Lock()
		call.result = result
		call.err = err
		delete(c.inflight, key)
		if err == nil {
			ttl := activityProbeClosedTTL
			if result.Open {
				ttl = activityProbeOpenTTL
			}
			c.cache[key] = activityProbeCacheEntry{result: result, expiresAt: c.now().Add(ttl)}
		}
		close(call.done)
		c.mu.Unlock()
		return result, err
	}
}
