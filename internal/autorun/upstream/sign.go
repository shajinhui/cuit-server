package upstream

import (
	"crypto/md5"
	"encoding/hex"
	"net/url"
	"sort"
	"strings"
)

// MD5Hex returns the lower-case hexadecimal MD5 digest used by the mobile
// protocol for passwords and request signatures.
func MD5Hex(value string) string {
	sum := md5.Sum([]byte(value))
	return hex.EncodeToString(sum[:])
}

// MD5Password hashes a password for the password-login request.  This is
// protocol encoding only; callers must not use it as password storage.
func MD5Password(password string) string { return MD5Hex(password) }

// GenerateSign mirrors the tanmasports signing algorithm used by AutoRun-ts.
// Query keys are sorted lexicographically, empty values are omitted, then the
// app key, app secret, and raw JSON body are concatenated.  If one of the
// protocol-special characters is present, it is removed before Go query
// escaping and the encodeutf8 suffix is appended.
//
// appKey and appSecret are explicit arguments so credentials never need to be
// embedded in source code or test fixtures.
func GenerateSign(query map[string]string, body, appKey, appSecret string) string {
	keys := make([]string, 0, len(query))
	for key := range query {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	var builder strings.Builder
	for _, key := range keys {
		value := query[key]
		if value == "" {
			continue
		}
		builder.WriteString(key)
		builder.WriteString(value)
	}
	builder.WriteString(appKey)
	builder.WriteString(appSecret)
	builder.WriteString(body)

	raw := builder.String()
	sanitized := strings.NewReplacer(
		" ", "",
		"~", "",
		"!", "",
		"(", "",
		")", "",
		"'", "",
	).Replace(raw)
	if sanitized != raw {
		// url.QueryEscape is the Go equivalent of the URLSearchParams branch
		// used by the TypeScript implementation.  Keep '*' unescaped because
		// the upstream protocol explicitly treats it as an allowed character.
		encoded := strings.ReplaceAll(url.QueryEscape(sanitized), "%2A", "*")
		return strings.ToUpper(MD5Hex(encoded)) + "encodeutf8"
	}
	return strings.ToUpper(MD5Hex(raw))
}
