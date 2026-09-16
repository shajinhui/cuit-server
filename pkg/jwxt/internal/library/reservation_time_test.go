package library

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/go-resty/resty/v2"
)

// 预约记录接口返回毫秒时间戳（resvBeginTime: 1789555200000），座位接口返回字符串。
// 早期实现把时间当成字符串解析，只要账号存在一条预约记录，整条列表就解析失败，
// App 侧表现为“服务暂时不可用”。这里用真实抓到的响应固定住行为。
const seatReservationPayload = `{"code":0,"message":"查询成功","data":[{
	"uuid":"36d67b7eec4247eeacea53efc0c214c9",
	"resvId":213550,
	"appAccNo":18346,
	"resvDate":20260916,
	"resvBeginTime":1789555200000,
	"resvEndTime":1789567200000,
	"resvEndRealTime":1789557026000,
	"resvDelTime":null,
	"resvStatus":1169,
	"classKind":8,
	"resvProperty":0,
	"testName":"",
	"resvName":"沙金辉",
	"memo":"好",
	"devName":null,
	"leftTime":null,
	"checkInfo":null,
	"endEarly":false,
	"tempLeaveEndTime":null,
	"resvCheckInTime":null,
	"resvDevInfoList":[{
		"resvId":213550,"devId":25,"devName":"H1F-A025","devSn":25,"kindId":1,
		"devStatus":0,"devProp":2,"kindName":"普通座位","classKind":8,
		"roomId":7,"roomSn":"7","roomName":"航空港一楼A区",
		"labId":2,"labName":"航空港一楼","campusId":1
	}],
	"resvMemberInfoList":[{"uuid":"9fe18ebfbb1f4dc19d3fb3542fba194d","resvId":213550,"accNo":18346}]
}],"count":1,"vals":null}`

const studyReservationPayload = `{"code":0,"message":"查询成功","data":[{
	"uuid":"5f2b8e0a4c1d4c0b9d0a3f0b1c2d3e4f",
	"resvId":"213601",
	"resvBeginTime":"2026-09-17 09:00:00",
	"resvEndTime":"2026-09-17 15:00:00",
	"resvStatus":2,
	"classKind":16,
	"resvName":"沙金辉",
	"roomName":"自修室",
	"resvDevInfoList":[{"devId":9,"devName":"Z-09","roomName":"自修室","labName":"图书馆"}]
}],"count":1}`

func TestListReservationsParsesTimestampAndStringTimes(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		switch request.URL.Path {
		case "/api/reserve/resvInfo":
			_, _ = writer.Write([]byte(seatReservationPayload))
		case "/api/psgSeat/resvInfo":
			_, _ = writer.Write([]byte(studyReservationPayload))
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	baseURL, err := url.Parse(server.URL + "/api/")
	if err != nil {
		t.Fatal(err)
	}

	reservations, err := ListReservations(context.Background(), resty.New(), baseURL, ReservationQuery{})
	if err != nil {
		t.Fatalf("ListReservations returned error: %v", err)
	}
	if len(reservations) != 2 {
		t.Fatalf("expected 2 reservations, got %d: %+v", len(reservations), reservations)
	}
	byUUID := make(map[string]Reservation, len(reservations))
	for _, reservation := range reservations {
		byUUID[reservation.UUID] = reservation
	}

	seat := byUUID["36d67b7eec4247eeacea53efc0c214c9"]
	if seat.Start != "2026-09-16 18:40:00" || seat.End != "2026-09-16 22:00:00" || seat.ActualEnd != "2026-09-16 19:10:26" {
		t.Fatalf("seat reservation times not normalised: %+v", seat)
	}
	if seat.ReservationID != "213550" {
		t.Fatalf("seat reservation id = %q, want 213550", seat.ReservationID)
	}
	if seat.Kind != KindSeat || seat.Building != "航空港一楼" || seat.Room != "航空港一楼A区" || seat.Seat != "H1F-A025" {
		t.Fatalf("seat reservation mapping unexpected: %+v", seat)
	}
	if seat.Status != 1169 || seat.StatusLabel != "审核通过" {
		t.Fatalf("seat reservation status unexpected: %+v", seat)
	}

	study := byUUID["5f2b8e0a4c1d4c0b9d0a3f0b1c2d3e4f"]
	if study.Start != "2026-09-17 09:00:00" || study.End != "2026-09-17 15:00:00" {
		t.Fatalf("string times should pass through unchanged: %+v", study)
	}
	if study.Kind != KindStudy {
		t.Fatalf("study reservation kind = %s, want %s", study.Kind, KindStudy)
	}
}

func TestFlexTimeAcceptsNullStringsAndBothStampUnits(t *testing.T) {
	cases := []struct {
		raw  string
		want string
	}{
		{raw: "null", want: ""},
		{raw: `""`, want: ""},
		{raw: "0", want: ""},
		{raw: `"2026-09-17 09:00:00"`, want: "2026-09-17 09:00:00"},
		{raw: "1789555200000", want: "2026-09-16 18:40:00"},
		{raw: "1789555200", want: "2026-09-16 18:40:00"},
	}
	for _, testCase := range cases {
		t.Run(testCase.raw, func(t *testing.T) {
			var value flexTime
			if err := json.Unmarshal([]byte(testCase.raw), &value); err != nil {
				t.Fatalf("unmarshal %s: %v", testCase.raw, err)
			}
			if string(value) != testCase.want {
				t.Fatalf("flexTime(%s) = %q, want %q", testCase.raw, value, testCase.want)
			}
		})
	}
}
