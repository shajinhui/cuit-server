package library

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const (
	dateLayout     = "2006-01-02"
	dateTimeLayout = "2006-01-02 15:04:05"
	allStatuses    = 32766
)

var shanghaiLocation = func() *time.Location {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		return time.FixedZone("Asia/Shanghai", 8*60*60)
	}
	return location
}()

// LoginURL asks the service for a fresh CAS entry point. The returned URL is
// tied to this client's cookie jar and must be followed by the same client.
func LoginURL(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	webURL string,
) (*url.URL, error) {
	requestURL := endpoint(baseURL, "auth/address")
	response, err := client.R().
		SetContext(ctx).
		SetQueryParams(map[string]string{
			"finalAddress": strings.TrimSpace(webURL),
			"manager":      "false",
			"consoleType":  "16",
		}).
		Get(requestURL)
	if err != nil {
		return nil, jwxterr.WithMessage(jwxterr.ErrRemoteUnavailable, "request library CAS address failed")
	}
	envelope, err := parseEnvelope(response, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return nil, err
	}
	var address flexString
	if err := json.Unmarshal(envelope.Data, &address); err != nil || strings.TrimSpace(string(address)) == "" {
		return nil, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "图书馆登录入口解析失败"}
	}
	loginURL, err := url.Parse(strings.TrimSpace(string(address)))
	if err != nil || loginURL.Host == "" {
		return nil, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "图书馆登录入口无效"}
	}
	return loginURL, nil
}

func BootstrapSession(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
) (UserSession, error) {
	envelope, err := getEnvelope(ctx, client, baseURL, "auth/userInfo", nil, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return UserSession{}, err
	}
	var info userInfo
	if err := json.Unmarshal(envelope.Data, &info); err != nil {
		return UserSession{}, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "图书馆账号信息解析失败"}
	}
	session := UserSession{AccountNo: strings.TrimSpace(string(info.AccountNo)), Token: strings.TrimSpace(info.Token)}
	if session.AccountNo == "" || session.Token == "" {
		return UserSession{}, &Error{Kind: jwxterr.ErrSessionExpired, Message: "图书馆登录未完成"}
	}
	return session, nil
}

func ListAreas(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	kind string,
) ([]Area, error) {
	path := "seatMenu"
	if kind == KindStudy {
		path = "psgSeatMenu"
	}
	envelope, err := getEnvelope(ctx, client, baseURL, path, nil, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return nil, err
	}
	var nodes []menuNode
	if err := decodeArray(envelope.Data, &nodes); err != nil {
		return nil, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "图书馆区域数据解析失败"}
	}
	areas := make([]Area, 0, len(nodes))
	for _, node := range nodes {
		areas = append(areas, mapArea(node, ""))
	}
	return areas, nil
}

func ListSeats(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	query SeatQuery,
) ([]Seat, error) {
	if err := validateSeatQuery(query); err != nil {
		return nil, err
	}
	resvDates := strings.ReplaceAll(query.StartDate, "-", "")
	sysKind := SysKindSeat
	if query.Kind == KindStudy {
		sysKind = SysKindStudy
		resvDates += "," + strings.ReplaceAll(query.EndDate, "-", "")
	}
	envelope, err := getEnvelope(ctx, client, baseURL, "reserve", map[string]string{
		"roomIds":   query.RoomID,
		"resvDates": resvDates,
		"sysKind":   strconv.Itoa(sysKind),
	}, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return nil, err
	}
	var upstream []upstreamSeat
	if err := decodeArray(envelope.Data, &upstream); err != nil {
		return nil, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "图书馆座位数据解析失败"}
	}
	seats := make([]Seat, 0, len(upstream))
	for _, item := range upstream {
		seat := mapSeat(item, query)
		if seat.ID != "" {
			seats = append(seats, seat)
		}
	}
	sort.SliceStable(seats, func(left, right int) bool {
		return naturalLess(seats[left].Number, seats[right].Number)
	})
	return seats, nil
}

