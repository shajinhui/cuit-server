package coursetable

import (
	"reflect"
	"testing"
)

func TestParseClassroomPage(t *testing.T) {
	rooms, total, err := ParseClassroomPage([]byte(sampleClassroomPageHTML))
	if err != nil {
		t.Fatalf("ParseClassroomPage returned error: %v", err)
	}
	if total != 2 || len(rooms) != 2 {
		t.Fatalf("unexpected classroom page: total=%d rooms=%d", total, len(rooms))
	}
	if rooms[0] != (Classroom{
		ID:       "67",
		Code:     "H2101",
		Name:     "H2101",
		Building: "航空港第二教学楼",
		Campus:   "航空港",
		Type:     "多媒体",
		Capacity: 166,
	}) {
		t.Fatalf("unexpected first classroom: %+v", rooms[0])
	}
	if rooms[1].ID != "68" || rooms[1].Capacity != 80 {
		t.Fatalf("unexpected second classroom: %+v", rooms[1])
	}
}

func TestParseRoomOccupanciesKeepsTableOrderAndWeeks(t *testing.T) {
	occupancies, err := ParseRoomOccupancies([]byte(sampleRoomOccupancyHTML), 2)
	if err != nil {
		t.Fatalf("ParseRoomOccupancies returned error: %v", err)
	}
	if len(occupancies) != 2 || len(occupancies[0]) != 1 || len(occupancies[1]) != 1 {
		t.Fatalf("unexpected occupancy counts: %#v", occupancies)
	}

	first := occupancies[0][0]
	if first.weekday != 1 || first.startSection != 1 || first.endSection != 2 {
		t.Fatalf("unexpected first occupancy position: %+v", first)
	}
	if !reflect.DeepEqual(first.weeks, []int{1, 2}) {
		t.Fatalf("unexpected first occupancy weeks: %#v", first.weeks)
	}

	second := occupancies[1][0]
	if second.weekday != 3 || second.startSection != 3 || second.endSection != 3 {
		t.Fatalf("unexpected second occupancy position: %+v", second)
	}
	if !reflect.DeepEqual(second.weeks, []int{2}) {
		t.Fatalf("unexpected second occupancy weeks: %#v", second.weeks)
	}
}

func TestParseClassroomOptions(t *testing.T) {
	options, err := ParseClassroomOptions([]byte(sampleClassroomOptionsHTML))
	if err != nil {
		t.Fatalf("ParseClassroomOptions returned error: %v", err)
	}
	if len(options.Campuses) != 2 || options.Campuses[0] != (ClassroomOption{ID: "1", Name: "航空港"}) {
		t.Fatalf("unexpected campuses: %+v", options.Campuses)
	}
	if len(options.ClassroomTypes) != 2 || options.ClassroomTypes[1] != (ClassroomOption{ID: "2", Name: "多媒体"}) {
		t.Fatalf("unexpected classroom types: %+v", options.ClassroomTypes)
	}

	buildings, err := ParseBuildingOptions([]byte(`<option value="1">航空港第一教学楼</option><option value="2">航空港第二教学楼</option>`))
	if err != nil {
		t.Fatalf("ParseBuildingOptions returned error: %v", err)
	}
	if len(buildings) != 2 || buildings[1] != (ClassroomOption{ID: "2", Name: "航空港第二教学楼"}) {
		t.Fatalf("unexpected buildings: %+v", buildings)
	}
}

func TestFilterAvailableClassroomsRequiresEverySectionToBeFree(t *testing.T) {
	rooms, _, err := ParseClassroomPage([]byte(sampleClassroomPageHTML))
	if err != nil {
		t.Fatal(err)
	}
	occupancies, err := ParseRoomOccupancies([]byte(sampleRoomOccupancyHTML), 2)
	if err != nil {
		t.Fatal(err)
	}

	available := filterAvailableClassrooms(rooms, occupancies, AvailableClassroomQuery{
		Week:     1,
		Weekday:  1,
		Sections: []int{1, 2},
	})
	if len(available) != 1 || available[0].ID != "68" {
		t.Fatalf("unexpected available classrooms: %+v", available)
	}
}

const sampleClassroomPageHTML = `
<table class="gridtable">
<thead><tr>
<th>选择全部</th><th>代码</th><th>名称</th><th>教学楼</th><th>校区</th><th>教室设备配置</th><th>容纳听课人数</th>
</tr></thead>
<tbody>
<tr>
<td><input type="checkbox" name="classroom.id" value="67"></td>
<td>H2101</td><td>H2101</td><td>航空港第二教学楼</td><td>航空港</td><td>多媒体</td><td>166</td>
</tr>
<tr>
<td><input type="checkbox" name="classroom.id" value="68"></td>
<td>H2102</td><td>H2102</td><td>航空港第二教学楼</td><td>航空港</td><td>智慧教室</td><td>80</td>
</tr>
</tbody>
</table>
<script>page_grid1.pageInfo(1,100,2);</script>`

const sampleClassroomOptionsHTML = `
<select name="classroom.campus.id">
  <option value="">...</option>
  <option value="1">航空港</option>
  <option value="2">龙泉</option>
</select>
<select name="classroom.type.id">
  <option value="">...</option>
  <option value="1">普通</option>
  <option value="2">多媒体</option>
</select>`

const sampleRoomOccupancyHTML = `
<div id="ExportA">
<h2>教室H2101课程安排</h2>
<script>
var table0 = new CourseTable(2025,84);
var unitCount = 12;
activity = new TaskActivity(actTeacherId.join(','),actTeacherName.join(','),"900(COURSE001.001)","示例课程","","","0110000",null,null,assistantName,"","","","");
index = 0*unitCount+0;
table0.activities[index][table0.activities[index].length]=activity;
index = 0*unitCount+1;
table0.activities[index][table0.activities[index].length]=activity;
table0.marshalTable(2,1,6);
</script>
<h2>教室H2102课程安排</h2>
<script>
var table1 = new CourseTable(2025,84);
var unitCount = 12;
activity = new TaskActivity(actTeacherId.join(','),actTeacherName.join(','),"901(COURSE002.001)","另一门课程","","","0010000",null,null,assistantName,"","","","");
index = 2*unitCount+2;
table1.activities[index][table1.activities[index].length]=activity;
table1.marshalTable(2,1,6);
</script>
</div>`
