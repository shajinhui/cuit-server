package cache

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"
)

// 该测试仅在显式提供 Redis 地址时运行，默认测试不依赖外部服务。
func TestRedisStoreIntegration(t *testing.T) {
	rawURL := os.Getenv("REDIS_TEST_URL")
	if rawURL == "" {
		t.Skip("REDIS_TEST_URL is not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	store, err := OpenRedis(ctx, rawURL)
	if err != nil {
		t.Fatalf("open Redis: %v", err)
	}
	defer store.Close()

	const key = "cuit-server:test:redis-store"
	t.Cleanup(func() {
		_ = store.Delete(context.Background(), key)
	})

	if err := store.Set(ctx, key, []byte(`{"ok":true}`), 50*time.Millisecond); err != nil {
		t.Fatalf("set value: %v", err)
	}

	value, err := store.Get(ctx, key)
	if err != nil {
		t.Fatalf("get value: %v", err)
	}
	if got, want := string(value), `{"ok":true}`; got != want {
		t.Fatalf("value = %q, want %q", got, want)
	}

	time.Sleep(100 * time.Millisecond)
	if _, err := store.Get(ctx, key); !errors.Is(err, ErrMiss) {
		t.Fatalf("get expired value error = %v, want ErrMiss", err)
	}

	if err := store.Set(ctx, key, []byte(`{"ok":true}`), time.Minute); err != nil {
		t.Fatalf("set value before delete: %v", err)
	}
	if err := store.Delete(ctx, key); err != nil {
		t.Fatalf("delete value: %v", err)
	}
	if _, err := store.Get(ctx, key); !errors.Is(err, ErrMiss) {
		t.Fatalf("get deleted value error = %v, want ErrMiss", err)
	}
}
