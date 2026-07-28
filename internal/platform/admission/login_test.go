package admission

import (
	"context"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/ut"
)

func TestLoginGateRejectsExcessRequestsAndReleasesSlot(t *testing.T) {
	gate, err := NewLoginGate(1, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	h := server.Default()
	entered := make(chan struct{})
	release := make(chan struct{})
	firstStatus := make(chan int, 1)
	var calls atomic.Int32

	h.POST("/login", gate.Middleware(), func(_ context.Context, c *app.RequestContext) {
		if calls.Add(1) == 1 {
			close(entered)
			<-release
		}
		c.String(200, "ok")
	})

	go func() {
		response := ut.PerformRequest(h.Engine, "POST", "/login", nil).Result()
		firstStatus <- response.StatusCode()
	}()
	<-entered

	busyResponse := ut.PerformRequest(h.Engine, "POST", "/login", nil).Result()
	if busyResponse.StatusCode() != 503 {
		t.Fatalf("unexpected busy status: %d", busyResponse.StatusCode())
	}
	if string(busyResponse.Header.Peek("Retry-After")) != "5" {
		t.Fatalf("unexpected Retry-After: %q", busyResponse.Header.Peek("Retry-After"))
	}
	if !strings.Contains(string(busyResponse.Body()), `"code":50301`) {
		t.Fatalf("unexpected busy response: %s", busyResponse.Body())
	}

	close(release)
	if status := <-firstStatus; status != 200 {
		t.Fatalf("unexpected first request status: %d", status)
	}
	nextResponse := ut.PerformRequest(h.Engine, "POST", "/login", nil).Result()
	if nextResponse.StatusCode() != 200 {
		t.Fatalf("released slot was not reusable: %d", nextResponse.StatusCode())
	}
}

func TestLoginGateRejectsInvalidConfiguration(t *testing.T) {
	if _, err := NewLoginGate(0, 5*time.Second); err == nil {
		t.Fatal("zero concurrency must be rejected")
	}
	if _, err := NewLoginGate(1, 0); err == nil {
		t.Fatal("zero retry delay must be rejected")
	}
}
