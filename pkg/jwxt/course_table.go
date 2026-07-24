package jwxt

import (
	"context"
	"errors"
	"net/url"
	"strings"

	courseflow "cuit-server/pkg/jwxt/internal/coursetable"
	"cuit-server/pkg/jwxt/internal/jwxterr"
)

type CourseTable = courseflow.CourseTable

type Course = courseflow.Course

type CourseActivity = courseflow.CourseActivity

type AvailableClassroomQuery = courseflow.AvailableClassroomQuery

type Classroom = courseflow.Classroom

type ClassroomOccupancy = courseflow.ClassroomOccupancy

type ClassroomScheduleRoom = courseflow.ClassroomScheduleRoom

type ClassroomSchedule = courseflow.ClassroomSchedule

type ClassroomOption = courseflow.ClassroomOption

type ClassroomOptions = courseflow.ClassroomOptions

// GetCourseTable 查询指定学期的完整个人课表，学生内部 ID 和项目 ID 均由当前 EAMS 会话动态取得。
func (c *Client) GetCourseTable(ctx context.Context, semesterID string) (CourseTable, error) {
	semesterID = strings.TrimSpace(semesterID)
	if semesterID == "" {
		return CourseTable{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "semester ID is required")
	}
	if !c.loggedIn {
		return CourseTable{}, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return CourseTable{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "invalid EAMS base URL")
	}

	table, err := courseflow.GetCourseTable(ctx, c.resty, baseURL, semesterID)
	// 后续业务层可以在收到 Session 失效后重新登录；SDK 不能继续把当前 Client 当作已登录会话。
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return table, err
}

// GetAvailableClassrooms 查询指定教学周、星期和节次内没有排课的教室。
func (c *Client) GetAvailableClassrooms(
	ctx context.Context,
	query AvailableClassroomQuery,
) ([]Classroom, error) {
	if !c.loggedIn {
		return nil, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return nil, jwxterr.WithMessage(ErrCourseTableQueryFailed, "invalid EAMS base URL")
	}

	rooms, err := courseflow.GetAvailableClassrooms(ctx, c.resty, baseURL, query)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return rooms, err
}

// GetClassroomSchedule 查询指定学期和校区的完整教室占用快照。
func (c *Client) GetClassroomSchedule(
	ctx context.Context,
	semesterID string,
	campusID string,
) (ClassroomSchedule, error) {
	if !c.loggedIn {
		return ClassroomSchedule{}, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return ClassroomSchedule{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "invalid EAMS base URL")
	}

	schedule, err := courseflow.GetClassroomSchedule(ctx, c.resty, baseURL, semesterID, campusID)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return schedule, err
}

// GetClassroomOptions 查询校区、教室类型和指定校区的教学楼选项。
func (c *Client) GetClassroomOptions(
	ctx context.Context,
	semesterID string,
	campusID string,
) (ClassroomOptions, error) {
	if !c.loggedIn {
		return ClassroomOptions{}, jwxterr.WithMessage(ErrSessionExpired, "login required")
	}
	baseURL, err := url.Parse(c.cfg.EAMSBaseURL)
	if err != nil || baseURL.Host == "" {
		return ClassroomOptions{}, jwxterr.WithMessage(ErrCourseTableQueryFailed, "invalid EAMS base URL")
	}

	options, err := courseflow.GetClassroomOptions(ctx, c.resty, baseURL, semesterID, campusID)
	if errors.Is(err, ErrSessionExpired) {
		c.loggedIn = false
	}
	return options, err
}
