package academic

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"cuit-server/pkg/jwxt"
)

var (
	ErrInvalidInput    = errors.New("academic: invalid input")
	ErrUnauthenticated = errors.New("academic: unauthenticated")
)

const defaultClientIdleTTL = 3 * time.Minute

type JWXTClient interface {
	Login(ctx context.Context, username string, password string) error
	GetStudentProfile(ctx context.Context) (jwxt.StudentProfile, error)
	GetPlanCompletion(ctx context.Context) (jwxt.PlanCompletion, error)
	ListSemesters(ctx context.Context) ([]jwxt.Semester, error)
	GetGrades(ctx context.Context, semesterID string) ([]jwxt.Grade, error)
	GetExamsByType(ctx context.Context, semesterID string, examType string) ([]jwxt.Exam, error)
	GetCourseTable(ctx context.Context, semesterID string) (jwxt.CourseTable, error)
	GetClassroomOptions(ctx context.Context, semesterID string, campusID string) (jwxt.ClassroomOptions, error)
	GetAvailableClassrooms(ctx context.Context, query jwxt.AvailableClassroomQuery) ([]jwxt.Classroom, error)
	GetClassroomSchedule(ctx context.Context, semesterID string, campusID string) (jwxt.ClassroomSchedule, error)
}

type ClientFactory func() (JWXTClient, error)

// clientEntry 既是某个用户的短期 JWXT Client 缓存，也是该用户访问教务系统的串行锁。
// 应用 Session 不过期；只有内部 Client 在空闲三分钟后释放。
type clientEntry struct {
	mu         sync.Mutex
	user       StoredUser
	client     JWXTClient
	lastUsed   time.Time
	idleTimer  *time.Timer
	generation uint64
	revoked    bool
}

type Service struct {
	mu                sync.Mutex
	sessions          map[[sha256.Size]byte]*clientEntry
	activeTokenByUser map[int64][sha256.Size]byte
	clientFactory     ClientFactory
	repository        UserRepository
	credentials       *CredentialCipher
	now               func() time.Time
	clientIdleTTL     time.Duration
}

func NewService(
	clientFactory ClientFactory,
	repository UserRepository,
	credentials *CredentialCipher,
	clientIdleTTL time.Duration,
) *Service {
	if clientIdleTTL <= 0 {
		clientIdleTTL = defaultClientIdleTTL
	}
	return &Service{
		sessions:          make(map[[sha256.Size]byte]*clientEntry),
		activeTokenByUser: make(map[int64][sha256.Size]byte),
		clientFactory:     clientFactory,
		repository:        repository,
		credentials:       credentials,
		now:               time.Now,
		clientIdleTTL:     clientIdleTTL,
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
	profile, err := client.GetStudentProfile(ctx)
	if err != nil {
		return "", err
	}
	enrollmentYear, err := strconv.Atoi(profile.Grade)
	if err != nil {
		return "", fmt.Errorf("academic: invalid enrollment year: %w", err)
	}
	encrypted, err := s.credentials.Encrypt(password)
	if err != nil {
		return "", err
	}
	sessionID, err := newSessionID()
	if err != nil {
		return "", err
	}
	tokenHash := sessionTokenHash(sessionID)
	user := LoginUser{
		StudentNo:      studentNo,
		Name:           profile.Name,
		College:        profile.College,
		Major:          profile.Major,
		EnrollmentYear: enrollmentYear,
	}
	if err := s.saveLogin(ctx, user, encrypted, tokenHash, client); err != nil {
		return "", err
	}
	return sessionID, nil
}

func (s *Service) GetStudentProfile(ctx context.Context, sessionID string) (jwxt.StudentProfile, error) {
	return withClient(s, ctx, sessionID, func(client JWXTClient) (jwxt.StudentProfile, error) {
		return client.GetStudentProfile(ctx)
	})
}

func (s *Service) GetPlanCompletion(ctx context.Context, sessionID string) (jwxt.PlanCompletion, error) {
	return withClient(s, ctx, sessionID, func(client JWXTClient) (jwxt.PlanCompletion, error) {
		return client.GetPlanCompletion(ctx)
	})
}

func (s *Service) ListSemesters(ctx context.Context, sessionID string) ([]jwxt.Semester, error) {
	return withClient(s, ctx, sessionID, func(client JWXTClient) ([]jwxt.Semester, error) {
		return client.ListSemesters(ctx)
	})
}

func (s *Service) GetGrades(ctx context.Context, sessionID string, semesterID string) ([]jwxt.Grade, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return nil, ErrInvalidInput
	}
	return withClient(s, ctx, sessionID, func(client JWXTClient) ([]jwxt.Grade, error) {
		return client.GetGrades(ctx, semesterID)
	})
}

func (s *Service) GetExams(
	ctx context.Context,
	sessionID string,
	semesterID string,
	examType string,
) ([]jwxt.Exam, error) {
	semesterID = strings.TrimSpace(semesterID)
	examType = strings.TrimSpace(examType)
	if semesterID == "" || (examType != jwxt.ExamTypeFinal && examType != jwxt.ExamTypeMakeup) {
		return nil, ErrInvalidInput
	}
	return withClient(s, ctx, sessionID, func(client JWXTClient) ([]jwxt.Exam, error) {
		return client.GetExamsByType(ctx, semesterID, examType)
	})
}

