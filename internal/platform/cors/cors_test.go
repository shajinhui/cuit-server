package cors

import (
	"context"
	"net/http"
	"testing"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

const testFrontendOrigin = "https://fanxiaogao05.dpdns.org"

func TestAllowedOriginCanSendCredentials(t *testing.T) {
	h := server.Default()
	h.Use(New(testFrontendOrigin))
	h.GET("/api/test", okHandler)

	response := ut.PerformRequest(
		h.Engine,
		http.MethodGet,
		"/api/test",
		nil,
		ut.Header{Key: "Origin", Value: testFrontendOrigin},
	).Result()

	if response.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	if got := string(response.Header.Peek("Access-Control-Allow-Origin")); got != testFrontendOrigin {
		t.Fatalf("unexpected allow origin: %q", got)
	}
	if got := string(response.Header.Peek("Access-Control-Allow-Credentials")); got != "true" {
		t.Fatalf("unexpected allow credentials: %q", got)
	}
}

func TestPreflightStopsBeforeAPIHandler(t *testing.T) {
	h := server.Default()
	called := false
	h.Use(New(testFrontendOrigin))
	h.POST("/api/test", func(context.Context, *app.RequestContext) {
		called = true
	})

	response := ut.PerformRequest(
		h.Engine,
		http.MethodOptions,
		"/api/test",
		nil,
		ut.Header{Key: "Origin", Value: testFrontendOrigin},
		ut.Header{Key: "Access-Control-Request-Method", Value: http.MethodPost},
		ut.Header{Key: "Access-Control-Request-Headers", Value: "content-type"},
	).Result()

	if response.StatusCode() != http.StatusNoContent {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
	if called {
		t.Fatal("preflight reached API handler")
	}
}

func TestUnexpectedOriginIsRejected(t *testing.T) {
	h := server.Default()
	h.Use(New(testFrontendOrigin))
	h.GET("/api/test", okHandler)

	response := ut.PerformRequest(
		h.Engine,
		http.MethodGet,
		"/api/test",
		nil,
		ut.Header{Key: "Origin", Value: "https://example.com"},
	).Result()

	if response.StatusCode() != http.StatusForbidden {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
}

func TestRequestWithoutOriginStillWorks(t *testing.T) {
	h := server.Default()
	h.Use(New(testFrontendOrigin))
	h.GET("/api/test", okHandler)

	response := ut.PerformRequest(h.Engine, http.MethodGet, "/api/test", nil).Result()
	if response.StatusCode() != http.StatusOK {
		t.Fatalf("unexpected status: %d", response.StatusCode())
	}
}

func okHandler(_ context.Context, c *app.RequestContext) {
	c.Status(http.StatusOK)
}
