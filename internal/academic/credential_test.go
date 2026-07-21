package academic

import (
	"encoding/base64"
	"testing"
)

func TestCredentialCipherRoundTrip(t *testing.T) {
	key := base64.StdEncoding.EncodeToString(make([]byte, 32))
	cipher, err := NewCredentialCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	encrypted, err := cipher.Encrypt("test-password")
	if err != nil {
		t.Fatal(err)
	}
	if string(encrypted) == "test-password" {
		t.Fatal("credential must not be stored as plaintext")
	}
	plain, err := cipher.Decrypt(encrypted)
	if err != nil || plain != "test-password" {
		t.Fatalf("unexpected decrypted credential")
	}
}

func TestCredentialCipherRejectsInvalidKey(t *testing.T) {
	if _, err := NewCredentialCipher("invalid"); err != ErrInvalidCredentialKey {
		t.Fatalf("expected invalid key error, got %v", err)
	}
}
