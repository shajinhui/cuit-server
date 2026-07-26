package coursetable

import (
	"errors"
	"reflect"
	"testing"

	"cuit-server/pkg/jwxt/internal/jwxterr"
)

func TestParseStudentAndProjectIDs(t *testing.T) {
	entry := []byte(`<script>
function searchTable(){
  if(jQuery("#courseTableType").val()=="std"){
    bg.form.addInput(form,"ids","12345");
  }else{
    bg.form.addInput(form,"ids","67890");
  }
}
</script>`)

	studentID, err := ParseStudentID(entry)
	if err != nil {
		t.Fatalf("ParseStudentID returned error: %v", err)
	}
	if studentID != "12345" {
		t.Fatalf("unexpected student ID: %s", studentID)
	}
	tagID, semesterID, err := ParseCalendarContext([]byte(sampleEntryHTML))
	if err != nil {
		t.Fatalf("ParseCalendarContext returned error: %v", err)
	}
	if tagID != "semesterBar123Semester" || semesterID != "1006" {
		t.Fatalf("unexpected calendar context: tag=%s semester=%s", tagID, semesterID)
	}

	projectID, err := ParseProjectID([]byte(" 1\n"))
	if err != nil {
		t.Fatalf("ParseProjectID returned error: %v", err)
	}
	if projectID != "1" {
		t.Fatalf("unexpected project ID: %s", projectID)
	}
}

func TestParseCourseTableKeepsCoursesAndActivities(t *testing.T) {
	table, err := ParseCourseTable([]byte(sampleCourseTableHTML), "1106")
	if err != nil {
		t.Fatalf("ParseCourseTable returned error: %v", err)
	}
	if table.SemesterID != "1106" || table.WeekCount != 6 || table.SectionsPerDay != 12 {
		t.Fatalf("unexpected course table metadata: %+v", table)
	}
	if len(table.Courses) != 2 {
		t.Fatalf("unexpected course count: %d", len(table.Courses))
	}

	first := table.Courses[0]
	if first.LessonID != "101" || first.Code != "COURSE001" || first.Name != "示例课程 实验" {
		t.Fatalf("unexpected course identity: %+v", first)
	}
	if first.Credits != "2.5" || first.Sequence != "COURSE001.001" || first.TeachingClass != "示例班" {
		t.Fatalf("unexpected course metadata: %+v", first)
	}
	if !reflect.DeepEqual(first.Teachers, []string{"教师甲", "教师乙"}) {
		t.Fatalf("unexpected course teachers: %#v", first.Teachers)
	}
	if len(first.Activities) != 1 {
		t.Fatalf("unexpected activity count: %d", len(first.Activities))
	}

	activity := first.Activities[0]
	if activity.Weekday != 1 || activity.StartSection != 1 || activity.EndSection != 2 {
		t.Fatalf("unexpected activity position: %+v", activity)
	}
	if activity.RoomID != "20" || activity.RoomName != "A101" {
		t.Fatalf("unexpected activity room: %+v", activity)
	}
	if !reflect.DeepEqual(activity.TeacherIDs, []string{"11", "12"}) || !reflect.DeepEqual(activity.Teachers, []string{"教师甲", "教师乙"}) {
		t.Fatalf("unexpected activity teachers: %+v", activity)
	}
	if !reflect.DeepEqual(activity.Weeks, []int{1, 2, 3}) {
		t.Fatalf("unexpected teaching weeks: %#v", activity.Weeks)
	}
	if len(table.Courses[1].Activities) != 0 {
		t.Fatalf("unscheduled course should have no activities: %+v", table.Courses[1])
	}
}

func TestParseCourseTableRejectsUnknownActivityCourse(t *testing.T) {
	body := []byte(`
<script>
var unitCount = 12;
var teachers = [{id:11,name:"教师甲",lab:false}];
activity = new TaskActivity(actTeacherId.join(','),actTeacherName.join(','),"900(UNKNOWN.001)","未知课程","20","A101","0111000",null,null,assistantName,"","","","");
index = 0*unitCount+0;
table0.activities[index][table0.activities[index].length]=activity;
table0.marshalTable(2,1,6);
</script>
<table class="gridtable"><thead><tr><th>序号</th><th>课程代码</th><th>课程名称</th><th>学分</th><th>课程序号</th><th>教学班</th><th>教师</th><th>操作</th></tr></thead><tbody></tbody></table>`)

	_, err := ParseCourseTable(body, "1106")
	if !errors.Is(err, jwxterr.ErrCourseTableQueryFailed) {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestParseCourseTableAllowsEmptyBodyRows(t *testing.T) {
	body := []byte(`
<script>
var unitCount = 12;
table0.marshalTable(2,1,19);
</script>
<table class="gridtable">
<thead><tr>
<th>序号</th><th>课程代码</th><th>课程名称</th><th>学分</th><th>课程序号</th><th>教学班</th><th>教师</th><th>操作</th>
</tr></thead>
<tbody><tr></tr></tbody>
</table>`)

	table, err := ParseCourseTable(body, "7")
	if err != nil {
		t.Fatalf("ParseCourseTable returned error for an empty row: %v", err)
	}
	if len(table.Courses) != 0 || table.WeekCount != 19 || table.SectionsPerDay != 12 {
		t.Fatalf("unexpected empty course table: %+v", table)
	}
}

const sampleCourseTableHTML = `
<script>
var table0 = new CourseTable(2026,84);
var unitCount = 12;
var teachers = [{id:11,name:"教师甲",lab:false},{id:12,name:"教师乙",lab:false}];
activity = new TaskActivity(actTeacherId.join(','),actTeacherName.join(','),"900(COURSE001.001)","示例课程,实验","20","A101","011100000",null,null,assistantName,"","","","");
index = 0*unitCount+0;
table0.activities[index][table0.activities[index].length]=activity;
index = 0*unitCount+1;
table0.activities[index][table0.activities[index].length]=activity;
table0.marshalTable(2,1,6);
</script>
<table id="course-list" class="gridtable">
<thead><tr>
<th>序号</th><th>课程代码</th><th>课程名称</th><th>学分</th><th>课程序号</th><th>教学班</th><th>教师</th><th>操作</th>
</tr></thead>
<tbody>
<tr><td>1</td><td>COURSE001</td><td>示例课程 <sup>实验</sup></td><td>2.5</td><td><a href="/eams/courseTableForStd!taskTable.action?lesson.id=101">COURSE001.001</a></td><td>示例班</td><td>教师甲;教师乙</td><td></td></tr>
<tr><td>2</td><td>COURSE002</td><td>暂未排课</td><td>1</td><td><a href="/eams/courseTableForStd!taskTable.action?lesson.id=102">COURSE002.001</a></td><td>示例班</td><td>教师丙</td><td></td></tr>
</tbody>
</table>`
