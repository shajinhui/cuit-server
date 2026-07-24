package coursetable

// CourseTable 保存一个学期的课程目录和具体上课安排。
type CourseTable struct {
	SemesterID string
	// WeekCount 来自页面 marshalTable 的结束周，表示该学期课表覆盖的最大教学周。
	WeekCount int
	// SectionsPerDay 来自页面 unitCount，当前真实响应为每天12节。
	SectionsPerDay int
	Courses        []Course
}

// Course 对应课表页面下方“课程列表”中的一行。
type Course struct {
	LessonID      string
	Code          string
	Name          string
	Credits       string
	Sequence      string
	TeachingClass string
	Teachers      []string
	Activities    []CourseActivity
}

// CourseActivity 对应课程在某一天、某组连续节次和某些教学周内的一次上课安排。
type CourseActivity struct {
	TeacherIDs   []string
	Teachers     []string
	RoomID       string
	RoomName     string
	Weekday      int   // 1至7分别表示周一至周日。
	StartSection int   // 从1开始，包含该节。
	EndSection   int   // 从1开始，包含该节。
	Weeks        []int // 保存确切教学周，能够直接表达连续周、单双周和不规则周次。
}

// AvailableClassroomQuery 指定需要查询的教学周、星期、节次和教室筛选条件。
type AvailableClassroomQuery struct {
	SemesterID      string
	Week            int
	Weekday         int
	Sections        []int
	CampusID        string
	BuildingID      string
	ClassroomTypeID string
	MinCapacity     int
}

// Classroom 保存 EAMS 公共课表页面返回的教室基本信息。
type Classroom struct {
	ID       string
	Code     string
	Name     string
	Building string
	Campus   string
	Type     string
	Capacity int
}

// ClassroomOccupancy 保存一间教室在一个学期内的一段占用时间。
type ClassroomOccupancy struct {
	Weekday      int
	StartSection int
	EndSection   int
	Weeks        []int
}

// ClassroomScheduleRoom 将教室基本信息和该学期的全部占用时间放在一起。
type ClassroomScheduleRoom struct {
	Classroom   Classroom
	Occupancies []ClassroomOccupancy
}

// ClassroomSchedule 是指定学期、校区的完整教室占用快照。
type ClassroomSchedule struct {
	SemesterID string
	CampusID   string
	Rooms      []ClassroomScheduleRoom
}

// ClassroomOption 是校区、教室类型和教学楼下拉选项的统一结构。
type ClassroomOption struct {
	ID   string
	Name string
}

// ClassroomOptions 保存空教室查询页面需要的筛选项。
type ClassroomOptions struct {
	Campuses       []ClassroomOption
	ClassroomTypes []ClassroomOption
	Buildings      []ClassroomOption
}