func ListReservations(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	query ReservationQuery,
) ([]Reservation, error) {
	startDate, endDate, err := reservationDateRange(query)
	if err != nil {
		return nil, err
	}
	regularEnvelope, err := getEnvelope(ctx, client, baseURL, "reserve/resvInfo", map[string]string{
		"beginDate":  startDate,
		"endDate":    endDate,
		"needStatus": strconv.Itoa(allStatuses),
		"page":       "1",
		"pageNum":    "200",
		"orderKey":   "gmt_create",
		"orderModel": "desc",
	}, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return nil, err
	}
	studyEnvelope, err := getEnvelope(ctx, client, baseURL, "psgSeat/resvInfo", map[string]string{
		"page":          "1",
		"pageSize":      "200",
		"resvBeginTime": startDate,
		"resvEndTime":   endDate,
		"resvStatus":    strconv.Itoa(allStatuses),
		"orderKey":      "gmt_create",
		"orderModel":    "desc",
	}, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return nil, err
	}
	var regular []upstreamReservation
	if err := decodeArray(regularEnvelope.Data, &regular); err != nil {
		return nil, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "座位预约记录解析失败"}
	}
	var study []upstreamReservation
	if err := decodeArray(studyEnvelope.Data, &study); err != nil {
		return nil, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "自修室预约记录解析失败"}
	}
	reservations := make([]Reservation, 0, len(regular)+len(study))
	for _, item := range regular {
		reservations = append(reservations, mapReservation(item, KindSeat))
	}
	for _, item := range study {
		reservations = append(reservations, mapReservation(item, KindStudy))
	}
	sort.SliceStable(reservations, func(left, right int) bool {
		return reservations[left].Start > reservations[right].Start
	})
	return reservations, nil
}

func GetCapabilities(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	officialURL string,
) (Capabilities, error) {
	envelope, err := getEnvelope(ctx, client, baseURL, "sysConfig/public", nil, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return Capabilities{}, err
	}
	values := configValues(envelope.Data)
	captchaMode := "none"
	switch strings.TrimSpace(values["resvCode"]) {
	case "1":
		captchaMode = "image"
	case "2":
		captchaMode = "interactive"
	}
	memoLength, _ := strconv.Atoi(strings.TrimSpace(values["resvmemolen"]))
	memoRequired := bitEnabled(values["resvmemo"], SysKindSeat) && bitEnabled(values["classKindMemoRequired"], SysKindSeat)
	return Capabilities{
		CaptchaMode:       captchaMode,
		MemoMaximumLength: memoLength,
		MemoRequired:      memoRequired,
		TemporaryLeave:    true,
		FinishEarly:       true,
		OfficialURL:       strings.TrimSpace(officialURL),
	}, nil
}

func GetCaptcha(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
) (Captcha, error) {
	response, err := client.R().
		SetContext(ctx).
		SetQueryParam("id", strconv.FormatInt(time.Now().UnixMilli(), 10)).
		Get(endpoint(baseURL, "captcha"))
	if err != nil {
		return Captcha{}, jwxterr.WithMessage(jwxterr.ErrRemoteUnavailable, "request library captcha failed")
	}
	if response.StatusCode() == http.StatusUnauthorized || response.StatusCode() == http.StatusForbidden {
		return Captcha{}, &Error{Kind: jwxterr.ErrSessionExpired, Message: "图书馆登录已失效"}
	}
	if response.IsError() || len(response.Body()) == 0 {
		return Captcha{}, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "验证码读取失败"}
	}
	contentType := strings.TrimSpace(response.Header().Get("Content-Type"))
	if strings.Contains(strings.ToLower(contentType), "json") || strings.HasPrefix(strings.TrimSpace(string(response.Body())), "{") {
		if _, envelopeErr := parseEnvelope(response, jwxterr.ErrLibraryQueryFailed); envelopeErr != nil {
			return Captcha{}, envelopeErr
		}
		return Captcha{}, &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "验证码响应中未包含图片"}
	}
	if !strings.HasPrefix(strings.ToLower(contentType), "image/") {
		contentType = "image/png"
	}
	return Captcha{ContentType: contentType, Data: append([]byte(nil), response.Body()...)}, nil
}

