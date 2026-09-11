package relay

import (
	"net/http"
	"testing"
	"time"
)

func TestRequestSignatureRejectsTamperingAndStaleTimestamp(t *testing.T) {
	secret := "test-internal-secret-with-more-than-32-characters"
	now := time.Date(2026, time.September, 11, 12, 0, 0, 0, time.UTC)
	body := []byte(`{"action":"probe","studentId":22}`)
	timestamp, signature := signRequest(secret, http.MethodPost, executePath, body, now)
	if err := verifyRequest(secret, http.MethodPost, executePath, body, timestamp, signature, now); err != nil {
		t.Fatalf("verifyRequest() error = %v", err)
	}
	if err := verifyRequest(secret, http.MethodPost, executePath, append(body, ' '), timestamp, signature, now); err == nil {
		t.Fatal("verifyRequest() accepted a changed body")
	}
	if err := verifyRequest(secret, http.MethodPost, executePath, body, timestamp, signature, now.Add(301*time.Second)); err == nil {
		t.Fatal("verifyRequest() accepted a stale timestamp")
	}
}
