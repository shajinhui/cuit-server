package academic

import "time"

type StoredUser struct {
	ID                int64
	StudentNo         string
	EncryptedPassword []byte
	SessionExpiresAt  time.Time
}
