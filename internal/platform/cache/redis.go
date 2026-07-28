package cache

import (
	"context"
	"errors"
	"fmt"
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

func (s *RedisStore) Close() error {
	return s.client.Close()
}
