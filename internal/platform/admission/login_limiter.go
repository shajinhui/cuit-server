package admission

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

// 登录失败限流：按学号和 IP 分别计数，窗口内失败次数达到阈值后锁定一段时间。
// 只有密码错误（401）才会调用 Fail，教务网络故障不计数，避免误锁用户。
const (
	loginFailWindow    = 10 * time.Minute // 失败计数窗口
	loginFailLock      = 15 * time.Minute // 锁定时间
	loginFailTimeout   = 2 * time.Second  // 限流 Redis 操作超时
	loginFailAccScope  = "acc"            // 学号维度
	loginFailIPScope   = "ip"             // IP 维度
)

func init() {
	if loginFailWindow >= loginFailLock {
		panic("login limiter: fail window must be shorter than lock duration")
	}
}

// failScript 原子地完成计数、设置窗口过期，并在达到阈值时写入锁。
var failScript = redis.NewScript(`
local count = redis.call('INCR', KEYS[1])
if count == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[1])
end
if count >= tonumber(ARGV[2]) then
    redis.call('SET', KEYS[2], '1', 'EX', ARGV[3])
end
return count
`)

// LoginLimiter 使用 Redis 保存登录失败计数与锁，进程重启后状态不丢失。
type LoginLimiter struct {
	client          *redis.Client
	maxAccountFails int64
	maxIPFails      int64
}

func NewLoginLimiter(client *redis.Client, maxAccountFails, maxIPFails int) (*LoginLimiter, error) {
	if client == nil {
		return nil, errors.New("login limiter: redis client must not be nil")
	}
	if maxAccountFails < 1 {
		return nil, fmt.Errorf("login limiter: max account failures must be positive, got %d", maxAccountFails)
	}
	if maxIPFails < 1 {
		return nil, fmt.Errorf("login limiter: max IP failures must be positive, got %d", maxIPFails)
	}
	return &LoginLimiter{
		client:          client,
		maxAccountFails: int64(maxAccountFails),
		maxIPFails:      int64(maxIPFails),
	}, nil
}

// Check 返回是否被锁定及剩余锁定时间。
func (l *LoginLimiter) Check(ctx context.Context, studentNo, ip string) (time.Duration, bool) {
	ctx, cancel := context.WithTimeout(ctx, loginFailTimeout)
	defer cancel()
	var maxTTL time.Duration
	for _, key := range []string{loginLockKey(loginFailAccScope, studentNo), loginLockKey(loginFailIPScope, ip)} {
		ttl, err := l.client.TTL(ctx, key).Result()
		if err != nil {
			// Redis 不可用时放行，保证登录主流程不因限流组件不可用而中断。
			log.Printf("login limiter: check ttl: %v", err)
			return 0, false
		}
		if ttl > maxTTL {
			maxTTL = ttl
		}
	}
	if maxTTL > 0 {
		return maxTTL, true
	}
	return 0, false
}

// Fail 记录一次密码错误，达到阈值后锁定对应学号和 IP。
func (l *LoginLimiter) Fail(ctx context.Context, studentNo, ip string) {
	ctx, cancel := context.WithTimeout(ctx, loginFailTimeout)
	defer cancel()
	l.record(ctx, loginFailAccScope, studentNo, l.maxAccountFails)
	l.record(ctx, loginFailIPScope, ip, l.maxIPFails)
}

func (l *LoginLimiter) record(ctx context.Context, scope, value string, maxFails int64) {
	err := failScript.Run(ctx, l.client,
		[]string{loginFailKey(scope, value), loginLockKey(scope, value)},
		int64(loginFailWindow/time.Second), maxFails, int64(loginFailLock/time.Second),
	).Err()
	if err != nil {
		log.Printf("login limiter: record failure: %v", err)
	}
}

// Reset 登录成功后清空该学号的失败计数与锁。
// 不清除 IP 维度的状态，避免攻击者猜对一个学号后解锁 IP 继续爆破其他学号。
func (l *LoginLimiter) Reset(ctx context.Context, studentNo string) {
	ctx, cancel := context.WithTimeout(ctx, loginFailTimeout)
	defer cancel()
	keys := []string{
		loginFailKey(loginFailAccScope, studentNo), loginLockKey(loginFailAccScope, studentNo),
	}
	if err := l.client.Del(ctx, keys...).Err(); err != nil {
		log.Printf("login limiter: reset: %v", err)
	}
}

func loginFailKey(scope, value string) string { return "login:fail:" + scope + ":" + value }
func loginLockKey(scope, value string) string { return "login:lock:" + scope + ":" + value }

// DisabledLoginLimiter 未配置 Redis 时使用，登录流程不依赖 Redis。
type DisabledLoginLimiter struct{}

func (DisabledLoginLimiter) Check(context.Context, string, string) (time.Duration, bool) {
	return 0, false
}

func (DisabledLoginLimiter) Fail(context.Context, string, string) {}

func (DisabledLoginLimiter) Reset(context.Context, string) {}
