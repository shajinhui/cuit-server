package labms

import (
	"bytes"
	"encoding/json"
	"strconv"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
)

type envelope struct {
	Status  int             `json:"status"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

func (e envelope) check(op string) error {
	if e.Status == 200 {
		return nil
	}
	if e.Status == 401 || strings.EqualFold(strings.TrimSpace(e.Message), "unLogin") {
		return jwxterr.WithMessage(jwxterr.ErrSessionExpired, op+": LABMS session expired")
	}
	return jwxterr.WithMessage(jwxterr.ErrCourseTableQueryFailed, op+": LABMS request failed")
}

type userInfo struct {
	UserCode string `json:"userCode"`
}

type semester struct {
	ID           flexString `json:"id"`
	SemesterName string     `json:"semesterName"`
}

type scheduleRequest struct {
	StudentIDs  []string `json:"studentIds"`
	TeacherIDs  []string `json:"teacherIds"`
	LabIDs      []string `json:"labIds"`
	ClassIDs    []string `json:"classIds"`
	CourseNo    *string  `json:"courseNo"`
	Status      int      `json:"status"`
	Semester    string   `json:"semester"`
	Week        *int     `json:"week"`
	ShowMode    string   `json:"showMode"`
	ToBeDeleted int      `json:"toBeDeleted"`
}

type ScheduleItem struct {
	ID          flexString `json:"id"`
	CourseID    flexString `json:"courseId"`
	TaskID      flexString `json:"taskId"`
	CourseNo    string     `json:"courseNo"`
	CourseName  string     `json:"courseName"`
	ProjectType string     `json:"projectType"`
	ProjectName string     `json:"projectName"`
	Location    string     `json:"location"`
	TeacherName string     `json:"teacherName"`
	ClassName   string     `json:"className"`
	Weekday     flexInt    `json:"weekDay"`
	Sections    intList    `json:"sections"`
	Weeks       intList    `json:"weeks"`
	Week        flexInt    `json:"week"`
	StartTime   string     `json:"startTime"`
	EndTime     string     `json:"endTime"`
}

type flexString string

func (s *flexString) UnmarshalJSON(data []byte) error {
	if bytes.Equal(data, []byte("null")) {
		*s = ""
		return nil
	}
	var text string
	if err := json.Unmarshal(data, &text); err == nil {
		*s = flexString(text)
		return nil
	}
	var number json.Number
	if err := json.Unmarshal(data, &number); err != nil {
		return err
	}
	*s = flexString(number.String())
	return nil
}

type flexInt int

func (i *flexInt) UnmarshalJSON(data []byte) error {
	if bytes.Equal(data, []byte("null")) || bytes.Equal(data, []byte(`""`)) {
		*i = 0
		return nil
	}
	var number int
	if err := json.Unmarshal(data, &number); err == nil {
		*i = flexInt(number)
		return nil
	}
	var text string
	if err := json.Unmarshal(data, &text); err != nil {
		return err
	}
	parsed, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return err
	}
	*i = flexInt(parsed)
	return nil
}

type intList []int

func (list *intList) UnmarshalJSON(data []byte) error {
	if bytes.Equal(data, []byte("null")) || bytes.Equal(data, []byte(`""`)) {
		*list = nil
		return nil
	}
	var numbers []flexInt
	if err := json.Unmarshal(data, &numbers); err == nil {
		result := make([]int, 0, len(numbers))
		for _, number := range numbers {
			result = append(result, int(number))
		}
		*list = result
		return nil
	}
	var text string
	if err := json.Unmarshal(data, &text); err != nil {
		return err
	}
	parts := strings.FieldsFunc(text, func(r rune) bool {
		return r == ',' || r == '，' || r == '、' || r == ';' || r == '；'
	})
	result := make([]int, 0, len(parts))
	for _, part := range parts {
		value, err := strconv.Atoi(strings.TrimSpace(part))
		if err != nil {
			return err
		}
		result = append(result, value)
	}
	*list = result
	return nil
}

func decodeScheduleItems(data json.RawMessage) ([]ScheduleItem, error) {
	var items []ScheduleItem
	if err := json.Unmarshal(data, &items); err == nil {
		return items, nil
	}
	var wrapped struct {
		Results []ScheduleItem `json:"results"`
		List    []ScheduleItem `json:"list"`
	}
	if err := json.Unmarshal(data, &wrapped); err != nil {
		return nil, err
	}
	if wrapped.Results != nil {
		return wrapped.Results, nil
	}
	return wrapped.List, nil
}
