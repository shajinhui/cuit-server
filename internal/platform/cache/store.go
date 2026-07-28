package cache

import (
	"context"
	"errors"
	"time"
)

var ErrMiss = errors.New("cache: key not found")

// Store 只描述业务缓存需要的字符串键值操作，业务层不依赖具体 Redis 客户端。
type Store interface {
	Get(ctx context.Context, key string) ([]byte, error)
	Set(ctx context.Context, key string, value []byte, ttl time.Duration) error
	Delete(ctx context.Context, key string) error
}

// DisabledStore 在未配置或暂时无法连接 Redis 时保持 Cache-Aside 主流程可用。
type DisabledStore struct{}

func (DisabledStore) Get(context.Context, string) ([]byte, error) {
	return nil, ErrMiss
}

func (DisabledStore) Set(context.Context, string, []byte, time.Duration) error {
	return nil
}

func (DisabledStore) Delete(context.Context, string) error {
	return nil
}
