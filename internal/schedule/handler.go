package schedule

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"cuit-server/internal/academic"
	apiresponse "cuit-server/internal/platform/response"
	"cuit-server/pkg/jwxt"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
)

const sessionCookieName = "campus_session"

// CourseTableService 只描述课表 Handler 所需能力，具体会话恢复仍由现有 JWXT 会话服务负责。
type CourseTableService interface {
	GetCourseTable(ctx context.Context, sessionID string, semesterID string) (jwxt.CourseTable, error)
	GetClassroomOptions(ctx context.Context, sessionID string, semesterID string, campusID string) (jwxt.ClassroomOptions, error)
	GetAvailableClassrooms(ctx context.Context, sessionID string, query jwxt.AvailableClassroomQuery) ([]jwxt.Classroom, error)
	GetClassroomSchedule(ctx context.Context, sessionID string, semesterID string, campusID string) (jwxt.ClassroomSchedule, error)
}

// Handler 提供课表和当前教学周 HTTP 接口，不解析学校页面，也不直接访问数据库。
type Handler struct {
	courseTableService CourseTableService
	currentWeekService CurrentWeekService
}

func NewHandler(courseTableService CourseTableService, currentWeekService CurrentWeekService) *Handler {
	return &Handler{
		courseTableService: courseTableService,
		currentWeekService: currentWeekService,
	}
}

func (h *Handler) Register(server *server.Hertz) {
	server.GET("/api/v1/jwxt/course-table", h.getCourseTable)
	server.GET("/api/v1/jwxt/classroom-options", h.getClassroomOptions)
	server.GET("/api/v1/jwxt/available-classrooms", h.getAvailableClassrooms)
	server.GET("/api/v1/jwxt/classroom-schedule", h.getClassroomSchedule)
	server.GET("/api/v1/schedule/current-week", h.getCurrentWeek)
}

