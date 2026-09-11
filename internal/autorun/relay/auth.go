// Package relay connects the local AutoRun scheduler to the Cloudflare Worker
// and exposes a small authenticated state API back to that Worker.
package relay

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"time"
)

const (
	timestampHeader  = "X-Autorun-Timestamp"
	signatureHeader  = "X-Autorun-Signature"
	defaultClockSkew = 5 * time.Minute
)

var errUnauthorized = errors.New("autorun relay: unauthorized")

func signRequest(secret, method, pathname string, body []byte, now time.Time) (string, string) {
	timestamp := strconv.FormatInt(now.Unix(), 10)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(canonicalRequest(timestamp, method, pathname, body)))
	return timestamp, hex.EncodeToString(mac.Sum(nil))
}

func verifyRequest(secret, method, pathname string, body []byte, timestamp, signature string, now time.Time) error {
	if len(strings.TrimSpace(secret)) < 32 {
		return errUnauthorized
	}
	timestamp = strings.TrimSpace(timestamp)
	signature = strings.ToLower(strings.TrimSpace(signature))
	seconds, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil || len(timestamp) < 10 || len(timestamp) > 13 {
		return errUnauthorized
	}
	requestTime := time.Unix(seconds, 0)
	if requestTime.Before(now.Add(-defaultClockSkew)) || requestTime.After(now.Add(defaultClockSkew)) {
		return errUnauthorized
	}
	provided, err := hex.DecodeString(signature)
	if err != nil || len(provided) != sha256.Size {
		return errUnauthorized
	}
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(canonicalRequest(timestamp, method, pathname, body)))
	if !hmac.Equal(mac.Sum(nil), provided) {
		return errUnauthorized
	}
	return nil
}

func canonicalRequest(timestamp, method, pathname string, body []byte) string {
	digest := sha256.Sum256(body)
	return timestamp + "\n" + strings.ToUpper(strings.TrimSpace(method)) + "\n" + pathname + "\n" + hex.EncodeToString(digest[:])
}
