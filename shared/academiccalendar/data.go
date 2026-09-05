// Package academiccalendar 保存按学校公开校历核实的教学周配置，供 Go 和 Web 共用。
package academiccalendar

import (
	_ "embed"
	"encoding/json"
)

// 每个日期是校历中标为“第一周”的周一，不一定是学生报到日或正式上课日。
// Web 构建直接导入同一个 JSON；Go 将其嵌入二进制，部署时无需额外复制配置文件。
//
//go:embed calendars.json
var calendarJSON []byte

type Semester struct {
	SchoolYear      string `json:"schoolYear"`
	Term            string `json:"term"`
	FirstWeekMonday string `json:"firstWeekMonday"`
	WeekCount       int    `json:"weekCount"`
	Source          string `json:"source"`
}

func List() ([]Semester, error) {
	var semesters []Semester
	err := json.Unmarshal(calendarJSON, &semesters)
	return semesters, err
}