func CreateReservation(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	user UserSession,
	request CreateReservationRequest,
) (OperationResult, error) {
	if err := validateCreateRequest(request); err != nil {
		return OperationResult{}, err
	}
	capabilities, err := GetCapabilities(ctx, client, baseURL, "")
	if err != nil {
		return OperationResult{}, err
	}
	if capabilities.CaptchaMode == "interactive" {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryVerification, Message: "当前预约需要完成交互验证，请前往官方预约页操作"}
	}
	if capabilities.CaptchaMode == "image" && strings.TrimSpace(request.Captcha) == "" {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryVerification, Message: "请输入图形验证码"}
	}
	if capabilities.MemoRequired && strings.TrimSpace(request.Memo) == "" {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryVerification, Message: "请填写预约用途"}
	}
	if capabilities.MemoMaximumLength > 0 && len([]rune(request.Memo)) > capabilities.MemoMaximumLength {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryVerification, Message: fmt.Sprintf("预约用途不能超过 %d 个字", capabilities.MemoMaximumLength)}
	}

	if request.Kind == KindStudy {
		return createStudyReservation(ctx, client, baseURL, user, request)
	}
	return createSeatReservation(ctx, client, baseURL, user, request)
}

func Cancel(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	uuid string,
) (OperationResult, error) {
	return operation(ctx, client, baseURL, "reserve/delete", map[string]string{"uuid": strings.TrimSpace(uuid)}, "预约已取消")
}

func Finish(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	uuid string,
) (OperationResult, error) {
	return operation(ctx, client, baseURL, "reserve/endAhaed", map[string]string{"uuid": strings.TrimSpace(uuid)}, "预约已提前结束")
}

func TemporaryLeave(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	reservationID string,
) (OperationResult, error) {
	return operation(ctx, client, baseURL, "seatOperation/tempLeave", map[string]string{"resvId": strings.TrimSpace(reservationID)}, "已登记暂离")
}

func createSeatReservation(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	user UserSession,
	request CreateReservationRequest,
) (OperationResult, error) {
	seats, err := ListSeats(ctx, client, baseURL, SeatQuery{
		Kind:      KindSeat,
		RoomID:    request.RoomID,
		StartDate: request.StartDate,
		EndDate:   request.StartDate,
		StartTime: request.StartTime,
		EndTime:   request.EndTime,
	})
	if err != nil {
		return OperationResult{}, err
	}
	var selected *Seat
	for index := range seats {
		if seats[index].ID == request.SeatID {
			selected = &seats[index]
			break
		}
	}
	if selected == nil || selected.OnlyView || selected.Status != "available" {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryOperationRejected, Message: "该座位当前不可预约，请刷新后重试"}
	}
	if selected.Rule.ID == "" {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryOperationRejected, Message: "该座位未返回可用预约规则"}
	}
	if _, err := getEnvelope(ctx, client, baseURL, "device/tips", map[string]string{
		"devId":           request.SeatID,
		"classKind":       strconv.Itoa(SysKindSeat),
		"resvRuleId":      selected.Rule.ID,
		"chooseBeginTime": request.StartDate + " " + request.StartTime + ":00",
		"isConsole":       "false",
	}, jwxterr.ErrLibraryOperationRejected); err != nil {
		return OperationResult{}, err
	}
	publicKey, err := getPublicKey(ctx, client, baseURL)
	if err != nil {
		return OperationResult{}, err
	}
	encryptedKey, encryptedSeat, err := encryptSeatID(publicKey, request.SeatID)
	if err != nil {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryOperationRejected, Message: "座位预约数据加密失败"}
	}
	body := map[string]any{
		"sysKind":         SysKindSeat,
		"appAccNo":        user.AccountNo,
		"memberKind":      1,
		"resvMember":      []string{user.AccountNo},
		"resvBeginTime":   request.StartDate + " " + request.StartTime + ":00",
		"resvEndTime":     request.StartDate + " " + request.EndTime + ":00",
		"testName":        strings.TrimSpace(request.Title),
		"captcha":         strings.TrimSpace(request.Captcha),
		"resvProperty":    0,
		"resvDev":         []int{0},
		"encryptVlaue":    encryptedKey,
		"resvDevEncrypts": []string{encryptedSeat},
		"memo":            strings.TrimSpace(request.Memo),
	}
	return createOperation(ctx, client, baseURL, body)
}

