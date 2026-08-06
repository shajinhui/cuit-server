package admission

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

func newTestLoginLimiter(t *testing.T, maxAccount, maxIP int) (*LoginLimiter, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	client := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = client.Close() })
	limiter, err := NewLoginLimiter(client, maxAccount, maxIP)
	if err != nil {
		t.Fatalf("NewLoginLimiter: %v", err)
	}
	return limiter, mr
}

func TestNewLoginLimiterRejectsInvalidConfiguration(t *testing.T) {
	if _, err := NewLoginLimiter(nil, 5, 20); err == nil {
		t.Fatal("nil redis client must be rejected")
	}
	mr := miniredis.RunT(t)
	client := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = client.Close() })
	if _, err := NewLoginLimiter(client, 0, 20); err == nil {
		t.Fatal("non-positive account threshold must be rejected")
	}
	if _, err := NewLoginLimiter(client, 5, 0); err == nil {
		t.Fatal("non-positive IP threshold must be rejected")
	}
}

func TestLoginLimiterLocksAccountAfterThreshold(t *testing.T) {
	limiter, mr := newTestLoginLimiter(t, 5, 20)
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		limiter.Fail(ctx, "2024125083", "203.0.113.9")
	}
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); !locked {
		t.Fatal("account must be locked after 5 failures")
	}
	// 单个学号的失败不应连带锁死共享 IP 上的其他学号。
	if _, locked := limiter.Check(ctx, "2024999999", "203.0.113.9"); locked {
		t.Fatal("shared IP must not be locked by one account's failures")
	}
	// 锁定时间到期后自动恢复。
	mr.FastForward(16 * time.Minute)
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); locked {
		t.Fatal("account lock must expire after the lock duration")
	}
}

func TestLoginLimiterLocksIPAfterThreshold(t *testing.T) {
	limiter, _ := newTestLoginLimiter(t, 100, 20)
	ctx := context.Background()
	for i := 0; i < 20; i++ {
		limiter.Fail(ctx, fmt.Sprintf("user-%d", i), "203.0.113.9")
	}
	if _, locked := limiter.Check(ctx, "someone-else", "203.0.113.9"); !locked {
		t.Fatal("IP must be locked after 20 failures")
	}
}

func TestLoginLimiterResetClearsState(t *testing.T) {
	limiter, _ := newTestLoginLimiter(t, 3, 20)
	ctx := context.Background()
	for i := 0; i < 3; i++ {
		limiter.Fail(ctx, "2024125083", "203.0.113.9")
	}
	limiter.Reset(ctx, "2024125083")
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); locked {
		t.Fatal("reset must clear the lock")
	}
	// 复位后重新计数，未达阈值不应锁定。
	limiter.Fail(ctx, "2024125083", "203.0.113.9")
	limiter.Fail(ctx, "2024125083", "203.0.113.9")
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); locked {
		t.Fatal("account must not be locked before the threshold is reached again")
	}
}

func TestLoginLimiterCountExpiresAfterWindow(t *testing.T) {
	limiter, mr := newTestLoginLimiter(t, 3, 20)
	ctx := context.Background()
	limiter.Fail(ctx, "2024125083", "203.0.113.9")
	limiter.Fail(ctx, "2024125083", "203.0.113.9")
	// 窗口过期后旧计数失效，再失败一次不应触发锁定。
	mr.FastForward(11 * time.Minute)
	limiter.Fail(ctx, "2024125083", "203.0.113.9")
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); locked {
		t.Fatal("failures outside the window must not accumulate")
	}
}

func TestLoginLimiterResetKeepsIPLock(t *testing.T) {
	limiter, _ := newTestLoginLimiter(t, 5, 20)
	ctx := context.Background()
	// 先锁住 IP：20 个不同学号各失败一次。
	for i := 0; i < 20; i++ {
		limiter.Fail(ctx, fmt.Sprintf("user-%d", i), "203.0.113.9")
	}
	// 另一个 IP 上的学号 A 失败 5 次被锁，随后登录成功。
	for i := 0; i < 5; i++ {
		limiter.Fail(ctx, "2024125083", "198.51.100.7")
	}
	limiter.Reset(ctx, "2024125083")
	// 学号维度的锁被清除，A 从自己的 IP 可以重新登录。
	if _, locked := limiter.Check(ctx, "2024125083", "198.51.100.7"); locked {
		t.Fatal("reset must clear the account lock")
	}
	// IP 维度的锁必须保留，攻击者不能靠一次成功登录解锁整个 IP。
	if _, locked := limiter.Check(ctx, "someone-else", "203.0.113.9"); !locked {
		t.Fatal("reset must not clear the IP lock")
	}
}

func TestLoginLimiterCheckReturnsLongestLock(t *testing.T) {
	limiter, mr := newTestLoginLimiter(t, 5, 20)
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		limiter.Fail(ctx, "2024125083", "203.0.113.9")
	}
	// 学号锁只剩约 30 秒时，同一 IP 达到阈值被锁 15 分钟。
	mr.FastForward(14*time.Minute + 30*time.Second)
	for i := 0; i < 20; i++ {
		limiter.Fail(ctx, fmt.Sprintf("user-%d", i), "203.0.113.9")
	}
	retryAfter, locked := limiter.Check(ctx, "2024125083", "203.0.113.9")
	if !locked {
		t.Fatal("must be locked by the IP lock")
	}
	if retryAfter < 10*time.Minute {
		t.Fatalf("Retry-After must reflect the longest lock, got %v", retryAfter)
	}
}

func TestLoginLimiterCountsFreshlyAfterLockExpires(t *testing.T) {
	limiter, mr := newTestLoginLimiter(t, 5, 20)
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		limiter.Fail(ctx, "2024125083", "203.0.113.9")
	}
	mr.FastForward(16 * time.Minute)
	// 锁和计数均已过期，需重新累计到阈值才会锁定。
	for i := 0; i < 4; i++ {
		limiter.Fail(ctx, "2024125083", "203.0.113.9")
	}
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); locked {
		t.Fatal("counter must start fresh after lock expires")
	}
	limiter.Fail(ctx, "2024125083", "203.0.113.9")
	if _, locked := limiter.Check(ctx, "2024125083", "203.0.113.9"); !locked {
		t.Fatal("must lock again after reaching the threshold")
	}
}
