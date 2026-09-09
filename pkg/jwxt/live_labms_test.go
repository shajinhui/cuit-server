//go:build jwxt_live

package jwxt

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestLiveLABMSCourseTable(t *testing.T) {
	if os.Getenv("CUIT_JWXT_LIVE_TEST") != "1" {
		t.Skip("set CUIT_JWXT_LIVE_TEST=1 to run live LABMS course table test")
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
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	if err := client.Login(ctx, username, password); err != nil {
		t.Fatalf("EAMS login failed: %s", err)
	}
	if err := client.LoginLABMS(ctx, username, password); err != nil {
		t.Fatalf("LABMS login failed: %s", err)
	}
	table, err := client.GetLABMSCourseTable(ctx, semesterID)
	if err != nil {
		t.Fatalf("GetLABMSCourseTable failed: %s", err)
	}
	if table.SemesterID != semesterID || len(table.Courses) == 0 {
		t.Fatalf("LABMS returned no usable courses: semester=%q courses=%d", table.SemesterID, len(table.Courses))
	}
}
