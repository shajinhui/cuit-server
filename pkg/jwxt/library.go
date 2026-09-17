package jwxt

import (
	"context"
	"errors"
	"net/url"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	libraryflow "cuit-server/pkg/jwxt/internal/library"
	loginflow "cuit-server/pkg/jwxt/internal/login"
)

const (
	LibraryKindSeat  = libraryflow.KindSeat
	LibraryKindStudy = libraryflow.KindStudy
)

type LibraryArea = libraryflow.Area
type LibrarySeat = libraryflow.Seat
type LibrarySeatQuery = libraryflow.SeatQuery
type LibraryReservation = libraryflow.Reservation
type LibraryReservationQuery = libraryflow.ReservationQuery
type LibraryCreateReservationRequest = libraryflow.CreateReservationRequest
type LibraryCapabilities = libraryflow.Capabilities
type LibraryOperationResult = libraryflow.OperationResult
type LibraryRenewalOptions = libraryflow.RenewalOptions
type LibraryCaptcha = libraryflow.Captcha
type LibrarySeatMap = libraryflow.SeatMap

// LoginLibrary creates a library session with a CookieJar independent from
// EAMS and LABMS. Credentials are only used during this call.
func (c *Client) LoginLibrary(ctx context.Context, username string, password string) error {
	if !c.loggedIn {
		return jwxterr.WithMessage(ErrSessionExpired, "EAMS login required")
	}
	loginCfg, err := c.loginConfig()
	if err != nil {
		return err
	}
	loginCfg.TraceLogin = true
	baseURL, err := c.libraryBaseURL()
	if err != nil {
		return err
	}
	startURL, err := libraryflow.LoginURL(ctx, c.libraryResty, baseURL, c.cfg.LibraryWebURL)
	if err != nil {
		c.clearLibrarySession()
		return err
	}
	// 图书馆的票据可能落在 Portal 登录响应、校内账号切换或起始跳转中的任意一条上，
	// 因此由 auth/userInfo 自己确认会话是否真的建立。
	var session libraryflow.UserSession
	err = loginflow.LoginTargetWithVerifier(ctx, c.libraryResty, loginCfg, startURL, username, password, func(ctx context.Context) error {
		candidate, verifyErr := libraryflow.BootstrapSession(ctx, c.libraryResty, baseURL)
		if verifyErr != nil {
			return verifyErr
		}
		session = candidate
		return nil
	})
	if err != nil {
		c.clearLibrarySession()
		return err
	}
	c.libraryResty.
		SetHeader("token", session.Token).
		SetHeader("Referer", strings.TrimSpace(c.cfg.LibraryWebURL))
	if webURL, parseErr := url.Parse(c.cfg.LibraryWebURL); parseErr == nil && webURL.Scheme != "" && webURL.Host != "" {
		c.libraryResty.SetHeader("Origin", webURL.Scheme+"://"+webURL.Host)
	}
	c.libraryUser = session
	c.libraryLoggedIn = true
	return nil
}

func (c *Client) GetLibraryCapabilities(ctx context.Context) (LibraryCapabilities, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryCapabilities{}, err
	}
	result, err := libraryflow.GetCapabilities(ctx, c.libraryResty, baseURL, c.cfg.LibraryWebURL)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) ListLibraryAreas(ctx context.Context, kind string) ([]LibraryArea, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return nil, err
	}
	result, err := libraryflow.ListAreas(ctx, c.libraryResty, baseURL, kind)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) ListLibrarySeats(ctx context.Context, query LibrarySeatQuery) ([]LibrarySeat, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return nil, err
	}
	result, err := libraryflow.ListSeats(ctx, c.libraryResty, baseURL, query)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) ListLibraryReservations(
	ctx context.Context,
	query LibraryReservationQuery,
) ([]LibraryReservation, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return nil, err
	}
	result, err := libraryflow.ListReservations(ctx, c.libraryResty, baseURL, query)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) CreateLibraryReservation(
	ctx context.Context,
	request LibraryCreateReservationRequest,
) (LibraryOperationResult, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryOperationResult{}, err
	}
	result, err := libraryflow.CreateReservation(ctx, c.libraryResty, baseURL, c.libraryUser, request)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) CancelLibraryReservation(
	ctx context.Context,
	uuid string,
) (LibraryOperationResult, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryOperationResult{}, err
	}
	result, err := libraryflow.Cancel(ctx, c.libraryResty, baseURL, uuid)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) FinishLibraryReservation(
	ctx context.Context,
	uuid string,
) (LibraryOperationResult, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryOperationResult{}, err
	}
	result, err := libraryflow.Finish(ctx, c.libraryResty, baseURL, uuid)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) TemporaryLeaveLibraryReservation(
	ctx context.Context,
	reservationID string,
) (LibraryOperationResult, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryOperationResult{}, err
	}
	result, err := libraryflow.TemporaryLeave(ctx, c.libraryResty, baseURL, reservationID)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) GetLibraryRenewalOptions(
	ctx context.Context,
	reservationID string,
) (LibraryRenewalOptions, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryRenewalOptions{}, err
	}
	result, err := libraryflow.GetRenewalOptions(ctx, c.libraryResty, baseURL, reservationID)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) RenewLibraryReservation(
	ctx context.Context,
	reservationID string,
	duration int,
) (LibraryOperationResult, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryOperationResult{}, err
	}
	result, err := libraryflow.Renew(ctx, c.libraryResty, baseURL, reservationID, duration)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) GetLibraryCaptcha(ctx context.Context) (LibraryCaptcha, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibraryCaptcha{}, err
	}
	result, err := libraryflow.GetCaptcha(ctx, c.libraryResty, baseURL)
	c.observeLibraryError(err)
	return result, err
}

func (c *Client) GetLibrarySeatMap(ctx context.Context, roomID string) (LibrarySeatMap, error) {
	baseURL, err := c.readyLibraryBaseURL()
	if err != nil {
		return LibrarySeatMap{}, err
	}
	result, err := libraryflow.GetSeatMap(ctx, c.libraryResty, baseURL, roomID)
	c.observeLibraryError(err)
	return result, err
}

func LibraryErrorMessage(err error) string {
	return libraryflow.PublicMessage(err)
}

func (c *Client) libraryBaseURL() (*url.URL, error) {
	baseURL, err := url.Parse(c.cfg.LibraryBaseURL)
	if err != nil || baseURL.Host == "" {
		return nil, jwxterr.WithMessage(ErrLibraryQueryFailed, "invalid library base URL")
	}
	return baseURL, nil
}

func (c *Client) readyLibraryBaseURL() (*url.URL, error) {
	if !c.loggedIn || !c.libraryLoggedIn || c.libraryUser.Token == "" {
		return nil, jwxterr.WithMessage(ErrSessionExpired, "library login required")
	}
	return c.libraryBaseURL()
}

func (c *Client) observeLibraryError(err error) {
	if errors.Is(err, ErrSessionExpired) {
		c.clearLibrarySession()
	}
}

func (c *Client) clearLibrarySession() {
	c.libraryLoggedIn = false
	c.libraryUser = libraryflow.UserSession{}
	c.libraryResty.SetHeader("token", "")
}
