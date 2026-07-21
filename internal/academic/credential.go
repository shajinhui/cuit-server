package academic

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
)

var ErrInvalidCredentialKey = errors.New("academic: invalid credential key")

type CredentialCipher struct {
	aead cipher.AEAD
}

func NewCredentialCipher(encodedKey string) (*CredentialCipher, error) {
	key, err := base64.StdEncoding.DecodeString(encodedKey)
	if err != nil || len(key) != 32 {
		return nil, ErrInvalidCredentialKey
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("academic: create credential cipher: %w", err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("academic: create credential GCM: %w", err)
	}
	return &CredentialCipher{aead: aead}, nil
}

func (c *CredentialCipher) Encrypt(password string) ([]byte, error) {
	nonce := make([]byte, c.aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("academic: create credential nonce: %w", err)
	}
	return c.aead.Seal(nonce, nonce, []byte(password), nil), nil
}

func (c *CredentialCipher) Decrypt(encrypted []byte) (string, error) {
	nonceSize := c.aead.NonceSize()
	if len(encrypted) < nonceSize {
		return "", errors.New("academic: invalid encrypted credential")
	}
	plain, err := c.aead.Open(nil, encrypted[:nonceSize], encrypted[nonceSize:], nil)
	if err != nil {
		return "", fmt.Errorf("academic: decrypt credential: %w", err)
	}
	return string(plain), nil
}
