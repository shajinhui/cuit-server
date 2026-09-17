package academic

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"cuit-server/pkg/jwxt"
)

var ErrLibraryAutoRenewalSkipped = errors.New("academic: library auto renewal skipped")

type libraryAutoRenewalSkipError struct {
	reason string
}

func (err *libraryAutoRenewalSkipError) Error() string {
	return ErrLibraryAutoRenewalSkipped.Error() + ": " + err.reason
}

func (err *libraryAutoRenewalSkipError) Unwrap() error {
	return ErrLibraryAutoRenewalSkipped
}

func LibraryAutoRenewalSkipReason(err error) string {
	var skipped *libraryAutoRenewalSkipError
	if errors.As(err, &skipped) {
		return skipped.reason
	}
	return ""
}

func (s *Service) GetLibraryRenewalOptions(
	ctx context.Context,
	sessionID string,
	reservationID string,
) (jwxt.LibraryRenewalOptions, error) {
	reservationID = strings.TrimSpace(reservationID)
	if reservationID == "" {
		return jwxt.LibraryRenewalOptions{}, ErrInvalidInput
	}
	return withLibraryClient(s, ctx, sessionID, func(client libraryJWXTClient) (jwxt.LibraryRenewalOptions, error) {
		return client.GetLibraryRenewalOptions(ctx, reservationID)
	})
}

func (s *Service) RenewLibraryReservation(
	ctx context.Context,
	sessionID string,
	reservationID string,
	duration int,
) (jwxt.LibraryOperationResult, error) {
	reservationID = strings.TrimSpace(reservationID)
	if reservationID == "" || duration <= 0 {
		return jwxt.LibraryOperationResult{}, ErrInvalidInput
	}
	return withLibraryClient(s, ctx, sessionID, func(client libraryJWXTClient) (jwxt.LibraryOperationResult, error) {
		return client.RenewLibraryReservation(ctx, reservationID, duration)
	})
}

// ExecuteLibraryAutoRenewal logs in with the user's persisted credential and
// performs a fresh eligibility check immediately before the one external
// mutation. It deliberately does not retry an ambiguous renewal response.
func (s *Service) ExecuteLibraryAutoRenewal(
	ctx context.Context,
	userID int64,
	reservationID string,
	duration int,
	expectedEnd string,
) (jwxt.LibraryOperationResult, error) {
	reservationID = strings.TrimSpace(reservationID)
	expectedEnd = strings.TrimSpace(expectedEnd)
	if userID <= 0 || reservationID == "" || duration <= 0 {
		return jwxt.LibraryOperationResult{}, ErrInvalidInput
	}
	user, err := s.repository.FindUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, ErrStoredUserNotFound) {
			return jwxt.LibraryOperationResult{}, &libraryAutoRenewalSkipError{reason: "登录信息已不存在，自动续座已跳过"}
		}
		return jwxt.LibraryOperationResult{}, err
	}
	password, err := s.credentials.Decrypt(user.EncryptedPassword)
	if err != nil {
		return jwxt.LibraryOperationResult{}, err
	}
	client, err := s.clientFactory()
	if err != nil {
		return jwxt.LibraryOperationResult{}, err
	}
	if err := client.Login(ctx, user.StudentNo, password); err != nil {
		return jwxt.LibraryOperationResult{}, err
	}
	libraryClient, ok := client.(libraryJWXTClient)
	if !ok {
		return jwxt.LibraryOperationResult{}, errors.New("academic: JWXT client does not support library access")
	}
	if err := libraryClient.LoginLibrary(ctx, user.StudentNo, password); err != nil {
		return jwxt.LibraryOperationResult{}, err
	}

	query := jwxt.LibraryReservationQuery{}
	if date := renewalDate(expectedEnd); date != "" {
		query.StartDate = date
		query.EndDate = date
	}
	reservations, err := libraryClient.ListLibraryReservations(ctx, query)
	if err != nil {
		return jwxt.LibraryOperationResult{}, err
	}
	var reservation *jwxt.LibraryReservation
	for index := range reservations {
		if strings.TrimSpace(reservations[index].ReservationID) == reservationID {
			reservation = &reservations[index]
			break
		}
	}
	if reservation == nil {
		return jwxt.LibraryOperationResult{}, &libraryAutoRenewalSkipError{reason: "预约记录已不存在，自动续座已跳过"}
	}
	if reservation.Kind != jwxt.LibraryKindSeat || !reservation.CanRenew {
		return jwxt.LibraryOperationResult{}, &libraryAutoRenewalSkipError{reason: "预约已结束或不再处于可续座状态"}
	}
	if expectedEnd != "" && !sameLibraryTime(reservation.End, expectedEnd) {
		return jwxt.LibraryOperationResult{}, &libraryAutoRenewalSkipError{reason: "预约结束时间已变化，为避免重复续座已跳过"}
	}
	return libraryClient.RenewLibraryReservation(ctx, reservationID, duration)
}

func renewalDate(value string) string {
	value = strings.TrimSpace(value)
	if len(value) >= len("2006-01-02") {
		candidate := value[:len("2006-01-02")]
		if _, err := time.Parse("2006-01-02", candidate); err == nil {
			return candidate
		}
	}
	return ""
}

func sameLibraryTime(left string, right string) bool {
	left = strings.TrimSpace(left)
	right = strings.TrimSpace(right)
	if left == right {
		return true
	}
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		location = time.FixedZone("Asia/Shanghai", 8*60*60)
	}
	parse := func(value string) (time.Time, error) {
		for _, layout := range []string{"2006-01-02 15:04:05", "2006-01-02T15:04:05", time.RFC3339} {
			if parsed, parseErr := time.ParseInLocation(layout, value, location); parseErr == nil {
				return parsed, nil
			}
		}
		return time.Time{}, fmt.Errorf("invalid library time %q", value)
	}
	first, firstErr := parse(left)
	second, secondErr := parse(right)
	return firstErr == nil && secondErr == nil && first.Equal(second)
}
