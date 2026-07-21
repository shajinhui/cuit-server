//go:build jwxt_live

package jwxt

import (
	"context"
	"io"
	"os"
	"testing"
	"time"
)

func TestLiveInspectLoginFlow(t *testing.T) {
	if os.Getenv("CUIT_JWXT_LIVE_TEST") != "1" {
		t.Skip("set CUIT_JWXT_LIVE_TEST=1 to run live JWXT inspect test")
	}

	client, err := NewClient(WithOutput(io.Discard))
	if err != nil {
		t.Fatalf("NewClient failed: %s", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := client.InspectLoginFlow(ctx); err != nil {
		t.Fatalf("InspectLoginFlow failed: %s", err)
	}
}
