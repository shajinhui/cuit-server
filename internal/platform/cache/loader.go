package cache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"golang.org/x/sync/singleflight"
)

// Loader 实现 Cache-Aside，并合并同一进程内同时发生的同 Key 冷缓存请求。
type Loader struct {
	store Store
	group singleflight.Group
}

func NewLoader(store Store) *Loader {
	if store == nil {
		store = DisabledStore{}
	}
	return &Loader{store: store}
}

func GetOrLoad[T any](
	ctx context.Context,
	loader *Loader,
	key string,
	ttl time.Duration,
	source func(context.Context) (T, error),
) (T, error) {
	var zero T
	if value, found := readJSON[T](ctx, loader.store, key); found {
		return value, nil
	}

	resultChannel := loader.group.DoChan(key, func() (any, error) {
		// 等待进入 singleflight 期间，其他请求可能已经写入 Redis，因此需要再次读取。
		if value, found := readJSON[T](ctx, loader.store, key); found {
			return value, nil
		}
		value, err := source(ctx)
		if err != nil {
			return nil, err
		}
		writeJSON(ctx, loader.store, key, value, ttl)
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
		return value, nil
	}
}

func readJSON[T any](ctx context.Context, store Store, key string) (T, bool) {
	var zero T
	data, err := store.Get(ctx, key)
	if err != nil {
		if !errors.Is(err, ErrMiss) {
			log.Printf("读取 Redis 缓存失败: key=%s: %v", key, err)
		}
		return zero, false
	}
	var value T
	if err := json.Unmarshal(data, &value); err != nil {
		log.Printf("解析 Redis 缓存失败: key=%s: %v", key, err)
		if deleteErr := store.Delete(ctx, key); deleteErr != nil {
			log.Printf("删除无效 Redis 缓存失败: key=%s: %v", key, deleteErr)
		}
		return zero, false
	}
	return value, true
}

func writeJSON[T any](ctx context.Context, store Store, key string, value T, ttl time.Duration) {
	data, err := json.Marshal(value)
	if err != nil {
		log.Printf("编码 Redis 缓存失败: key=%s: %v", key, err)
		return
	}
	if err := store.Set(ctx, key, data, ttl); err != nil {
		log.Printf("写入 Redis 缓存失败: key=%s: %v", key, err)
	}
}