func (s *Service) GetCourseTable(
	ctx context.Context,
	sessionID string,
	semesterID string,
) (jwxt.CourseTable, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return jwxt.CourseTable{}, ErrInvalidInput
	}
	return withClient(s, ctx, sessionID, func(client JWXTClient) (jwxt.CourseTable, error) {
		return client.GetCourseTable(ctx, semesterID)
	})
}

func (s *Service) GetClassroomOptions(
	ctx context.Context,
	sessionID string,
	semesterID string,
	campusID string,
) (jwxt.ClassroomOptions, error) {
	semesterID = strings.TrimSpace(semesterID)
	campusID = strings.TrimSpace(campusID)
	if semesterID == "" {
		return jwxt.ClassroomOptions{}, ErrInvalidInput
	}
	return withClient(s, ctx, sessionID, func(client JWXTClient) (jwxt.ClassroomOptions, error) {
		return client.GetClassroomOptions(ctx, semesterID, campusID)
	})
}

func (s *Service) GetAvailableClassrooms(
	ctx context.Context,
	sessionID string,
	query jwxt.AvailableClassroomQuery,
) ([]jwxt.Classroom, error) {
	query.SemesterID = strings.TrimSpace(query.SemesterID)
	query.CampusID = strings.TrimSpace(query.CampusID)
	if query.SemesterID == "" || query.CampusID == "" {
		return nil, ErrInvalidInput
	}
	return withClient(s, ctx, sessionID, func(client JWXTClient) ([]jwxt.Classroom, error) {
		return client.GetAvailableClassrooms(ctx, query)
	})
}

func (s *Service) GetClassroomSchedule(
	ctx context.Context,
	sessionID string,
	semesterID string,
	campusID string,
) (jwxt.ClassroomSchedule, error) {
	semesterID = strings.TrimSpace(semesterID)
	campusID = strings.TrimSpace(campusID)
	if semesterID == "" || campusID == "" {
		return jwxt.ClassroomSchedule{}, ErrInvalidInput
	}
	return withClient(s, ctx, sessionID, func(client JWXTClient) (jwxt.ClassroomSchedule, error) {
		return client.GetClassroomSchedule(ctx, semesterID, campusID)
	})
}

func (s *Service) Authenticated(ctx context.Context, sessionID string) (bool, error) {
	if strings.TrimSpace(sessionID) == "" {
		return false, nil
	}
	entry, _, err := s.sessionEntry(ctx, sessionID)
	if errors.Is(err, ErrUnauthenticated) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	entry.mu.Lock()
	authenticated := !entry.revoked
	entry.mu.Unlock()
	return authenticated, nil
}

func (s *Service) Logout(ctx context.Context, sessionID string) error {
	if strings.TrimSpace(sessionID) == "" {
		return nil
	}
	tokenHash := sessionTokenHash(sessionID)

	// 数据库清除与冷缓存加载共用同一把锁，避免退出时重新装入刚失效的 Session。
	s.mu.Lock()
	err := s.repository.ClearSession(ctx, tokenHash)
	entry := s.sessions[tokenHash]
	if err == nil {
		delete(s.sessions, tokenHash)
		if entry != nil && s.activeTokenByUser[entry.user.ID] == tokenHash {
			delete(s.activeTokenByUser, entry.user.ID)
		}
	}
	s.mu.Unlock()
	if err != nil {
		return err
	}
	revokeEntry(entry)
	return nil
}

func (s *Service) saveLogin(
	ctx context.Context,
	user LoginUser,
	encryptedPassword []byte,
	tokenHash [sha256.Size]byte,
	client JWXTClient,
) error {
	now := s.now()
	entry := &clientEntry{
		user: StoredUser{
			StudentNo:         user.StudentNo,
			Name:              user.Name,
			College:           user.College,
			Major:             user.Major,
			EnrollmentYear:    user.EnrollmentYear,
			EncryptedPassword: append([]byte(nil), encryptedPassword...),
		},
		client:   client,
		lastUsed: now,
	}

	// 同一学号的数据库 Token 和内存映射在一个临界区内一起覆盖。
	s.mu.Lock()
	userID, err := s.repository.UpsertLogin(ctx, user, encryptedPassword, tokenHash, now)
	if err != nil {
		s.mu.Unlock()
		return err
	}
	entry.user.ID = userID
	oldHash, hasOld := s.activeTokenByUser[userID]
	oldEntry := s.sessions[oldHash]
	if hasOld {
		delete(s.sessions, oldHash)
	}
	s.sessions[tokenHash] = entry
	s.activeTokenByUser[userID] = tokenHash
	s.mu.Unlock()

	entry.mu.Lock()
	s.scheduleClientReleaseLocked(entry)
	entry.mu.Unlock()
	if hasOld && oldEntry != entry {
		revokeEntry(oldEntry)
	}
	return nil
}

