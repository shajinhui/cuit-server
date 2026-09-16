package library

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

func TestListSeatsMapsAvailabilityAndRule(t *testing.T) {
	date := time.Now().In(shanghaiLocation).Format(dateLayout)
	compactDate := time.Now().In(shanghaiLocation).Format("20060102")
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/reserve" {
			t.Fatalf("unexpected path: %s", request.URL.Path)
		}
		if request.URL.Query().Get("roomIds") != "7" || request.URL.Query().Get("resvDates") != compactDate {
			t.Fatalf("unexpected query: %s", request.URL.RawQuery)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprintf(writer, `{"code":0,"data":[{"devId":18,"devSn":"A-18","devName":"18号座位","labName":"图书馆","roomName":"二楼","devProp":2,"resvInfo":[{"startTime":"%s 09:30:00","endTime":"%s 10:30:00"}],"resvRule":{"ruleId":3,"minResvTime":30,"maxResvTime":360}}]}`, date, date)
	}))
	defer server.Close()
	baseURL, _ := url.Parse(server.URL + "/api/")

	seats, err := ListSeats(context.Background(), resty.New(), baseURL, SeatQuery{
		Kind: KindSeat, RoomID: "7", StartDate: date, EndDate: date,
		StartTime: "09:00", EndTime: "11:00",
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(seats) != 1 || seats[0].ID != "18" || seats[0].Status != "reserved" || seats[0].Rule.MaximumMinutes != 360 {
		t.Fatalf("unexpected seats: %+v", seats)
	}
}

func TestCapabilitiesReadsDirectPublicConfig(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"code":0,"data":{"resvCode":"1","resvmemo":"8","classKindMemoRequired":"8","resvmemolen":"60"}}`))
	}))
	defer server.Close()
	baseURL, _ := url.Parse(server.URL + "/")

	capabilities, err := GetCapabilities(context.Background(), resty.New(), baseURL, "https://example.test/library")
	if err != nil {
		t.Fatal(err)
	}
	if capabilities.CaptchaMode != "image" || !capabilities.MemoRequired || capabilities.MemoMaximumLength != 60 {
		t.Fatalf("unexpected capabilities: %+v", capabilities)
	}
}

func TestEnvelopeCode300BecomesSessionExpired(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"code":300,"message":"登录超时"}`))
	}))
	defer server.Close()
	baseURL, _ := url.Parse(server.URL + "/")

	_, err := ListAreas(context.Background(), resty.New(), baseURL, KindSeat)
	if !errors.Is(err, jwxterr.ErrSessionExpired) || PublicMessage(err) != "登录超时" {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestCaptchaDoesNotTreatExpiredJSONAsAnImage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"code":300,"msg":"请重新登录"}`))
	}))
	defer server.Close()
	baseURL, _ := url.Parse(server.URL + "/")

	_, err := GetCaptcha(context.Background(), resty.New(), baseURL)
	if !errors.Is(err, jwxterr.ErrSessionExpired) || PublicMessage(err) != "请重新登录" {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestStudyBeginTimeUsesOpenTimeAndNeverStartsInThePast(t *testing.T) {
	tomorrow := time.Now().In(shanghaiLocation).AddDate(0, 0, 1).Format(dateLayout)
	if got := studyBeginTime(tomorrow, "08:30"); got != tomorrow+" 08:30:00" {
		t.Fatalf("future study start = %q", got)
	}
	if got := studyBeginTime(tomorrow, ""); got != tomorrow+" 00:00:00" {
		t.Fatalf("study start without open time = %q", got)
	}

	today := time.Now().In(shanghaiLocation).Format(dateLayout)
	begin, err := time.ParseInLocation(dateTimeLayout, studyBeginTime(today, "08:00"), shanghaiLocation)
	if err != nil {
		t.Fatal(err)
	}
	if !begin.After(time.Now().In(shanghaiLocation)) {
		t.Fatalf("same-day study start should be in the future: %s", begin)
	}
}