func (h *Handler) getCourseTable(ctx context.Context, c *app.RequestContext) {
	semesterID := strings.TrimSpace(c.Query("semester_id"))
	if semesterID == "" {
		writeError(c, http.StatusBadRequest, 40000, "请选择学期")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	// campus_session 只标识本应用会话；真实 EAMS Cookie 始终保留在后端的独立 JWXT Client 中。
	table, err := h.courseTableService.GetCourseTable(requestCtx, string(c.Cookie(sessionCookieName)), semesterID)
	if err != nil {
		log.Printf("查询课表失败: semester_id=%s: %v", semesterID, err)
		writeServiceError(c, err)
		return
	}
	apiresponse.Success(c, table)
}

func (h *Handler) getClassroomOptions(ctx context.Context, c *app.RequestContext) {
	semesterID := strings.TrimSpace(c.Query("semester_id"))
	campusID := strings.TrimSpace(c.Query("campus_id"))
	if semesterID == "" || (campusID != "" && !isPositiveID(campusID)) {
		writeError(c, http.StatusBadRequest, 40000, "教室筛选参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	options, err := h.courseTableService.GetClassroomOptions(
		requestCtx,
		string(c.Cookie(sessionCookieName)),
		semesterID,
		campusID,
	)
	if err != nil {
		log.Printf("查询教室筛选项失败: semester_id=%s campus_id=%s: %v", semesterID, campusID, err)
		writeClassroomServiceError(c, err)
		return
	}
	apiresponse.Success(c, options)
}

func (h *Handler) getAvailableClassrooms(ctx context.Context, c *app.RequestContext) {
	query, err := parseAvailableClassroomQuery(c)
	if err != nil {
		writeError(c, http.StatusBadRequest, 40000, "空教室查询参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	rooms, err := h.courseTableService.GetAvailableClassrooms(
		requestCtx,
		string(c.Cookie(sessionCookieName)),
		query,
	)
	if err != nil {
		log.Printf(
			"查询空教室失败: semester_id=%s week=%d weekday=%d campus_id=%s: %v",
			query.SemesterID,
			query.Week,
			query.Weekday,
			query.CampusID,
			err,
		)
		writeClassroomServiceError(c, err)
		return
	}
	apiresponse.Success(c, rooms)
}

func (h *Handler) getClassroomSchedule(ctx context.Context, c *app.RequestContext) {
	semesterID := strings.TrimSpace(c.Query("semester_id"))
	campusID := strings.TrimSpace(c.Query("campus_id"))
	if semesterID == "" || !isPositiveID(campusID) {
		writeError(c, http.StatusBadRequest, 40000, "教室课表参数无效")
		return
	}
	requestCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	schedule, err := h.courseTableService.GetClassroomSchedule(
		requestCtx,
		string(c.Cookie(sessionCookieName)),
		semesterID,
		campusID,
	)
	if err != nil {
		log.Printf("查询教室课表失败: semester_id=%s campus_id=%s: %v", semesterID, campusID, err)
		writeClassroomServiceError(c, err)
		return
	}
	apiresponse.Success(c, schedule)
}

func parseAvailableClassroomQuery(c *app.RequestContext) (jwxt.AvailableClassroomQuery, error) {
	query := jwxt.AvailableClassroomQuery{
		SemesterID:      strings.TrimSpace(c.Query("semester_id")),
		CampusID:        strings.TrimSpace(c.Query("campus_id")),
		BuildingID:      strings.TrimSpace(c.Query("building_id")),
		ClassroomTypeID: strings.TrimSpace(c.Query("classroom_type_id")),
	}
	if query.SemesterID == "" || !isPositiveID(query.CampusID) {
		return jwxt.AvailableClassroomQuery{}, academic.ErrInvalidInput
	}
	if query.BuildingID != "" && !isPositiveID(query.BuildingID) {
		return jwxt.AvailableClassroomQuery{}, academic.ErrInvalidInput
	}
	if query.ClassroomTypeID != "" && !isPositiveID(query.ClassroomTypeID) {
		return jwxt.AvailableClassroomQuery{}, academic.ErrInvalidInput
	}

	var err error
	query.Week, err = parseBoundedInt(c.Query("week"), 1, 53)
	if err != nil {
		return jwxt.AvailableClassroomQuery{}, err
	}
	query.Weekday, err = parseBoundedInt(c.Query("weekday"), 1, 7)
	if err != nil {
		return jwxt.AvailableClassroomQuery{}, err
	}
	query.Sections, err = parseSections(c.Query("sections"))
	if err != nil {
		return jwxt.AvailableClassroomQuery{}, err
	}

	minCapacity := strings.TrimSpace(c.Query("min_capacity"))
	if minCapacity != "" {
		query.MinCapacity, err = strconv.Atoi(minCapacity)
		if err != nil || query.MinCapacity < 0 {
			return jwxt.AvailableClassroomQuery{}, academic.ErrInvalidInput
		}
	}
	return query, nil
}

func parseSections(raw string) ([]int, error) {
	parts := strings.Split(raw, ",")
	if len(parts) == 0 || strings.TrimSpace(raw) == "" {
		return nil, academic.ErrInvalidInput
	}
	sections := make([]int, 0, len(parts))
	for _, part := range parts {
		section, err := parseBoundedInt(part, 1, 12)
		if err != nil {
			return nil, err
		}
		sections = append(sections, section)
	}
	return sections, nil
}

func parseBoundedInt(raw string, minimum int, maximum int) (int, error) {
	value, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil || value < minimum || value > maximum {
		return 0, academic.ErrInvalidInput
	}
	return value, nil
}

func isPositiveID(raw string) bool {
	value, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 64)
	return err == nil && value > 0
}

func (h *Handler) getCurrentWeek(ctx context.Context, c *app.RequestContext) {
	requestCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	week, err := h.currentWeekService.GetCurrentWeek(requestCtx)
	if err != nil {
		log.Printf("查询当前教学周失败: %v", err)
		writeError(c, http.StatusBadGateway, 50204, "当前教学周查询失败，请稍后重试")
		return
	}
	apiresponse.Success(c, week)
}

func writeClassroomServiceError(c *app.RequestContext, err error) {
	switch {
	case errors.Is(err, academic.ErrInvalidInput):
		writeError(c, http.StatusBadRequest, 40000, "空教室查询参数无效")
	case errors.Is(err, academic.ErrUnauthenticated), errors.Is(err, jwxt.ErrSessionExpired):
		writeError(c, http.StatusUnauthorized, 40101, "教务登录已失效，请重新登录")
	case errors.Is(err, jwxt.ErrRemoteUnavailable):
		writeError(c, http.StatusBadGateway, 50201, "教务系统暂时无法访问")
	case errors.Is(err, jwxt.ErrCourseTableQueryFailed):
		writeError(c, http.StatusBadGateway, 50207, "教室信息查询失败，请稍后重试")
	default:
		writeError(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
	}
}

func writeError(c *app.RequestContext, status int, code int, message string) {
	apiresponse.Error(c, status, code, message)
}

func writeServiceError(c *app.RequestContext, err error) {
	switch {
	case errors.Is(err, academic.ErrInvalidInput):
		writeError(c, http.StatusBadRequest, 40000, "请选择学期")
	case errors.Is(err, academic.ErrUnauthenticated), errors.Is(err, jwxt.ErrSessionExpired):
		writeError(c, http.StatusUnauthorized, 40101, "教务登录已失效，请重新登录")
	case errors.Is(err, jwxt.ErrRemoteUnavailable):
		writeError(c, http.StatusBadGateway, 50201, "教务系统暂时无法访问")
	case errors.Is(err, jwxt.ErrCourseTableQueryFailed):
		writeError(c, http.StatusBadGateway, 50203, "课表查询失败，请稍后重试")
	default:
		writeError(c, http.StatusInternalServerError, 50000, "服务暂时不可用")
	}
}
