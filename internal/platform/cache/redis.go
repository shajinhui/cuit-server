package cache

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisStore struct {
	client *redis.Client
}

func OpenRedis(ctx context.Context, rawURL string) (*RedisStore, error) {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		return nil, fmt.Errorf("redis: REDIS_URL is required")
	}
	options, err := redis.ParseURL(rawURL)
	if err != nil {
		// 配置地址可能含认证信息，解析失败时不能把原值拼进日志。
		return nil, fmt.Errorf("redis: invalid REDIS_URL")
	}
	client := redis.NewClient(options)
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("redis: ping: %w", err)
	}
	return &RedisStore{client: client}, nil
}

func (s *RedisStore) Get(ctx context.Context, key string) ([]byte, error) {
	value, err := s.client.Get(ctx, key).Bytes()
	if errors.Is(err, redis.Nil) {
		return nil, ErrMiss
	}
	if err != nil {
		return nil, fmt.Errorf("redis: get: %w", err)
	}
	return value, nil
}

func (s *RedisStore) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	if err := s.client.Set(ctx, key, value, ttl).Err(); err != nil {
		return fmt.Errorf("redis: set: %w", err)
	}
	return nil
}

func (s *RedisStore) Delete(ctx context.Context, key string) error {
	if err := s.client.Del(ctx, key).Err(); err != nil {
		return fmt.Errorf("redis: delete: %w", err)
	}
	return nil
}

func (s *RedisStore) Stats(ctx context.Context) (StoreStats, error) {
	keys, err := s.client.DBSize(ctx).Result()
	if err != nil {
		return StoreStats{Enabled: true}, fmt.Errorf("redis: read key count: %w", err)
	}
	memoryInfo, err := s.client.Info(ctx, "memory").Result()
	if err != nil {
		return StoreStats{Enabled: true}, fmt.Errorf("redis: read memory info: %w", err)
	}
	statsInfo, err := s.client.Info(ctx, "stats").Result()
	if err != nil {
		return StoreStats{Enabled: true}, fmt.Errorf("redis: read stats info: %w", err)
	}
	memoryBytes, err := infoUint(memoryInfo, "used_memory")
	if err != nil {
		return StoreStats{Enabled: true}, err
	}
	evictedKeys, err := infoUint(statsInfo, "evicted_keys")
	if err != nil {
		return StoreStats{Enabled: true}, err
	}
	expiredKeys, err := infoUint(statsInfo, "expired_keys")
	if err != nil {
		return StoreStats{Enabled: true}, err
	}
	return StoreStats{
		Enabled:     true,
		Reachable:   true,
		Keys:        keys,
		MemoryBytes: memoryBytes,
		EvictedKeys: evictedKeys,
		ExpiredKeys: expiredKeys,
	}, nil
}

func infoUint(info string, name string) (uint64, error) {
	prefix := name + ":"
	for line := range strings.SplitSeq(info, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, prefix) {
			continue
		}
		value, err := strconv.ParseUint(strings.TrimSpace(strings.TrimPrefix(line, prefix)), 10, 64)
		if err != nil {
			return 0, fmt.Errorf("redis: parse %s: %w", name, err)
		}
		return value, nil
	}
	return 0, fmt.Errorf("redis: %s not found in INFO", name)
}

func (s *RedisStore) Close() error {
	return s.client.Close()
}
