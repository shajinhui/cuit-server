package profile

import (
	"errors"
	"testing"

	"cuit-server/pkg/jwxt/internal/jwxterr"
)

func TestParseStudentProfileMapsStudentRecordFields(t *testing.T) {
	body := []byte(`
<table class="infoTable">
  <tr><td class="title">证件号码：</td><td>must-not-be-read</td></tr>
</table>
<table id="studentInfoTb" class="infoTable">
  <tr><td class="darkColumn" colspan="5">学籍信息</td></tr>
  <tr>
    <td class="title">学号：</td><td>test-student</td>
    <td class="title">姓名：</td><td>测试同学</td>
    <td rowspan="5"><img alt="测试同学"></td>
  </tr>
  <tr>
    <td class="title">英文名：</td><td>Test Student</td>
    <td class="title">性别：</td><td>男</td>
  </tr>
  <tr>
    <td class="title">年级：</td><td>2024</td>
    <td class="title">学制：</td><td>4</td>
  </tr>
  <tr>
    <td class="title">项目：</td><td>本科</td>
    <td class="title">学历层次：</td><td>本科</td>
  </tr>
  <tr>
    <td class="title">学生类别：</td><td>普通本科生</td>
    <td class="title">院系：</td><td>测试学院</td>
  </tr>
  <tr>
    <td class="title">专业：</td><td>测试专业</td>
    <td class="title">方向：</td><td></td>
  </tr>
  <tr>
    <td class="title">入校时间：</td><td>2024-08-31</td>
    <td class="title">预毕业时间：</td><td>2028-06-30</td>
  </tr>
  <tr>
    <td class="title">行政管理院系：</td><td>测试学院</td>
    <td class="title">学习形式：</td><td>普通全日制</td>
  </tr>
  <tr>
    <td class="title">所属校区：</td><td>测试校区</td>
    <td class="title">所属班级：</td><td>测试班</td>
  </tr>
  <tr>
    <td class="title">培养层次：</td><td>本科</td>
    <td class="title">辅导员：</td><td>测试老师</td>
  </tr>
  <tr>
    <td class="title">学籍生效日期：</td><td>2024-08-31</td>
    <td class="title">学籍状态：</td><td>注册学籍</td>
  </tr>
  <tr><td class="title">备注：</td><td colspan="3"> / 理工 / </td></tr>
</table>`)

	profile, err := ParseStudentProfile(body)
	if err != nil {
		t.Fatal(err)
	}
	if profile.StudentNo != "test-student" || profile.Name != "测试同学" {
		t.Fatalf("unexpected identity: %+v", profile)
	}
	if profile.EnglishName != "Test Student" || profile.Gender != "男" {
		t.Fatalf("unexpected basic fields: %+v", profile)
	}
	if profile.College != "测试学院" || profile.Major != "测试专业" || profile.Grade != "2024" {
		t.Fatalf("unexpected academic identity: %+v", profile)
	}
	if profile.Direction != "" || profile.ClassName != "测试班" || profile.StudentStatus != "注册学籍" {
		t.Fatalf("unexpected enrollment fields: %+v", profile)
	}
	if profile.ExpectedGraduationDate != "2028-06-30" || profile.StudyMode != "普通全日制" {
		t.Fatalf("unexpected study fields: %+v", profile)
	}
	if profile.Remark != "/ 理工 /" {
		t.Fatalf("unexpected remark: %q", profile.Remark)
	}
}

func TestParseStudentProfileRequiresInfoTable(t *testing.T) {
	_, err := ParseStudentProfile([]byte(`<html><body>登录页面</body></html>`))
	if !errors.Is(err, jwxterr.ErrProfileQueryFailed) {
		t.Fatalf("expected profile query error, got %v", err)
	}
}
