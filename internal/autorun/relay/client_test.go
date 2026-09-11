package relay

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"cuit-server/internal/autorun/upstream"
)

func TestClientSignsProbeAndForwardsResponse(t *testing.T) {
	secret := "test-internal-secret-with-more-than-32-characters"
	now := time.Date(2026, time.September, 11, 12, 0, 0, 0, time.UTC)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		body, err := io.ReadAll(request.Body)
		if err != nil {
			t.Errorf("read body: %v", err)
		}
		if err := verifyRequest(secret, request.Method, request.URL.Path, body, request.Header.Get(timestampHeader), request.Header.Get(signatureHeader), now); err != nil {
			t.Errorf("verify request: %v", err)
		}
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{
			"code": 10000, "msg": "ok",
			"response": map[string]any{"signTask": map[string]any{
				"activityId": 456, "latitude": "30.1", "longitude": "104.1",
				"signBackStatus": "0", "signInStatus": "0", "signStatus": "1",
			}},
		})
	}))
	defer server.Close()

	client, err := NewClient(server.URL, secret)
	if err != nil {
		t.Fatal(err)
	}
	client.now = func() time.Time { return now }
	task, err := client.GetSignInTf(context.Background(), "test-token", 22)
	if err != nil {
		t.Fatal(err)
	}
	if task == nil || task.ActivityID != 456 {
		t.Fatalf("task = %+v", task)
	}
}

func TestClientRequiresActionKeyForMutation(t *testing.T) {
	client, err := NewClient("https://worker.example", "test-internal-secret-with-more-than-32-characters")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.SignInOrSignBack(context.Background(), "token", upstream.SignRequestBody{}); err == nil {
		t.Fatal("SignInOrSignBack() error = nil")
	}
}
