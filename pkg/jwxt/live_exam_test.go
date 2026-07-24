//go:build jwxt_live

package jwxt

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestLiveExamQuery(t *testing.T) {
	if os.Getenv("CUIT_JWXT_LIVE_TEST") != "1" {
		t.Skip("set CUIT_JWXT_LIVE_TEST=1 to run live JWXT exam test")
	}
	username := os.Getenv("CUIT_JWXT_USERNAME")
	password := os.Getenv("CUIT_JWXT_PASSWORD")
	semesterID := os.Getenv("CUIT_JWXT_SEMESTER_ID")
	if username == "" || password == "" || semesterID == "" {
		t.Skip("CUIT_JWXT_USERNAME, CUIT_JWXT_PASSWORD and CUIT_JWXT_SEMESTER_ID are required")
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

	batches, err := client.ListExamBatches(ctx, semesterID)
	if err != nil {
		t.Fatalf("ListExamBatches failed: %s", err)
	}
	if len(batches) == 0 {
		return
	}
	if _, err := client.GetExams(ctx, batches[0].ID); err != nil {
		t.Fatalf("GetExams failed: %s", err)
	}
}
