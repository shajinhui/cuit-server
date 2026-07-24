package profile

// StudentProfile 对应 EAMS“学籍信息”页中的学籍信息表。
// 字段保持字符串形式，避免 SDK 擅自解释学校系统中的日期、学制和状态值。
type StudentProfile struct {
	StudentNo              string
	Name                   string
	EnglishName            string
	Gender                 string
	Grade                  string
	StudyDuration          string
	Project                string
	EducationLevel         string
	StudentCategory        string
	College                string
	Major                  string
	Direction              string
	EnrollmentDate         string
	ExpectedGraduationDate string
	AdministrativeCollege  string
	StudyMode              string
	Campus                 string
	ClassName              string
	TrainingLevel          string
	Counselor              string
	StatusEffectiveDate    string
	StudentStatus          string
	Remark                 string
}
