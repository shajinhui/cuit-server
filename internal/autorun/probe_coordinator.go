package autorun

import (
	"context"
	"sync"
	"time"

	"cuit-server/internal/autorun/store"
	"cuit-server/internal/autorun/upstream"
)

const (
	// 已开放活动的公共编号和坐标在短时间内不会变化。缓存时间不宜过长，
	// 避免跨越活动状态切换边界。
	activityProbeOpenTTL = 30 * time.Second
	// “尚未开放”可能来自候选学生的个人状态，只做很短的抑制，既能合并
	// 同一波请求，也不会让整组学生长时间受单个候选状态影响。
	activityProbeClosedTTL = 5 * time.Second
	// 签退入口只对已签到学生可见。探测账号一旦发现签退开放，就把活动公共
	// 编号和坐标保留到整个签退窗口结束，供其余学生复用。
	activitySignBackOpenTTL   = 30 * time.Minute
	activitySignBackClosedTTL = 30 * time.Second
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

type activityProbeCandidates struct {
	studentIDs map[int64]struct{}
	expiresAt  time.Time
}

// activityProbeCoordinator 将同一活动、同一签到阶段的并发探测折叠为一次
// 上游请求。个人登录态错误不共享：候选学生 token 过期时，等待者会改用
// 自己的会话再次竞选 leader。超时等基础设施错误则共享给本波等待者，避免
// 所有人依次重试，把一次故障放大成一整组请求。
type activityProbeCoordinator struct {
	mu         sync.Mutex
	cache      map[activityProbeKey]activityProbeCacheEntry
	inflight   map[activityProbeKey]*activityProbeCall
	candidates map[activityProbeKey]activityProbeCandidates
	now        func() time.Time
}

func newActivityProbeCoordinator() *activityProbeCoordinator {
	return &activityProbeCoordinator{
		cache:      make(map[activityProbeKey]activityProbeCacheEntry),
		inflight:   make(map[activityProbeKey]*activityProbeCall),
		candidates: make(map[activityProbeKey]activityProbeCandidates),
		now:        time.Now,
	}
}

// OpenResult returns only a still-valid open result. Callers outside the small
// sign-back candidate pool use this to reuse public activity data without
// issuing their own upstream probe.
func (c *activityProbeCoordinator) OpenResult(key activityProbeKey) (activityProbeResult, bool) {
	now := c.now()
	c.mu.Lock()
	defer c.mu.Unlock()
	cached, ok := c.cache[key]
	if !ok {
		return activityProbeResult{}, false
	}
	if !now.Before(cached.expiresAt) {
		delete(c.cache, key)
		return activityProbeResult{}, false
	}
	if !cached.result.Open {
		return activityProbeResult{}, false
	}
	return cached.result, true
}

// ReserveCandidate keeps at most limit distinct students as upstream
// sign-back probes for one activity window.
func (c *activityProbeCoordinator) ReserveCandidate(
	key activityProbeKey,
	studentID int64,
	limit int,
	expiresAt time.Time,
) bool {
	if studentID <= 0 || limit <= 0 {
		return false
	}
	now := c.now()
	c.mu.Lock()
	defer c.mu.Unlock()
	for candidateKey, pool := range c.candidates {
		if !now.Before(pool.expiresAt) {
			delete(c.candidates, candidateKey)
		}
	}
	pool, ok := c.candidates[key]
	if !ok {
		pool = activityProbeCandidates{studentIDs: make(map[int64]struct{}), expiresAt: expiresAt}
	}
	if _, exists := pool.studentIDs[studentID]; exists {
		return true
	}
	if len(pool.studentIDs) >= limit {
		return false
	}
	pool.studentIDs[studentID] = struct{}{}
	if expiresAt.After(pool.expiresAt) {
		pool.expiresAt = expiresAt
	}
	c.candidates[key] = pool
	return true
}

func (c *activityProbeCoordinator) ReleaseCandidate(key activityProbeKey, studentID int64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	pool, ok := c.candidates[key]
	if !ok {
		return
	}
	delete(pool.studentIDs, studentID)
	if len(pool.studentIDs) == 0 {
		delete(c.candidates, key)
		return
	}
	c.candidates[key] = pool
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
					if upstream.IsTokenExpired(call.err) {
						// 仅个人登录态错误重新竞选 leader。
						continue
					}
					return activityProbeResult{}, call.err
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
			if key.SignType == store.SignBackType {
				ttl = activitySignBackClosedTTL
			}
			if result.Open && key.SignType == store.SignBackType {
				ttl = activitySignBackOpenTTL
			} else if result.Open {
				ttl = activityProbeOpenTTL
			}
			c.cache[key] = activityProbeCacheEntry{result: result, expiresAt: c.now().Add(ttl)}
		}
		close(call.done)
		c.mu.Unlock()
		return result, err
	}
}
