package academic

type LoginUser struct {
	StudentNo      string
	Name           string
	College        string
	Major          string
	EnrollmentYear int
}

type StoredUser struct {
	ID                int64
	StudentNo         string
	Name              string
	College           string
	Major             string
	EnrollmentYear    int
	EncryptedPassword []byte
}
