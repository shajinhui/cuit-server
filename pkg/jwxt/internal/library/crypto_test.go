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
	publicDER, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	publicPEM := string(pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: publicDER}))

	encryptedKey, encryptedSeat, err := encryptSeatID(publicPEM, "12345")
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
