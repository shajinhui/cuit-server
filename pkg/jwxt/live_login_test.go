//go:build jwxt_live

package jwxt

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestLiveLogin(t *testing.T) {
	if os.Getenv("CUIT_JWXT_LIVE_TEST") != "1" {
		t.Skip("set CUIT_JWXT_LIVE_TEST=1 to run live JWXT login test")
	}
	username := os.Getenv("CUIT_JWXT_USERNAME")
	password := os.Getenv("CUIT_JWXT_PASSWORD")
	if username == "" || password == "" {
		t.Skip("CUIT_JWXT_USERNAME and CUIT_JWXT_PASSWORD are required")
	}

	client, err := NewClient()
	if err != nil {
		t.Fatalf("NewClient failed: %s", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	if err := client.Login(ctx, username, password); err != nil {
		t.Fatalf("Login failed: %s", err)
	}
}