func createStudyReservation(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	user UserSession,
	request CreateReservationRequest,
) (OperationResult, error) {
	seats, err := ListSeats(ctx, client, baseURL, SeatQuery{
		Kind:      KindStudy,
		RoomID:    request.RoomID,
		StartDate: request.StartDate,
		EndDate:   request.EndDate,
	})
	if err != nil {
		return OperationResult{}, err
	}
	var selected *Seat
	for _, seat := range seats {
		if seat.ID == request.SeatID && seat.Status == "available" && !seat.OnlyView {
			candidate := seat
			selected = &candidate
			break
		}
	}
	if selected == nil {
		return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryOperationRejected, Message: "该自修室当前不可预约，请刷新后重试"}
	}
	begin := studyBeginTime(request.StartDate, selected.OpenStart)
	body := map[string]any{
		"sysKind":       SysKindStudy,
		"appAccNo":      user.AccountNo,
		"memberKind":    1,
		"resvMember":    []string{user.AccountNo},
		"resvBeginTime": begin,
		"resvEndTime":   request.EndDate + " 23:59:59",
		"testName":      "",
		"captcha":       strings.TrimSpace(request.Captcha),
		"resvProperty":  SysKindStudy,
		"resvDev":       []any{numericOrString(request.SeatID)},
		"memo":          strings.TrimSpace(request.Memo),
	}
	return createOperation(ctx, client, baseURL, body)
}

// 自修室按日期预约：未来日期从当天开放时间开始，当天预约则取
// “现在 + 1 分钟”与开放时间中较晚的一个，避免提交已经过去的开始时间。
func studyBeginTime(startDate string, openStart string) string {
	start, err := time.ParseInLocation(dateLayout, startDate, shanghaiLocation)
	if err != nil {
		return startDate + " 00:00:00"
	}
	begin := time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, shanghaiLocation)
	if open, openErr := time.Parse("15:04", strings.TrimSpace(openStart)); openErr == nil {
		begin = time.Date(start.Year(), start.Month(), start.Day(), open.Hour(), open.Minute(), 0, 0, shanghaiLocation)
	}
	if sameDate(start, time.Now().In(shanghaiLocation)) {
		if candidate := time.Now().In(shanghaiLocation).Add(time.Minute); candidate.After(begin) {
			begin = candidate
		}
	}
	return begin.Format(dateTimeLayout)
}

func createOperation(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	body map[string]any,
) (OperationResult, error) {
	envelope, err := postEnvelope(ctx, client, baseURL, "reserve/seat", body, jwxterr.ErrLibraryOperationRejected)
	if err != nil {
		return OperationResult{}, err
	}
	message := strings.TrimSpace(envelope.Message)
	if message == "" {
		message = dataMessage(envelope.Data)
	}
	if message == "" {
		message = "预约成功"
	}
	return OperationResult{Message: message}, nil
}

func operation(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	path string,
	body map[string]string,
	fallback string,
) (OperationResult, error) {
	for _, value := range body {
		if value == "" {
			return OperationResult{}, &Error{Kind: jwxterr.ErrLibraryVerification, Message: "预约记录标识不能为空"}
		}
	}
	envelope, err := postEnvelope(ctx, client, baseURL, path, body, jwxterr.ErrLibraryOperationRejected)
	if err != nil {
		return OperationResult{}, err
	}
	message := strings.TrimSpace(envelope.Message)
	if message == "" {
		message = dataMessage(envelope.Data)
	}
	if message == "" {
		message = fallback
	}
	return OperationResult{Message: message}, nil
}

