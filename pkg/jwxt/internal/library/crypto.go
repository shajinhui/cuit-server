package library

import (
	"crypto/aes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"strings"
)

const encryptionIV = "ABCDEF1234123412"

func encryptSeatID(encodedPublicKey string, seatID string) (string, string, error) {
	key, err := randomASCIIKey(16)
	if err != nil {
		return "", "", err
	}
	encryptedKey, err := rsaEncrypt(encodedPublicKey, []byte(key))
	if err != nil {
		return "", "", err
	}
	encryptedSeat, err := aesCBCZeroPadding([]byte(key), []byte(encryptionIV), []byte(seatID))
	if err != nil {
		return "", "", err
	}
	return base64.StdEncoding.EncodeToString(encryptedKey), strings.ToUpper(hex.EncodeToString(encryptedSeat)), nil
}

func randomASCIIKey(length int) (string, error) {
	const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	if length <= 0 {
		return "", fmt.Errorf("library: invalid random key length")
	}
	random := make([]byte, length)
	if _, err := rand.Read(random); err != nil {
		return "", err
	}
	result := make([]byte, length)
	for index, value := range random {
		result[index] = alphabet[int(value)%len(alphabet)]
	}
	return string(result), nil
}

// parseRSAPublicKey accepts the upstream key in either PEM or bare base64 DER
// form, because the school service hands out a headerless SubjectPublicKeyInfo
// payload that its own JSEncrypt frontend consumes verbatim.
func parseRSAPublicKey(encoded string) (*rsa.PublicKey, error) {
	encoded = strings.TrimSpace(encoded)
	if encoded == "" {
		return nil, fmt.Errorf("library: invalid public key")
	}
	der := []byte(nil)
	if block, _ := pem.Decode([]byte(encoded)); block != nil {
		der = block.Bytes
	} else {
		compact := strings.Join(strings.Fields(encoded), "")
		decoded, err := base64.StdEncoding.DecodeString(compact)
		if err != nil {
			decoded, err = base64.RawStdEncoding.DecodeString(compact)
		}
		if err != nil {
			return nil, fmt.Errorf("library: invalid public key")
		}
		der = decoded
	}
	if parsed, err := x509.ParsePKIXPublicKey(der); err == nil {
		publicKey, ok := parsed.(*rsa.PublicKey)
		if !ok {
			return nil, fmt.Errorf("library: public key is not RSA")
		}
		return publicKey, nil
	}
	publicKey, err := x509.ParsePKCS1PublicKey(der)
	if err != nil {
		return nil, fmt.Errorf("library: parse public key: %w", err)
	}
	return publicKey, nil
}

func rsaEncrypt(encodedPublicKey string, value []byte) ([]byte, error) {
	publicKey, err := parseRSAPublicKey(encodedPublicKey)
	if err != nil {
		return nil, err
	}
	return rsa.EncryptPKCS1v15(rand.Reader, publicKey, value)
}

func aesCBCZeroPadding(key, iv, value []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	if len(iv) != block.BlockSize() {
		return nil, fmt.Errorf("library: invalid IV length")
	}
	length := len(value)
	paddedLength := length
	if remainder := length % block.BlockSize(); remainder != 0 {
		paddedLength += block.BlockSize() - remainder
	}
	if paddedLength == 0 {
		paddedLength = block.BlockSize()
	}
	padded := make([]byte, paddedLength)
	copy(padded, value)
	encrypted := make([]byte, paddedLength)
	for offset := 0; offset < paddedLength; offset += block.BlockSize() {
		for index := 0; index < block.BlockSize(); index++ {
			padded[offset+index] ^= iv[index]
		}
		block.Encrypt(encrypted[offset:offset+block.BlockSize()], padded[offset:offset+block.BlockSize()])
		iv = encrypted[offset : offset+block.BlockSize()]
	}
	return encrypted, nil
}
