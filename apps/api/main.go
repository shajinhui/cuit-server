package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"cuit-server/internal/academic"
	"cuit-server/internal/analytics"
	"cuit-server/internal/autorun"
	autorunrelay "cuit-server/internal/autorun/relay"
	autorunstore "cuit-server/internal/autorun/store"
	autorunupstream "cuit-server/internal/autorun/upstream"
	"cuit-server/internal/feedback"
	"cuit-server/internal/platform/admission"
	platformcache "cuit-server/internal/platform/cache"
	"cuit-server/internal/platform/cors"
	"cuit-server/internal/platform/database"
	"cuit-server/internal/schedule"
	"cuit-server/migrations"
	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/hertz-contrib/logger/accesslog"
	"github.com/joho/godotenv"
)

func main() {
	loadEnvironment()
	address := os.Getenv("APP_ADDR")
	if address == "" {
		address = "127.0.0.1:8888"
	}
	secureCookie := strings.EqualFold(os.Getenv("APP_COOKIE_SECURE"), "true")
	allowedOrigin := strings.TrimSpace(os.Getenv("APP_CORS_ORIGIN"))
	sqlitePath := strings.TrimSpace(os.Getenv("SQLITE_PATH"))
	if sqlitePath == "" {
		sqlitePath = "data/cuit-server.db"
	}
	startupCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	db, err := database.OpenSQLite(startupCtx, sqlitePath)
	if err != nil {
		cancel()
		log.Fatal(err)
	}
	if err := migrations.Apply(startupCtx, db); err != nil {
		cancel()
		_ = db.Close()
		log.Fatal(err)
	}
	var cacheStore platformcache.Store = platformcache.DisabledStore{}
	var redisStore *platformcache.RedisStore
	if redisURL := strings.TrimSpace(os.Getenv("REDIS_URL")); redisURL != "" {
		opened, err := platformcache.OpenRedis(startupCtx, redisURL)
		if err != nil {
			// Redis 只承载可重新获取的缓存，连接失败不能阻止登录和教务查询主流程。
			log.Printf("Redis 缓存未启用: %v", err)
		} else {
			redisStore = opened
			cacheStore = opened
			defer opened.Close()
			log.Print("Redis 缓存已启用")
		}
	} else {
		log.Print("Redis 缓存未启用：未配置 REDIS_URL")
	}
	cancel()
	defer db.Close()

	credentialKey := os.Getenv("JWXT_CREDENTIAL_KEY")
	if credentialKey == "" {
		log.Fatal("academic: JWXT_CREDENTIAL_KEY is required; configure it in .env")
	}
	credentials, err := academic.NewCredentialCipher(credentialKey)
	if err != nil {
		log.Fatal(err)
	}
	repository := academic.NewSQLiteRepository(db)
	loginMaxConcurrency, err := positiveEnvironmentInt("LOGIN_MAX_CONCURRENCY", 200)
	if err != nil {
		log.Fatal(err)
	}
	loginGate, err := admission.NewLoginGate(loginMaxConcurrency, 5*time.Second)
	if err != nil {
		log.Fatal(err)
	}
	loginFailMaxAccount, err := positiveEnvironmentInt("LOGIN_FAIL_MAX_ACCOUNT", 5)
	if err != nil {
		log.Fatal(err)
	}
	loginFailMaxIP, err := positiveEnvironmentInt("LOGIN_FAIL_MAX_IP", 20)
	if err != nil {
		log.Fatal(err)
	}
	var loginLimiter academic.LoginLimiter = admission.DisabledLoginLimiter{}
	if redisStore != nil {
		loginLimiter, err = admission.NewLoginLimiter(redisStore.Client(), loginFailMaxAccount, loginFailMaxIP)
		if err != nil {
			log.Fatal(err)
		}
	} else {
		log.Print("登录失败限流未启用：未配置 REDIS_URL")
	}
	log.Printf("登录并发上限: %d，登录失败阈值: 学号 %d 次 / IP %d 次", loginMaxConcurrency, loginFailMaxAccount, loginFailMaxIP)

	jwxtService := academic.NewService(func() (academic.JWXTClient, error) {
		// 每次教务登录都创建独立 Client，确保不同学生不会共享 CookieJar。
		return jwxt.NewClient()
	}, repository, credentials, 3*time.Minute)
	labmsMode := strings.ToLower(strings.TrimSpace(os.Getenv("LABMS_SCHEDULE_MODE")))
	labmsRolloutPercent, err := boundedEnvironmentInt("LABMS_SCHEDULE_ROLLOUT_PERCENT", 0, 0, 100)
	if err != nil {
		log.Fatal(err)
	}
	scheduleSource, err := schedule.NewSwitchingCourseTableService(jwxtService, schedule.SwitchingSourceConfig{
		Mode:           schedule.SourceMode(labmsMode),
		RolloutPercent: labmsRolloutPercent,
	})
	if err != nil {
		log.Fatal(err)
	}
	if labmsMode == "" {
		labmsMode = string(schedule.SourceModeOff)
	}
	log.Printf("LABMS 课表源: mode=%s rollout=%d%%", labmsMode, labmsRolloutPercent)
	cacheLoader := platformcache.NewLoader(cacheStore)
	academicService := academic.NewCachedService(jwxtService, cacheLoader)
	scheduleService := schedule.NewCachedCourseTableService(scheduleSource, cacheLoader)
	currentWeekService := schedule.NewCachedCurrentWeekService(schedule.NewCalendarClient(), cacheLoader)
	academicHandler := academic.NewHandler(academicService, secureCookie, loginLimiter)
	scheduleHandler := schedule.NewHandler(scheduleService, currentWeekService)
	feedbackRepository := feedback.NewRepository(db)
	feedbackHandler := feedback.NewHandler(academicService, feedbackRepository)

	h := server.Default(server.WithHostPorts(address))
	h.Use(accesslog.New())
	analyticsRepository := analytics.NewRepository(db)
	analyticsCollector := analytics.NewCollector(
		analyticsRepository,
		academicService,
		"campus_session",
		time.Minute,
	)
	analyticsCollector.Start()
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := analyticsCollector.Stop(ctx); err != nil {
			log.Printf("停止统计收集器失败: %v", err)
		}
	}()
	h.Use(analyticsCollector.Middleware())
	if allowedOrigin != "" {
		h.Use(cors.New(allowedOrigin))
	}
	academicHandler.Register(h, loginGate.Middleware())
	scheduleHandler.Register(h)
	feedbackHandler.Register(h)
	autorunWorkerURL := strings.TrimSpace(os.Getenv("AUTORUN_WORKER_URL"))
	autorunInternalSecret := strings.TrimSpace(os.Getenv("AUTORUN_INTERNAL_SECRET"))
	autorunSecret := strings.TrimSpace(os.Getenv("AUTORUN_APP_SECRET"))
	if autorunWorkerURL != "" || autorunInternalSecret != "" {
		autorunEncryptionKey := os.Getenv("AUTORUN_SESSION_ENCRYPTION_KEY")
		if autorunWorkerURL == "" || len(autorunInternalSecret) < 32 || len(strings.TrimSpace(autorunEncryptionKey)) < 16 {
			log.Fatal("autorun: AUTORUN_WORKER_URL, AUTORUN_INTERNAL_SECRET (32+ chars) and AUTORUN_SESSION_ENCRYPTION_KEY are required together")
		}
		autorunRepository := autorunstore.NewRepository(db, autorunEncryptionKey)
		autorunRelay, err := autorunrelay.NewClient(autorunWorkerURL, autorunInternalSecret)
		if err != nil {
			log.Fatal(err)
		}
		autorunrelay.NewHandler(autorunRepository, autorunInternalSecret).Register(h)
		log.Print("AutoRun 定时状态内部接口已启用")
		defer startAutoRunScheduler(autorunRepository, autorunRelay)()
	} else if autorunSecret != "" {
		autorunAppKey := strings.TrimSpace(os.Getenv("AUTORUN_APP_KEY"))
		autorunEncryptionKey := os.Getenv("AUTORUN_SESSION_ENCRYPTION_KEY")
		if autorunAppKey == "" || len(strings.TrimSpace(autorunEncryptionKey)) < 16 {
			log.Fatal("autorun: AUTORUN_APP_KEY and AUTORUN_SESSION_ENCRYPTION_KEY are required when AUTORUN_APP_SECRET is configured")
		}
		autorunRepository := autorunstore.NewRepository(db, autorunEncryptionKey)
		autorunClient := autorunupstream.NewClient(autorunupstream.Options{
			AppKey: autorunAppKey, AppSecret: autorunSecret,
		})
		autorun.NewHandler(autorun.NewService(autorunRepository, autorunClient)).Register(h, loginGate.Middleware())
		log.Print("AutoRun 旧版直连接口已启用（回滚模式）")
		defer startAutoRunScheduler(autorunRepository, autorunClient)()
	} else {
		log.Print("AutoRun 定时服务未启用：未配置 Worker relay")
	}
	if adminToken := strings.TrimSpace(os.Getenv("ADMIN_STATS_TOKEN")); adminToken != "" {
		analytics.NewHandler(
			analyticsCollector,
			adminToken,
			cacheLoader,
			feedbackRepository,
		).Register(h)
	} else {
		log.Print("统计接口未启用：未配置 ADMIN_STATS_TOKEN")
	}
	h.GET("/api/v1/health", func(_ context.Context, c *app.RequestContext) {
		c.JSON(http.StatusOK, map[string]any{"code": 0, "message": "success", "data": map[string]string{"status": "ok"}})
	})
	h.Spin()
}

