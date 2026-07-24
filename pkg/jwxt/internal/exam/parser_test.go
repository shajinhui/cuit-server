package exam

import (
	"errors"
	"testing"

	"cuit-server/pkg/jwxt/internal/jwxterr"
)

const sampleExamHTML = `
<table id="grid42" class="gridtable">
  <thead>
    <tr>
      <th>课程序号</th><th>课程名称</th><th>考试类别</th>
      <th>考试日期</th><th>考试时间</th><th>考试地点</th>
      <th>学分</th><th>考试状态</th><th>备注</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>COURSE001.001</td>
      <td>示例课程 <sup>实验班</sup></td>
      <td>期末考试</td>
      <td>2026-01-10</td>
      <td>09:30~11:30</td>
      <td><a href="/eams/stdExamTable!downloadExamroomSeat.action?examRoom.id=8001">A101</a></td>
      <td>2.5</td>
      <td>正常</td>
      <td>携带证件</td>
    </tr>
    <tr>
      <td>COURSE002.001</td><td>实践课程</td><td>期末考试</td>
      <td>时间未安排</td><td>时间未安排</td><td>地点未安排</td>
      <td>1</td><td>正常</td><td></td>
    </tr>
  </tbody>
</table>`

func TestParseBatches(t *testing.T) {
	body := []byte(`
<form id="semesterForm">
  <select name="examBatch.id">
    <option value="5027">开学补考</option>
    <option value="4926" selected>期末考试</option>
  </select>
</form>`)

	batches, err := ParseBatches(body)
	if err != nil {
		t.Fatal(err)
	}
	if len(batches) != 2 ||
		batches[0].ID != "5027" ||
		batches[0].Name != "开学补考" ||
		batches[1].ID != "4926" ||
		batches[1].Name != "期末考试" {
		t.Fatalf("unexpected batches: %+v", batches)
	}
}

func TestParseBatchesAllowsSemesterWithoutExamBatch(t *testing.T) {
	body := []byte(`
<form id="semesterForm">
  <select name="examBatch.id"></select>
</form>`)
	batches, err := ParseBatches(body)
	if err != nil {
		t.Fatal(err)
	}
	if len(batches) != 0 {
		t.Fatalf("expected no batches, got %+v", batches)
	}
}

func TestParseExams(t *testing.T) {
	exams, err := ParseExams([]byte(sampleExamHTML))
	if err != nil {
		t.Fatal(err)
	}
	if len(exams) != 2 {
		t.Fatalf("unexpected exam count: %d", len(exams))
	}
	first := exams[0]
	if first.CourseSequence != "COURSE001.001" ||
		first.CourseName != "示例课程 实验班" ||
		first.ExamType != "期末考试" ||
		first.ExamDate != "2026-01-10" ||
		first.ExamTime != "09:30~11:30" ||
		first.Location != "A101" ||
		first.ExamRoomID != "8001" ||
		first.Credits != "2.5" ||
		first.Status != "正常" ||
		first.Remark != "携带证件" {
		t.Fatalf("unexpected first exam: %+v", first)
	}
	if exams[1].ExamDate != "时间未安排" ||
		exams[1].ExamTime != "时间未安排" ||
		exams[1].Location != "地点未安排" ||
		exams[1].ExamRoomID != "" {
		t.Fatalf("unexpected unarranged exam: %+v", exams[1])
	}
}

func TestParseExamsAllowsEmptyBatchTable(t *testing.T) {
	exams, err := ParseExams([]byte(`
<table class="gridtable">
  <thead><tr>
    <th>考试日期</th><th>考试地点</th><th>考试状态</th>
  </tr></thead>
  <tbody><tr></tr></tbody>
</table>`))
	if err != nil {
		t.Fatal(err)
	}
	if len(exams) != 0 {
		t.Fatalf("expected no exams, got %+v", exams)
	}
}

func TestParseExamsRejectsUnexpectedColumns(t *testing.T) {
	_, err := ParseExams([]byte(`
<table class="gridtable">
  <thead><tr>
    <th>考试日期</th><th>考试地点</th><th>考试状态</th>
  </tr></thead>
  <tbody><tr><td>only one cell</td></tr></tbody>
</table>`))
	if !errors.Is(err, jwxterr.ErrExamQueryFailed) {
		t.Fatalf("expected exam query error, got %v", err)
	}
}