func getPublicKey(ctx context.Context, client *resty.Client, baseURL *url.URL) (string, error) {
	envelope, err := getEnvelope(ctx, client, baseURL, "login/publicKey", nil, jwxterr.ErrLibraryQueryFailed)
	if err != nil {
		return "", err
	}
	var direct flexString
	if err := json.Unmarshal(envelope.Data, &direct); err == nil && strings.Contains(string(direct), "BEGIN PUBLIC KEY") {
		return string(direct), nil
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(envelope.Data, &object); err == nil {
		for _, key := range []string{"publicKey", "key", "rsaPublicKey"} {
			var value string
			if json.Unmarshal(object[key], &value) == nil && strings.TrimSpace(value) != "" {
				return value, nil
			}
		}
	}
	return "", &Error{Kind: jwxterr.ErrLibraryQueryFailed, Message: "预约加密公钥读取失败"}
}

func getEnvelope(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	path string,
	query map[string]string,
	kind error,
) (envelope, error) {
	request := client.R().SetContext(ctx)
	if len(query) > 0 {
		request.SetQueryParams(query)
	}
	response, err := request.Get(endpoint(baseURL, path))
	if err != nil {
		return envelope{}, jwxterr.WithMessage(jwxterr.ErrRemoteUnavailable, "request library service failed")
	}
	return parseEnvelope(response, kind)
}

func postEnvelope(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	path string,
	body any,
	kind error,
) (envelope, error) {
	response, err := client.R().SetContext(ctx).SetBody(body).Post(endpoint(baseURL, path))
	if err != nil {
		return envelope{}, jwxterr.WithMessage(jwxterr.ErrRemoteUnavailable, "request library service failed")
	}
	return parseEnvelope(response, kind)
}

func parseEnvelope(response *resty.Response, kind error) (envelope, error) {
	if response.StatusCode() == http.StatusUnauthorized || response.StatusCode() == http.StatusForbidden ||
		(response.StatusCode() >= 300 && response.StatusCode() < 400) {
		return envelope{}, &Error{Kind: jwxterr.ErrSessionExpired, Message: "图书馆登录已失效"}
	}
	if response.IsError() {
		return envelope{}, &Error{Kind: kind, Message: "图书馆系统响应异常"}
	}
	var result envelope
	if err := json.Unmarshal(response.Body(), &result); err != nil {
		return envelope{}, &Error{Kind: kind, Message: "图书馆系统响应格式异常"}
	}
	if strings.TrimSpace(result.Message) == "" {
		result.Message = strings.TrimSpace(result.Msg)
	}
	if int(result.Code) == 300 {
		return envelope{}, &Error{Kind: jwxterr.ErrSessionExpired, Message: messageOr(result.Message, "图书馆登录已失效")}
	}
	if int(result.Code) != 0 {
		return envelope{}, &Error{Kind: kind, Message: messageOr(result.Message, "图书馆系统拒绝了本次请求")}
	}
	return result, nil
}

func endpoint(baseURL *url.URL, path string) string {
	base := *baseURL
	if !strings.HasSuffix(base.Path, "/") {
		base.Path += "/"
	}
	reference := &url.URL{Path: strings.TrimLeft(path, "/")}
	return base.ResolveReference(reference).String()
}

func decodeArray(data json.RawMessage, target any) error {
	trimmed := strings.TrimSpace(string(data))
	if trimmed == "" || trimmed == "null" {
		return json.Unmarshal([]byte("[]"), target)
	}
	if strings.HasPrefix(trimmed, "[") {
		return json.Unmarshal(data, target)
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(data, &object); err != nil {
		return err
	}
	for _, key := range []string{"list", "records", "rows", "content", "data"} {
		if value, ok := object[key]; ok {
			return decodeArray(value, target)
		}
	}
	return errors.New("library: array not found")
}

func mapArea(node menuNode, parent string) Area {
	name := localized(node.Name)
	path := name
	if parent != "" && name != "" {
		path = parent + " / " + name
	}
	available := int(node.Available)
	if available == 0 {
		available = int(node.AvailableAlt)
	}
	area := Area{
		ID:        string(node.ID),
		Name:      name,
		Path:      path,
		Available: available,
		Total:     int(node.Total),
		Leaf:      len(node.Children) == 0,
	}
	for _, child := range node.Children {
		area.Children = append(area.Children, mapArea(child, path))
	}
	return area
}

func mapSeat(item upstreamSeat, query SeatQuery) Seat {
	coordinate := strings.TrimSpace(item.MobileCoordinate)
	if coordinate == "" {
		coordinate = strings.TrimSpace(item.Coordinate)
	}
	seat := Seat{
		ID:         string(item.ID),
		Number:     localized(string(item.Number)),
		Name:       localized(item.Name),
		Building:   localized(item.Building),
		Room:       localized(item.Room),
		Coordinate: coordinate,
		Status:     "available",
		OnlyView:   item.OnlyView,
		OpenStart:  item.OpenStart,
		OpenEnd:    item.OpenEnd,
		Rule: Rule{
			ID:              string(item.Rule.ID),
			EarliestMinutes: int(item.Rule.EarliestMinutes),
			LatestMinutes:   int(item.Rule.LatestMinutes),
			MinimumMinutes:  int(item.Rule.MinimumMinutes),
			MaximumMinutes:  int(item.Rule.MaximumMinutes),
			CancelMinutes:   int(item.Rule.CancelMinutes),
			Deadline:        string(item.Rule.Deadline),
			LaterLineTime:   string(item.Rule.LaterLineTime),
		},
	}
	if seat.Number == "" {
		seat.Number = seat.Name
	}
	if seat.Name == "" {
		seat.Name = seat.Number
	}
	for _, open := range item.OpenTimes {
		seat.OpenTimes = append(seat.OpenTimes, OpenTime{Start: open.Start, End: open.End, Limit: int(open.Limit)})
	}
	for _, period := range item.Reservations {
		seat.Reservations = append(seat.Reservations, ReservationPeriod{Start: period.Start, End: period.End})
	}
	if item.OnlyView || int(item.DeviceProperty)&2 == 0 {
		seat.Status = "unavailable"
	} else if query.Kind == KindSeat && overlapsReservation(item.Reservations, query) {
		seat.Status = "reserved"
	}
	return seat
}

func overlapsReservation(periods []upstreamPeriod, query SeatQuery) bool {
	start, startErr := time.ParseInLocation(dateTimeLayout, query.StartDate+" "+query.StartTime+":00", shanghaiLocation)
	end, endErr := time.ParseInLocation(dateTimeLayout, query.StartDate+" "+query.EndTime+":00", shanghaiLocation)
	if startErr != nil || endErr != nil {
		return false
	}
	for _, period := range periods {
		periodStart, firstErr := parseUpstreamTime(period.Start)
		periodEnd, secondErr := parseUpstreamTime(period.End)
		if firstErr == nil && secondErr == nil && start.Before(periodEnd) && end.After(periodStart) {
			return true
		}
	}
	return false
}

func mapReservation(item upstreamReservation, fallbackKind string) Reservation {
	kind := fallbackKind
	if int(item.ClassKind) == SysKindStudy || int(item.Property)&SysKindStudy != 0 {
		kind = KindStudy
	}
	building, room, seat := localized(item.Building), localized(item.Room), localized(item.DeviceName)
	if len(item.Devices) > 0 {
		device := item.Devices[0]
		if building == "" {
			building = localized(device.Building)
		}
		if room == "" {
			room = localized(device.Room)
		}
		if seat == "" {
			seat = localized(device.Name)
		}
	}
	status := int(item.Status)
	return Reservation{
		UUID:                item.UUID,
		ReservationID:       string(item.ReservationID),
		Kind:                kind,
		Name:                firstNonEmpty(localized(item.Title), localized(item.Name), seat),
		Building:            building,
		Room:                room,
		Seat:                seat,
		Start:               string(item.Start),
		End:                 string(item.End),
		ActualEnd:           string(item.ActualEnd),
		Status:              status,
		StatusLabel:         statusLabel(status),
		CanCancel:           status&4 == 0 && status&128 == 0,
		CanTemporaryLeave:   kind == KindSeat && status&64 != 0 && status&(128|2048) == 0,
		CanFinish:           item.EndEarly && status&128 == 0,
		TemporaryLeaveUntil: string(item.TemporaryLeaveUntil),
		ViolationReason:     localized(item.ViolationReason),
	}
}

func statusLabel(status int) string {
	// 与图书馆前端 a59f 模块的标签顺序保持一致，多状态位时取第一个匹配项。
	labels := []struct {
		bit   int
		label string
	}{
		{256, "待审核"}, {512, "审核未通过"}, {1024, "审核通过"}, {2048, "暂离中"},
		{16, "违约"}, {64, "已签到"}, {2, "待生效"}, {4, "生效中"}, {128, "已结束"},
		{8192, "待同意"}, {16384, "举报"},
	}
	for _, item := range labels {
		if status&item.bit != 0 {
			return item.label
		}
	}
	return "状态未知"
}

func configValues(data json.RawMessage) map[string]string {
	values := make(map[string]string)
	var items []configItem
	if decodeArray(data, &items) == nil {
		for _, item := range items {
			values[item.Key] = string(item.Value)
		}
	}
	var object map[string]json.RawMessage
	if json.Unmarshal(data, &object) == nil {
		for key, raw := range object {
			var value flexString
			if json.Unmarshal(raw, &value) == nil {
				values[key] = string(value)
			}
		}
	}
	return values
}

func validateSeatQuery(query SeatQuery) error {
	if query.Kind != KindSeat && query.Kind != KindStudy {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "预约类型无效"}
	}
	if strings.TrimSpace(query.RoomID) == "" {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "请选择预约区域"}
	}
	start, err := time.ParseInLocation(dateLayout, query.StartDate, shanghaiLocation)
	if err != nil {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "预约日期无效"}
	}
	now := time.Now().In(shanghaiLocation)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, shanghaiLocation)
	if start.Before(today) {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "不能预约过去的日期"}
	}
	if query.Kind == KindStudy {
		end, parseErr := time.ParseInLocation(dateLayout, query.EndDate, shanghaiLocation)
		if parseErr != nil || end.Before(start) {
			return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "自修室结束日期无效"}
		}
		return nil
	}
	if start.After(today.AddDate(0, 0, 1)) {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "普通座位仅可查询当天或次日"}
	}
	if _, err := time.Parse("15:04", query.StartTime); err != nil {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "预约开始时间无效"}
	}
	if _, err := time.Parse("15:04", query.EndTime); err != nil || query.EndTime <= query.StartTime {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "预约结束时间无效"}
	}
	return nil
}