type autoRunSchedulerClient interface {
	GetSignInTf(context.Context, string, int64) (*autorunupstream.SignInTf, error)
	SignInOrSignBack(context.Context, string, autorunupstream.SignRequestBody) (string, error)
	GetClubActivityList(context.Context, string, int64, string, int64) ([]autorunupstream.ClubInfo, error)
}

func startAutoRunScheduler(repository *autorunstore.Repository, client autoRunSchedulerClient) func() {
	if !strings.EqualFold(strings.TrimSpace(os.Getenv("AUTORUN_SCHEDULER_ENABLED")), "true") {
		log.Print("AutoRun 本地定时器未启用")
		return func() {}
	}
	workers, err := positiveEnvironmentInt("AUTORUN_SCHEDULER_WORKERS", 10)
	if err != nil {
		log.Fatal(err)
	}
	rate, err := positiveEnvironmentInt("AUTORUN_SCHEDULER_JOBS_PER_SECOND", 5)
	if err != nil {
		log.Fatal(err)
	}
	autorunScheduler := autorun.NewScheduler(repository, client, autorun.SchedulerConfig{
		Workers: workers, JobsPerSecond: rate,
	})
	autorunScheduler.Start()
	log.Printf("AutoRun 本地定时器已启用: workers=%d jobs_per_second=%d transport=worker", workers, rate)
	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := autorunScheduler.Stop(ctx); err != nil {
			log.Printf("停止 AutoRun 定时器失败: %v", err)
		}
	}
}

func positiveEnvironmentInt(name string, fallback int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < 1 {
		return 0, errors.New(name + " must be a positive integer")
	}
	return value, nil
}

func boundedEnvironmentInt(name string, fallback int, minimum int, maximum int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < minimum || value > maximum {
		return 0, errors.New(name + " must be between " + strconv.Itoa(minimum) + " and " + strconv.Itoa(maximum))
	}
	return value, nil
}

func loadEnvironment() {
	if err := godotenv.Load(); err != nil && !errors.Is(err, os.ErrNotExist) {
		log.Fatal("load .env: ", err)
	}
}
