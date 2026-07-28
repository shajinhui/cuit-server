package cache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"sync/atomic"
	"time"

	"golang.org/x/sync/singleflight"
)

// Loader 实现 Cache-Aside，并合并同一进程内同时发生的同 Key 冷缓存请求。
type Loader struct {
	store       Store
	group       singleflight.Group
	startedAt   time.Time
	requests    atomic.Uint64
	hits        atomic.Uint64
	sourceLoads atomic.Uint64
	coalesced   atomic.Uint64
	readErrors  atomic.Uint64
	writeErrors atomic.Uint64
}

func NewLoader(store Store) *Loader {
	if store == nil {
		store = DisabledStore{}
	}
	return &Loader{store: store, startedAt: time.Now().UTC()}
}

func GetOrLoad[T any](
	ctx context.Context,
	loader *Loader,
	key string,
	ttl time.Duration,
	source func(context.Context) (T, error),
) (T, error) {
	var zero T
	loader.requests.Add(1)
	if value, found := readJSON[T](ctx, loader, key); found {
		loader.hits.Add(1)
		return value, nil
	}

	executed := false
	resultChannel := loader.group.DoChan(key, func() (any, error) {
		executed = true
		// 等待进入 singleflight 期间，其他请求可能已经写入 Redis，因此需要再次读取。
		if value, found := readJSON[T](ctx, loader, key); found {
			loader.hits.Add(1)
			return value, nil
		}
		loader.sourceLoads.Add(1)
		value, err := source(ctx)
		if err != nil {
			return nil, err
		}
		writeJSON(ctx, loader, key, value, ttl)
		return value, nil
	})

	select {
	case <-ctx.Done():
		return zero, ctx.Err()
	case result := <-resultChannel:
		if result.Err != nil {
			return zero, result.Err
		}
		value, ok := result.Val.(T)
		if !ok {
			return zero, fmt.Errorf("cache: unexpected value type for key %s", key)
		}
		if !executed {
			loader.coalesced.Add(1)
		}
		return value, nil
	}
}

type Snapshot struct {
	Enabled           bool      `json:"enabled"`
	Reachable         bool      `json:"reachable"`
	StartedAt         time.Time `json:"started_at"`
	Requests          uint64    `json:"requests"`
	Hits              uint64    `json:"hits"`
	SourceLoads       uint64    `json:"source_loads"`
	CoalescedRequests uint64    `json:"coalesced_requests"`
	ReadErrors        uint64    `json:"read_errors"`
	WriteErrors       uint64    `json:"write_errors"`
	Keys              int64     `json:"keys"`
	MemoryBytes       uint64    `json:"memory_bytes"`
	EvictedKeys       uint64    `json:"evicted_keys"`
	ExpiredKeys       uint64    `json:"expired_keys"`
}

// Snapshot 返回自当前 API 进程启动以来的应用缓存指标和 Redis 运行状态。
func (l *Loader) Snapshot(ctx context.Context) Snapshot {
	snapshot := Snapshot{
		StartedAt:         l.startedAt,
		Requests:          l.requests.Load(),
		Hits:              l.hits.Load(),
		SourceLoads:       l.sourceLoads.Load(),
		CoalescedRequests: l.coalesced.Load(),
		ReadErrors:        l.readErrors.Load(),
		WriteErrors:       l.writeErrors.Load(),
	}
	reader, ok := l.store.(StoreStatsReader)
	if !ok {
		return snapshot
	}
	storeStats, err := reader.Stats(ctx)
	snapshot.Enabled = storeStats.Enabled
	if err != nil {
		return snapshot
	}
	snapshot.Reachable = storeStats.Reachable
	snapshot.Keys = storeStats.Keys
	snapshot.MemoryBytes = storeStats.MemoryBytes
	snapshot.EvictedKeys = storeStats.EvictedKeys
	snapshot.ExpiredKeys = storeStats.ExpiredKeys
	return snapshot
}

func readJSON[T any](ctx context.Context, loader *Loader, key string) (T, bool) {
	var zero T
	data, err := loader.store.Get(ctx, key)
	if err != nil {
		if !errors.Is(err, ErrMiss) {
			loader.readErrors.Add(1)
			log.Printf("读取 Redis 缓存失败: key=%s: %v", key, err)
		}
		return zero, false
	}
	var value T
	if err := json.Unmarshal(data, &value); err != nil {
		log.Printf("解析 Redis 缓存失败: key=%s: %v", key, err)
		if deleteErr := loader.store.Delete(ctx, key); deleteErr != nil {
			log.Printf("删除无效 Redis 缓存失败: key=%s: %v", key, deleteErr)
		}
		return zero, false
	}
	return value, true
}

func writeJSON[T any](ctx context.Context, loader *Loader, key string, value T, ttl time.Duration) {
	data, err := json.Marshal(value)
	if err != nil {
		log.Printf("编码 Redis 缓存失败: key=%s: %v", key, err)
		return
	}
	if err := loader.store.Set(ctx, key, data, ttl); err != nil {
		loader.writeErrors.Add(1)
		log.Printf("写入 Redis 缓存失败: key=%s: %v", key, err)
	}
}