func validateCreateRequest(request CreateReservationRequest) error {
	if strings.TrimSpace(request.SeatID) == "" {
		return &Error{Kind: jwxterr.ErrLibraryVerification, Message: "请选择座位"}
	}
	return validateSeatQuery(SeatQuery{
		Kind: request.Kind, RoomID: request.RoomID, StartDate: request.StartDate,
		EndDate: request.EndDate, StartTime: request.StartTime, EndTime: request.EndTime,
	})
}

func reservationDateRange(query ReservationQuery) (string, string, error) {
	now := time.Now().In(shanghaiLocation)
	start := strings.TrimSpace(query.StartDate)
	end := strings.TrimSpace(query.EndDate)
	if start == "" {
		start = now.AddDate(0, -3, 0).Format(dateLayout)
	}
	if end == "" {
		end = now.AddDate(0, 3, 0).Format(dateLayout)
	}
	startTime, firstErr := time.ParseInLocation(dateLayout, start, shanghaiLocation)
	endTime, secondErr := time.ParseInLocation(dateLayout, end, shanghaiLocation)
	if firstErr != nil || secondErr != nil || endTime.Before(startTime) {
		return "", "", &Error{Kind: jwxterr.ErrLibraryVerification, Message: "预约记录日期范围无效"}
	}
	return start, end, nil
}

