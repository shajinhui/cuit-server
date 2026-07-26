package coursetable

import (
	"context"
	"net/url"
	"strconv"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/go-resty/resty/v2"
)

const (
	publicCourseTableEntryPath = "/eams/courseTableSecondForStd.action"
	classroomSearchPath        = "/eams/courseTableSecondForStd!search.action"
	classroomCourseTablePath   = "/eams/courseTableSecondForStd!courseTable.action"
	classroomPageSize          = 100
	classroomBatchSize         = 100
)

var fixedClassroomOptions = ClassroomOptions{
	Campuses: []ClassroomOption{
		{ID: "1", Name: "航空港"},
		{ID: "2", Name: "龙泉"},
		{ID: "22", Name: "芯谷"},
	},
	ClassroomTypes: []ClassroomOption{
		{ID: "1", Name: "普通"},
		{ID: "2", Name: "多媒体"},
		{ID: "3", Name: "精品课程录播"},
		{ID: "4", Name: "语音教室"},
		{ID: "22", Name: "体育场馆"},
		{ID: "122", Name: "智慧教室"},
	},
	Buildings: []ClassroomOption{},
}

// GetClassroomOptions 返回空教室查询页面中的校区、教室类型和指定校区的教学楼。
func GetClassroomOptions(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterID string,
	campusID string,
) (ClassroomOptions, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return ClassroomOptions{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "semester ID is required")
	}
	// 校区和教室类型是学校公共课表的固定枚举，不为每个用户重复请求 EAMS。
	options := ClassroomOptions{
		Campuses:       append([]ClassroomOption(nil), fixedClassroomOptions.Campuses...),
		ClassroomTypes: append([]ClassroomOption(nil), fixedClassroomOptions.ClassroomTypes...),
		Buildings:      []ClassroomOption{},
	}
	if strings.TrimSpace(campusID) == "" {
		return options, nil
	}

	// 页面在校区变化时使用 BUILDINGCASCADE 请求动态取得对应教学楼。
	form := "campusId=" + url.QueryEscape(strings.TrimSpace(campusID)) + "&dataType=BUILDINGCASCADE"
	buildingBody, err := postEncodedForm(
		ctx,
		client,
		resolvePath(baseURL, projectDataPath),
		form,
		publicCourseTableEntryPath,
		"text/plain, */*; q=0.01",
		"classroom-buildings",
	)
	if err != nil {
		return ClassroomOptions{}, err
	}
	buildings, err := ParseBuildingOptions(buildingBody)
	options.Buildings = buildings
	return options, err
}

// GetAvailableClassrooms 查询满足筛选条件且在指定时间段没有排课的教室。
func GetAvailableClassrooms(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	query AvailableClassroomQuery,
) ([]Classroom, error) {
	query.SemesterID = strings.TrimSpace(query.SemesterID)
	query.CampusID = strings.TrimSpace(query.CampusID)
	query.BuildingID = strings.TrimSpace(query.BuildingID)
	query.ClassroomTypeID = strings.TrimSpace(query.ClassroomTypeID)
	if err := validateAvailableClassroomQuery(query); err != nil {
		return nil, err
	}
	if err := setSemesterCookie(client, baseURL, query.SemesterID); err != nil {
		return nil, err
	}

	rooms, err := listClassrooms(ctx, client, baseURL, query)
	if err != nil || len(rooms) == 0 {
		return rooms, err
	}
	occupancies, err := queryRoomOccupancies(ctx, client, baseURL, query.SemesterID, rooms)
	if err != nil {
		return nil, err
	}
	return filterAvailableClassrooms(rooms, occupancies, query), nil
}

// GetClassroomSchedule 查询指定学期和校区的全部教室及其整学期占用时间。
func GetClassroomSchedule(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterID string,
	campusID string,
) (ClassroomSchedule, error) {
	semesterID = strings.TrimSpace(semesterID)
	campusID = strings.TrimSpace(campusID)
	if semesterID == "" {
		return ClassroomSchedule{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "semester ID is required")
	}
	if campusID == "" {
		return ClassroomSchedule{}, jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "campus ID is required")
	}
	if err := setSemesterCookie(client, baseURL, semesterID); err != nil {
		return ClassroomSchedule{}, err
	}

	// 快照查询只按学期和校区取数，教学楼、类型、容量和具体上课时间均由前端基于本地快照筛选。
	rooms, err := listClassrooms(ctx, client, baseURL, AvailableClassroomQuery{
		SemesterID: semesterID,
		CampusID:   campusID,
	})
	if err != nil {
		return ClassroomSchedule{}, err
	}
	schedule := ClassroomSchedule{
		SemesterID: semesterID,
		CampusID:   campusID,
		Rooms:      make([]ClassroomScheduleRoom, 0, len(rooms)),
	}
	if len(rooms) == 0 {
		return schedule, nil
	}

	occupancies, err := queryRoomOccupancies(ctx, client, baseURL, semesterID, rooms)
	if err != nil {
		return ClassroomSchedule{}, err
	}
	for index, room := range rooms {
		periods := make([]ClassroomOccupancy, 0, len(occupancies[index]))
		for _, period := range occupancies[index] {
			periods = append(periods, ClassroomOccupancy{
				Weekday:      period.weekday,
				StartSection: period.startSection,
				EndSection:   period.endSection,
				Weeks:        append([]int(nil), period.weeks...),
			})
		}
		schedule.Rooms = append(schedule.Rooms, ClassroomScheduleRoom{
			Classroom:   room,
			Occupancies: periods,
		})
	}
	return schedule, nil
}

