package exam

// Batch 是指定学期下由 EAMS 提供的考试批次，例如“开学补考”或“期末考试”。
type Batch struct {
	ID   string
	Name string
}

// Exam 对应“我的考试”页面考场表中的一行。
type Exam struct {
	CourseSequence string
	CourseName     string
	ExamType       string
	ExamDate       string
	ExamTime       string
	Location       string
	ExamRoomID     string
	Credits        string
	Status         string
	Remark         string
}
