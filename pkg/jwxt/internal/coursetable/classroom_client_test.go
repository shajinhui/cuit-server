package coursetable

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"testing"
)

func TestGetClassroomOptionsMatchesEAMSProtocol(t *testing.T) {
	buildingRequests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case projectDataPath:
			buildingRequests++
			assertFormHeaders(t, r)
			rawBody, err := io.ReadAll(r.Body)
			if err != nil {
				t.Fatal(err)
			}
			r.Body = io.NopCloser(bytes.NewReader(rawBody))
			if string(rawBody) != "campusId=1&dataType=BUILDINGCASCADE" {
				t.Fatalf("unexpected building request: %q", rawBody)
			}
			_, _ = w.Write([]byte(`<option value="1">航空港第一教学楼</option><option value="2">航空港第二教学楼</option>`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	options, err := GetClassroomOptions(context.Background(), newTestClient(t), baseURL, "905", "1")
	if err != nil {
		t.Fatalf("GetClassroomOptions returned error: %v", err)
	}
	if buildingRequests != 1 {
		t.Fatalf("unexpected building request count: %d", buildingRequests)
	}
	if len(options.Campuses) != 3 || len(options.ClassroomTypes) != 6 || len(options.Buildings) != 2 {
		t.Fatalf("unexpected classroom options: %+v", options)
	}
}

func TestGetClassroomOptionsDoesNotRequestFixedOptions(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		requests++
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	options, err := GetClassroomOptions(context.Background(), newTestClient(t), baseURL, "905", "")
	if err != nil {
		t.Fatalf("GetClassroomOptions returned error: %v", err)
	}
	if requests != 0 {
		t.Fatalf("fixed classroom options must not request EAMS: %d", requests)
	}
	if options.Campuses[2] != (ClassroomOption{ID: "22", Name: "芯谷"}) {
		t.Fatalf("unexpected fixed campuses: %+v", options.Campuses)
	}
}

func TestGetAvailableClassroomsMatchesEAMSProtocol(t *testing.T) {
	searchRequests := 0
	entryLoaded := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case publicCourseTableEntryPath:
			entryLoaded = true
			_, _ = w.Write([]byte(`<html><body>公共课表</body></html>`))
		case classroomSearchPath:
			if !entryLoaded {
				t.Fatal("classroom entry must be loaded before search")
			}
			searchRequests++
			assertClassroomSearchRequest(t, r)
			pageNo, _ := strconv.Atoi(r.URL.Query().Get("pageNo"))
			if pageNo == 1 {
				_, _ = w.Write([]byte(classroomPageFixture(1, 101, classroomRow67)))
				return
			}
			_, _ = w.Write([]byte(classroomPageFixture(2, 101, classroomRow68)))
		case classroomCourseTablePath:
			assertRoomCourseTableRequest(t, r)
			_, _ = w.Write([]byte(sampleRoomOccupancyHTML))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	rooms, err := GetAvailableClassrooms(context.Background(), newTestClient(t), baseURL, AvailableClassroomQuery{
		SemesterID:      "905",
		Week:            1,
		Weekday:         1,
		Sections:        []int{1, 2},
		CampusID:        "1",
		BuildingID:      "2",
		ClassroomTypeID: "2",
	})
	if err != nil {
		t.Fatalf("GetAvailableClassrooms returned error: %v", err)
	}
	if searchRequests != 2 {
		t.Fatalf("unexpected classroom search request count: %d", searchRequests)
	}
	if len(rooms) != 1 || rooms[0].ID != "68" {
		t.Fatalf("unexpected available classrooms: %+v", rooms)
	}
}

func TestGetClassroomScheduleReturnsWholeCampusSnapshot(t *testing.T) {
	entryLoaded := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case publicCourseTableEntryPath:
			entryLoaded = true
			_, _ = w.Write([]byte(`<html><body>公共课表</body></html>`))
		case classroomSearchPath:
			if !entryLoaded {
				t.Fatal("classroom entry must be loaded before search")
			}
			query := r.URL.Query()
			if query.Get("semester.id") != "905" || query.Get("classroom.campus.id") != "1" {
				t.Fatalf("unexpected snapshot classroom query: %s", r.URL.RawQuery)
			}
			if query.Has("classroom.building.id") || query.Has("classroom.type.id") {
				t.Fatalf("snapshot query must not narrow classroom filters: %s", r.URL.RawQuery)
			}
			_, _ = w.Write([]byte(sampleClassroomPageHTML))
		case classroomCourseTablePath:
			assertRoomCourseTableRequest(t, r)
			_, _ = w.Write([]byte(sampleRoomOccupancyHTML))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	schedule, err := GetClassroomSchedule(context.Background(), newTestClient(t), baseURL, "905", "1")
	if err != nil {
		t.Fatalf("GetClassroomSchedule returned error: %v", err)
	}
	if schedule.SemesterID != "905" || schedule.CampusID != "1" || len(schedule.Rooms) != 2 {
		t.Fatalf("unexpected classroom schedule: %+v", schedule)
	}
	first := schedule.Rooms[0]
	if first.Classroom.ID != "67" || len(first.Occupancies) != 1 {
		t.Fatalf("unexpected first classroom schedule: %+v", first)
	}
	if first.Occupancies[0].Weekday != 1 ||
		first.Occupancies[0].StartSection != 1 ||
		first.Occupancies[0].EndSection != 2 {
		t.Fatalf("unexpected first occupancy: %+v", first.Occupancies[0])
	}
}

func assertClassroomSearchRequest(t *testing.T, r *http.Request) {
	t.Helper()
	if r.Method != http.MethodGet {
		t.Fatalf("unexpected classroom search method: %s", r.Method)
	}
	if r.URL.Query().Get("semester.id") != "905" || r.URL.Query().Get("courseTableType") != "room" {
		t.Fatalf("unexpected classroom search query: %s", r.URL.RawQuery)
	}
	if r.URL.Query().Get("classroom.campus.id") != "1" ||
		r.URL.Query().Get("classroom.building.id") != "2" ||
		r.URL.Query().Get("classroom.type.id") != "2" {
		t.Fatalf("classroom filters are missing: %s", r.URL.RawQuery)
	}
	if r.Header.Get("X-Requested-With") != "XMLHttpRequest" {
		t.Fatalf("unexpected X-Requested-With: %q", r.Header.Get("X-Requested-With"))
	}
}

func assertRoomCourseTableRequest(t *testing.T, r *http.Request) {
	t.Helper()
	query := r.URL.Query()
	if r.Method != http.MethodGet || query.Get("setting.kind") != "room" {
		t.Fatalf("unexpected classroom course table request: method=%s query=%s", r.Method, r.URL.RawQuery)
	}
	if query.Get("ids") != "67,68" || query.Get("semester.id") != "905" || query.Get("setting.forSemester") != "1" {
		t.Fatalf("unexpected classroom course table query: %s", r.URL.RawQuery)
	}
	semesterCookie, err := r.Cookie("semester.id")
	if err != nil || semesterCookie.Value != "905" {
		t.Fatalf("classroom request must carry semester cookie: cookie=%v err=%v", semesterCookie, err)
	}
}

func classroomPageFixture(pageNo int, total int, row string) string {
	return fmt.Sprintf(`
<table class="gridtable">
<thead><tr>
<th>选择全部</th><th>代码</th><th>名称</th><th>教学楼</th><th>校区</th><th>教室设备配置</th><th>容纳听课人数</th>
</tr></thead>
<tbody>%s</tbody>
</table>
<script>page_grid1.pageInfo(%d,100,%d);</script>`, row, pageNo, total)
}

const classroomRow67 = `
<tr>
<td><input type="checkbox" name="classroom.id" value="67"></td>
<td>H2101</td><td>H2101</td><td>航空港第二教学楼</td><td>航空港</td><td>多媒体</td><td>166</td>
</tr>`

const classroomRow68 = `
<tr>
<td><input type="checkbox" name="classroom.id" value="68"></td>
<td>H2102</td><td>H2102</td><td>航空港第二教学楼</td><td>航空港</td><td>智慧教室</td><td>80</td>
</tr>`