func (s *Service) sessionEntry(
	ctx context.Context,
	sessionID string,
) (*clientEntry, [sha256.Size]byte, error) {
	var emptyHash [sha256.Size]byte
	if strings.TrimSpace(sessionID) == "" {
		return nil, emptyHash, ErrUnauthenticated
	}
	tokenHash := sessionTokenHash(sessionID)

	// 只有内存未命中时才查询 SQLite；普通业务请求直接使用 Token 哈希映射。
	s.mu.Lock()
	if entry := s.sessions[tokenHash]; entry != nil {
		s.mu.Unlock()
		return entry, tokenHash, nil
	}
	user, err := s.repository.FindUserBySession(ctx, tokenHash)
	if errors.Is(err, ErrStoredSessionNotFound) {
		s.mu.Unlock()
		return nil, tokenHash, ErrUnauthenticated
	}
	if err != nil {
		s.mu.Unlock()
		return nil, tokenHash, err
	}
	entry := &clientEntry{user: user}
	s.sessions[tokenHash] = entry
	s.activeTokenByUser[user.ID] = tokenHash
	s.mu.Unlock()
	return entry, tokenHash, nil
}

func withClient[T any](
	s *Service,
	ctx context.Context,
	sessionID string,
	query func(JWXTClient) (T, error),
) (T, error) {
	var zero T
	entry, tokenHash, err := s.sessionEntry(ctx, sessionID)
	if err != nil {
		return zero, err
	}

	entry.mu.Lock()
	defer entry.mu.Unlock()
	if entry.revoked {
		return zero, ErrUnauthenticated
	}
	client, err := s.ensureClientLocked(ctx, tokenHash, entry)
	if err != nil {
		return zero, err
	}
	result, err := query(client)
	if errors.Is(err, jwxt.ErrSessionExpired) {
		s.dropClientLocked(entry)
		client, loginErr := s.loginClientLocked(ctx, tokenHash, entry)
		if loginErr != nil {
			return zero, loginErr
		}
		result, err = query(client)
	}
	if entry.client != nil && !entry.revoked {
		entry.lastUsed = s.now()
		s.scheduleClientReleaseLocked(entry)
	}
	return result, err
}

func (s *Service) ensureClientLocked(
	ctx context.Context,
	tokenHash [sha256.Size]byte,
	entry *clientEntry,
) (JWXTClient, error) {
	if entry.client != nil && (entry.lastUsed.IsZero() || s.now().Sub(entry.lastUsed) < s.clientIdleTTL) {
		return entry.client, nil
	}
	s.dropClientLocked(entry)
	return s.loginClientLocked(ctx, tokenHash, entry)
}

func (s *Service) loginClientLocked(
	ctx context.Context,
	tokenHash [sha256.Size]byte,
	entry *clientEntry,
) (JWXTClient, error) {
	password, err := s.credentials.Decrypt(entry.user.EncryptedPassword)
	if err != nil {
		return nil, err
	}
	client, err := s.clientFactory()
	if err != nil {
		return nil, err
	}
	if err := client.Login(ctx, entry.user.StudentNo, password); err != nil {
		if errors.Is(err, jwxt.ErrInvalidCredentials) {
			return nil, s.invalidateSessionLocked(ctx, tokenHash, entry, err)
		}
		return nil, err
	}
	entry.client = client
	entry.lastUsed = s.now()
	return client, nil
}

func (s *Service) invalidateSessionLocked(
	ctx context.Context,
	tokenHash [sha256.Size]byte,
	entry *clientEntry,
	cause error,
) error {
	entry.revoked = true
	s.dropClientLocked(entry)
	clearErr := s.repository.ClearSession(ctx, tokenHash)

	s.mu.Lock()
	if s.sessions[tokenHash] == entry {
		delete(s.sessions, tokenHash)
	}
	if s.activeTokenByUser[entry.user.ID] == tokenHash {
		delete(s.activeTokenByUser, entry.user.ID)
	}
	s.mu.Unlock()
	if clearErr != nil {
		return errors.Join(cause, clearErr)
	}
	return cause
}

func (s *Service) scheduleClientReleaseLocked(entry *clientEntry) {
	entry.generation++
	generation := entry.generation
	if entry.idleTimer != nil {
		entry.idleTimer.Stop()
	}
	entry.idleTimer = time.AfterFunc(s.clientIdleTTL, func() {
		entry.mu.Lock()
		defer entry.mu.Unlock()
		if entry.generation != generation || entry.revoked {
			return
		}
		entry.client = nil
		entry.idleTimer = nil
	})
}

func (s *Service) dropClientLocked(entry *clientEntry) {
	entry.generation++
	if entry.idleTimer != nil {
		entry.idleTimer.Stop()
		entry.idleTimer = nil
	}
	entry.client = nil
}

func revokeEntry(entry *clientEntry) {
	if entry == nil {
		return
	}
	entry.mu.Lock()
	entry.revoked = true
	entry.generation++
	if entry.idleTimer != nil {
		entry.idleTimer.Stop()
		entry.idleTimer = nil
	}
	entry.client = nil
	entry.mu.Unlock()
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