func parseUpstreamTime(value string) (time.Time, error) {
	for _, layout := range []string{dateTimeLayout, "2006/01/02 15:04:05", "2006-01-02T15:04:05"} {
		if parsed, err := time.ParseInLocation(layout, strings.TrimSpace(value), shanghaiLocation); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("library: invalid time %q", value)
}

func localized(value string) string {
	parts := strings.Split(value, "|")
	if len(parts) == 0 {
		return ""
	}
	return strings.TrimSpace(parts[0])
}

func messageOr(value, fallback string) string {
	if strings.TrimSpace(value) != "" {
		return strings.TrimSpace(value)
	}
	return fallback
}

func dataMessage(data json.RawMessage) string {
	var value flexString
	if json.Unmarshal(data, &value) == nil {
		return strings.TrimSpace(string(value))
	}
	return ""
}

func naturalLess(left, right string) bool {
	leftNumber, leftErr := strconv.Atoi(strings.TrimSpace(left))
	rightNumber, rightErr := strconv.Atoi(strings.TrimSpace(right))
	if leftErr == nil && rightErr == nil {
		return leftNumber < rightNumber
	}
	return left < right
}

func bitEnabled(value string, bit int) bool {
	number, err := strconv.Atoi(strings.TrimSpace(value))
	return err == nil && number&bit != 0
}

func numericOrString(value string) any {
	if number, err := strconv.ParseInt(value, 10, 64); err == nil {
		return number
	}
	return value
}

func sameDate(left time.Time, right time.Time) bool {
	leftYear, leftMonth, leftDay := left.Date()
	rightYear, rightMonth, rightDay := right.Date()
	return leftYear == rightYear && leftMonth == rightMonth && leftDay == rightDay
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return "预约"
}
