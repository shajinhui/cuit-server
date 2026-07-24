package grade

type Semester struct {
	ID         string
	SchoolYear string
	Term       string
	Current    bool
}

type Grade struct {
	SchoolYearTerm string
	CourseCode     string
	CourseSequence string
	CourseName     string
	CourseCategory string
	Credits        string
	UsualScore     string
	FinalExamScore string
	OverallScore   string
	FinalScore     string
	GradePoint     string
}
