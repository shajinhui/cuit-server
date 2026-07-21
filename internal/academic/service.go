package academic

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"strings"
	"sync"
	"time"

	"cuit-server/pkg/jwxt"
)

var (
	ErrInvalidInput    = errors.New("academic: invalid input")
	ErrUnauthenticated = errors.New("academic: unauthenticated")
)

type GradeClient interface {
	Login(ctx context.Context, username string, password string) error
	ListSemesters(ctx context.Context) ([]jwxt.Semester, error)
	GetGrades(ctx context.Context, semesterID string) ([]jwxt.Grade, error)
}

type ClientFactory func() (GradeClient, error)

type session struct {
	client    GradeClient
	expiresAt time.Time
}

type Service struct {
	mu            sync.Mutex
	sessions      map[string]session
	clientFactory ClientFactory
	repository    UserRepository
	credentials   *CredentialCipher
	now           func() time.Time
	sessionTTL    time.Duration
}

func NewService(clientFactory ClientFactory, repository UserRepository, credentials *CredentialCipher, sessionTTL time.Duration) *Service {
	return &Service{
		sessions:      make(map[string]session),
		clientFactory: clientFactory,
		repository:    repository,
		credentials:   credentials,
		now:           time.Now,
		sessionTTL:    sessionTTL,
	}
}

func (s *Service) Login(ctx context.Context, username string, password string) (string, error) {
	studentNo := strings.TrimSpace(username)
	if studentNo == "" || password == "" {
		return "", ErrInvalidInput
	}
	client, err := s.clientFactory()
	if err != nil {
		return "", err
	}
	if err := client.Login(ctx, studentNo, password); err != nil {
		return "", err
	}
	encrypted, err := s.credentials.Encrypt(password)
	if err != nil {
		return "", err
	}
	userID, err := s.repository.UpsertLogin(ctx, studentNo, encrypted, s.now())
	if err != nil {
		return "", err
	}
	return s.createSession(ctx, userID, client)
}

func (s *Service) ListSemesters(ctx context.Context, sessionID string) ([]jwxt.Semester, error) {
	client, err := s.clientFor(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	semesters, err := client.ListSemesters(ctx)
	if !errors.Is(err, jwxt.ErrSessionExpired) {
		return semesters, err
	}
	client, err = s.relogin(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	return client.ListSemesters(ctx)
}

func (s *Service) GetGrades(ctx context.Context, sessionID string, semesterID string) ([]jwxt.Grade, error) {
	if strings.TrimSpace(semesterID) == "" {
		return nil, ErrInvalidInput
	}
	client, err := s.clientFor(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	grades, err := client.GetGrades(ctx, strings.TrimSpace(semesterID))
	if !errors.Is(err, jwxt.ErrSessionExpired) {
		return grades, err
	}
	client, err = s.relogin(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	return client.GetGrades(ctx, strings.TrimSpace(semesterID))
}

func (s *Service) Authenticated(ctx context.Context, sessionID string) (bool, error) {
	if strings.TrimSpace(sessionID) == "" {
		return false, nil
	}
	_, err := s.repository.FindUserBySession(ctx, sessionTokenHash(sessionID), s.now())
	if errors.Is(err, ErrStoredSessionNotFound) {
		return false, nil
	}
	return err == nil, err
}

func (s *Service) Logout(ctx context.Context, sessionID string) error {
	if strings.TrimSpace(sessionID) == "" {
		return nil
	}
	s.mu.Lock()
	delete(s.sessions, sessionID)
	s.mu.Unlock()
	return s.repository.DeleteSession(ctx, sessionTokenHash(sessionID))
}

func (s *Service) createSession(ctx context.Context, userID int64, client GradeClient) (string, error) {
	sessionID, err := newSessionID()
	if err != nil {
		return "", err
	}
	expiresAt := s.now().Add(s.sessionTTL)
	if err := s.repository.CreateSession(ctx, userID, sessionTokenHash(sessionID), expiresAt); err != nil {
		return "", err
	}
	s.cacheClient(sessionID, client, expiresAt)
	return sessionID, nil
}

func (s *Service) clientFor(ctx context.Context, sessionID string) (GradeClient, error) {
	if strings.TrimSpace(sessionID) == "" {
		return nil, ErrUnauthenticated
	}
	if client := s.cachedClient(sessionID); client != nil {
		return client, nil
	}
	return s.relogin(ctx, sessionID)
}

func (s *Service) relogin(ctx context.Context, sessionID string) (GradeClient, error) {
	user, err := s.repository.FindUserBySession(ctx, sessionTokenHash(sessionID), s.now())
	if errors.Is(err, ErrStoredSessionNotFound) {
		return nil, ErrUnauthenticated
	}
	if err != nil {
		return nil, err
	}
	password, err := s.credentials.Decrypt(user.EncryptedPassword)
	if err != nil {
		return nil, err
	}
	client, err := s.clientFactory()
	if err != nil {
		return nil, err
	}
	if err := client.Login(ctx, user.StudentNo, password); err != nil {
		if errors.Is(err, jwxt.ErrInvalidCredentials) {
			if deleteErr := s.Logout(ctx, sessionID); deleteErr != nil {
				return nil, errors.Join(err, deleteErr)
			}
		}
		return nil, err
	}
	s.cacheClient(sessionID, client, user.SessionExpiresAt)
	return client, nil
}

func (s *Service) cachedClient(sessionID string) GradeClient {
	s.mu.Lock()
	defer s.mu.Unlock()
	stored, ok := s.sessions[sessionID]
	if !ok {
		return nil
	}
	if !s.now().Before(stored.expiresAt) {
		delete(s.sessions, sessionID)
		return nil
	}
	return stored.client
}

func (s *Service) cacheClient(sessionID string, client GradeClient, expiresAt time.Time) {
	s.mu.Lock()
	s.sessions[sessionID] = session{client: client, expiresAt: expiresAt}
	s.mu.Unlock()
}

func sessionTokenHash(sessionID string) [sha256.Size]byte {
	return sha256.Sum256([]byte(sessionID))
}

func newSessionID() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}
