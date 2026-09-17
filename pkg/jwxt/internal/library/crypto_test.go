package library

import (
	"crypto/aes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"testing"
)

func TestEncryptSeatIDUsesUpstreamFormats(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 1024)
	if err != nil {
		t.Fatal(err)
	}
	pkixDER, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	pkcs1DER := x509.MarshalPKCS1PublicKey(&privateKey.PublicKey)
	cases := []struct {
		name string
		key  string
	}{
		{"pem pkix", string(pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: pkixDER}))},
		{"bare base64 pkix", base64.StdEncoding.EncodeToString(pkixDER)},
		{"pem pkcs1", string(pem.EncodeToMemory(&pem.Block{Type: "RSA PUBLIC KEY", Bytes: pkcs1DER}))},
		{"bare base64 pkcs1", base64.StdEncoding.EncodeToString(pkcs1DER)},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			assertSeatEncryptionRoundTrip(t, privateKey, testCase.key)
		})
	}
}

// The upstream login/publicKey endpoint returns a headerless base64
// SubjectPublicKeyInfo payload, which used to break every seat reservation.
func TestEncryptSeatIDRejectsUnusablePublicKey(t *testing.T) {
	for _, broken := range []string{"", "   ", "not-a-key", "-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----"} {
		if _, _, err := encryptSeatID(broken, "12345"); err == nil {
			t.Fatalf("encryptSeatID(%q) succeeded, want error", broken)
		}
	}
}

func assertSeatEncryptionRoundTrip(t *testing.T, privateKey *rsa.PrivateKey, encodedPublicKey string) {
	t.Helper()
	encryptedKey, encryptedSeat, err := encryptSeatID(encodedPublicKey, "12345")
	if err != nil {
		t.Fatal(err)
	}
	keyCiphertext, err := base64.StdEncoding.DecodeString(encryptedKey)
	if err != nil {
		t.Fatal(err)
	}
	key, err := rsa.DecryptPKCS1v15(rand.Reader, privateKey, keyCiphertext)
	if err != nil {
		t.Fatal(err)
	}
	if len(key) != 16 {
		t.Fatalf("key length = %d, want 16", len(key))
	}
	seatCiphertext, err := hex.DecodeString(encryptedSeat)
	if err != nil {
		t.Fatal(err)
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	plain := make([]byte, len(seatCiphertext))
	previous := []byte(encryptionIV)
	for offset := 0; offset < len(seatCiphertext); offset += block.BlockSize() {
		block.Decrypt(plain[offset:offset+block.BlockSize()], seatCiphertext[offset:offset+block.BlockSize()])
		for index := range previous {
			plain[offset+index] ^= previous[index]
		}
		previous = seatCiphertext[offset : offset+block.BlockSize()]
	}
	if got := string(plain[:5]); got != "12345" {
		t.Fatalf("decrypted seat = %q", got)
	}
}
