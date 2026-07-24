package plancompletion

import (
	"errors"
	"testing"

	"cuit-server/pkg/jwxt/internal/jwxterr"
)

func TestParsePlanCompletion(t *testing.T) {
	result, err := ParsePlanCompletion([]byte(samplePlanCompletionHTML))
	if err != nil {
		t.Fatal(err)
	}
	if result.Summary.StudentNo != "test-student" || result.Summary.Name != "测试同学" {
		t.Fatalf("unexpected student summary: %+v", result.Summary)
	}
	if result.Summary.RequiredCredits != "160" || result.Summary.EarnedCredits != "100.5" {
		t.Fatalf("unexpected credit summary: %+v", result.Summary)
	}
	if result.Summary.GPA != "3.20" || result.Summary.AuditResult != "预审通过" {
		t.Fatalf("unexpected audit summary: %+v", result.Summary)
	}
	if len(result.Items) != 2 {
		t.Fatalf("unexpected item count: %d", len(result.Items))
	}
	requirement := result.Items[0]
	if requirement.Kind != PlanCompletionRequirement ||
		requirement.Name != "一 测试必修" ||
		requirement.Status != "缺 2 学分" {
		t.Fatalf("unexpected requirement: %+v", requirement)
	}
	course := result.Items[1]
	if course.Kind != PlanCompletionCourse ||
		course.CourseCode != "TEST001" ||
		course.Score != "71 56" ||
		course.Status != "是" {
		t.Fatalf("unexpected course: %+v", course)
	}
}

func TestParsePlanCompletionRejectsUnexpectedDetailRow(t *testing.T) {
	body := []byte(`
<table class="infoTable">
  <tr><td class="title">学号：</td><td>test-student</td><td class="title">姓名：</td><td>测试同学</td></tr>
  <tr><td class="title">要求学分/实修学分：</td><td>10 / 5</td></tr>
</table>
<table class="formTable">
  <tr><td>序号</td><td>课程序号</td><td>课程名称</td><td>要求学分</td><td>实修学分</td><td>成绩</td><td>是否通过</td><td>备注</td></tr>
  <tr><td>invalid</td></tr>
</table>`)
	_, err := ParsePlanCompletion(body)
	if !errors.Is(err, jwxterr.ErrPlanCompletionQueryFailed) {
		t.Fatalf("expected plan completion query error, got %v", err)
	}
}

const samplePlanCompletionHTML = `
<table class="infoTable">
  <tr>
    <td class="title">学号：</td><td>test-student</td>
    <td class="title">姓名：</td><td>测试同学</td>
    <td class="title">年级：</td><td>2024</td>
  </tr>
  <tr>
    <td class="title">学历层次：</td><td>本科</td>
    <td class="title">学生类别：</td><td>普通本科生</td>
    <td class="title">院系：</td><td>测试学院</td>
  </tr>
  <tr>
    <td class="title">专业/专业方向：</td><td>测试专业</td>
    <td class="title">要求学分/实修学分：</td><td>160 / 100.5</td>
    <td class="title">GPA：</td><td>3.20</td>
  </tr>
  <tr>
    <td class="title">审核结果：</td><td>预审通过</td>
    <td class="title">审核时间：</td><td>2026-07-23 12:00:00</td>
    <td class="title">审核人：</td><td></td>
  </tr>
  <tr><td class="title">备注：</td><td colspan="5">仅供参考</td></tr>
</table>
<table class="formTable">
  <tr><td>序号</td><td>课程序号</td><td>课程名称</td><td>要求学分</td><td>实修学分</td><td>成绩</td><td>是否通过</td><td>备注</td></tr>
  <tr class="darkColumn">
    <td colspan="3">一 测试必修</td><td>10</td><td>8</td><td></td><td><font>缺 2 学分</font></td><td></td>
  </tr>
  <tr>
    <td>1</td><td>TEST001</td><td>测试课程</td><td>2</td><td>2</td><td>71<br>56</td><td>是</td><td></td>
  </tr>
</table>`