func validateAvailableClassroomQuery(query AvailableClassroomQuery) error {
	if strings.TrimSpace(query.SemesterID) == "" {
		return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "semester ID is required")
	}
	if query.Week < 1 || query.Week > 53 {
		return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "week must be between 1 and 53")
	}
	if query.Weekday < 1 || query.Weekday > 7 {
		return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "weekday must be between 1 and 7")
	}
	if len(query.Sections) == 0 {
		return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "at least one section is required")
	}
	for _, section := range query.Sections {
		if section < 1 || section > 12 {
			return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "section must be between 1 and 12")
		}
	}
	if query.MinCapacity < 0 {
		return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, "minimum capacity cannot be negative")
	}
	return nil
}

func listClassrooms(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	query AvailableClassroomQuery,
) ([]Classroom, error) {
	// 浏览器会先进入公共课表页，再由页面内的表格组件调用 search.action。
	// 入口请求会在 EAMS 会话中建立后续教室搜索所需的页面上下文。
	if _, err := getEntry(ctx, client, resolvePath(baseURL, publicCourseTableEntryPath)); err != nil {
		return nil, err
	}

	firstBody, err := queryClassroomPage(ctx, client, baseURL, query, 1)
	if err != nil {
		return nil, err
	}
	rooms, total, err := ParseClassroomPage(firstBody)
	if err != nil {
		return nil, err
	}

	pageCount := (total + classroomPageSize - 1) / classroomPageSize
	for pageNo := 2; pageNo <= pageCount; pageNo++ {
		body, err := queryClassroomPage(ctx, client, baseURL, query, pageNo)
		if err != nil {
			return nil, err
		}
		pageRooms, _, err := ParseClassroomPage(body)
		if err != nil {
			return nil, err
		}
		rooms = append(rooms, pageRooms...)
	}

	if query.MinCapacity == 0 {
		return rooms, nil
	}
	filtered := make([]Classroom, 0, len(rooms))
	for _, room := range rooms {
		if room.Capacity >= query.MinCapacity {
			filtered = append(filtered, room)
		}
	}
	return filtered, nil
}

func queryClassroomPage(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	query AvailableClassroomQuery,
	pageNo int,
) ([]byte, error) {
	targetURL := resolvePath(baseURL, classroomSearchPath)
	params := url.Values{
		"semester.id":     {query.SemesterID},
		"courseTableType": {"room"},
		"pageNo":          {strconv.Itoa(pageNo)},
		"pageSize":        {strconv.Itoa(classroomPageSize)},
	}
	if query.CampusID != "" {
		params.Set("classroom.campus.id", query.CampusID)
	}
	if query.BuildingID != "" {
		params.Set("classroom.building.id", query.BuildingID)
	}
	if query.ClassroomTypeID != "" {
		params.Set("classroom.type.id", query.ClassroomTypeID)
	}
	targetURL.RawQuery = params.Encode()

	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html, */*; q=0.01").
		SetHeader("X-Requested-With", "XMLHttpRequest").
		SetHeader("Referer", resolvePath(baseURL, publicCourseTableEntryPath).String()).
		Get(targetURL.String())
	return responseBody(resp, err, targetURL, "classroom-search")
}

func queryRoomOccupancies(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterID string,
	rooms []Classroom,
) ([][]occupiedPeriod, error) {
	occupancies := make([][]occupiedPeriod, 0, len(rooms))
	// 真实页面已确认一次请求100间教室时，会按 table0 至 table99 返回对应课表。
	for start := 0; start < len(rooms); start += classroomBatchSize {
		end := min(start+classroomBatchSize, len(rooms))
		batch, err := queryRoomOccupancyBatch(ctx, client, baseURL, semesterID, rooms[start:end])
		if err != nil {
			return nil, err
		}
		occupancies = append(occupancies, batch...)
	}
	return occupancies, nil
}

func queryRoomOccupancyBatch(
	ctx context.Context,
	client *resty.Client,
	baseURL *url.URL,
	semesterID string,
	rooms []Classroom,
) ([][]occupiedPeriod, error) {
	roomIDs := make([]string, len(rooms))
	for index, room := range rooms {
		roomIDs[index] = room.ID
	}

	targetURL := resolvePath(baseURL, classroomCourseTablePath)
	targetURL.RawQuery = url.Values{
		"setting.kind":        {"room"},
		"ids":                 {strings.Join(roomIDs, ",")},
		"semester.id":         {semesterID},
		"setting.forSemester": {"1"},
	}.Encode()
	resp, err := client.R().
		SetContext(ctx).
		SetHeader("Accept", "text/html, */*; q=0.01").
		SetHeader("Referer", resolvePath(baseURL, classroomSearchPath).String()).
		Get(targetURL.String())
	body, err := responseBody(resp, err, targetURL, "classroom-course-table")
	if err != nil {
		return nil, err
	}
	return ParseRoomOccupancies(body, rooms)
}

func filterAvailableClassrooms(
	rooms []Classroom,
	occupancies [][]occupiedPeriod,
	query AvailableClassroomQuery,
) []Classroom {
	available := make([]Classroom, 0, len(rooms))
	for index, room := range rooms {
		if !isRoomOccupied(occupancies[index], query) {
			available = append(available, room)
		}
	}
	return available
}

func isRoomOccupied(periods []occupiedPeriod, query AvailableClassroomQuery) bool {
	for _, period := range periods {
		if period.weekday != query.Weekday || !containsInt(period.weeks, query.Week) {
			continue
		}
		for _, section := range query.Sections {
			if section >= period.startSection && section <= period.endSection {
				return true
			}
		}
	}
	return false
}

func containsInt(values []int, target int) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
