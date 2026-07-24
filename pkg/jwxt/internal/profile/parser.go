package profile

import (
	"bytes"
	"strings"

	"cuit-server/pkg/jwxt/internal/jwxterr"
	"github.com/PuerkitoBio/goquery"
)

// ParseStudentProfile 只解析“学籍信息”标签页的 studentInfoTb。
// 同页还有“学生基本信息”表，其中可能包含证件号、银行账号等数据，不属于本 SDK 的当前范围。
func ParseStudentProfile(body []byte) (StudentProfile, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(body))
	if err != nil {
		return StudentProfile{}, jwxterr.WithMessage(jwxterr.ErrProfileQueryFailed, "invalid profile response")
	}
	table := doc.Find("#studentInfoTb").First()
	if table.Length() == 0 {
		return StudentProfile{}, jwxterr.WithMessage(jwxterr.ErrProfileQueryFailed, "profile table not found")
	}

	fields := make(map[string]string)
	// 真实页面使用 td.title 表示字段名，字段值位于紧邻的下一个 td。
	table.Find("td.title").Each(func(_ int, label *goquery.Selection) {
		value := label.NextFiltered("td").First()
		if value.Length() == 0 {
			return
		}
		fields[normalizeLabel(label.Text())] = normalizeText(value.Text())
	})

	result := StudentProfile{
		StudentNo:              fields["学号"],
		Name:                   fields["姓名"],
		EnglishName:            fields["英文名"],
		Gender:                 fields["性别"],
		Grade:                  fields["年级"],
		StudyDuration:          fields["学制"],
		Project:                fields["项目"],
		EducationLevel:         fields["学历层次"],
		StudentCategory:        fields["学生类别"],
		College:                fields["院系"],
		Major:                  fields["专业"],
		Direction:              fields["方向"],
		EnrollmentDate:         fields["入校时间"],
		ExpectedGraduationDate: fields["预毕业时间"],
		AdministrativeCollege:  fields["行政管理院系"],
		StudyMode:              fields["学习形式"],
		Campus:                 fields["所属校区"],
		ClassName:              fields["所属班级"],
		TrainingLevel:          fields["培养层次"],
		Counselor:              fields["辅导员"],
		StatusEffectiveDate:    fields["学籍生效日期"],
		StudentStatus:          fields["学籍状态"],
		Remark:                 fields["备注"],
	}
	if result.StudentNo == "" || result.Name == "" {
		return StudentProfile{}, jwxterr.WithMessage(jwxterr.ErrProfileQueryFailed, "student number or name not found")
	}
	return result, nil
}

func normalizeLabel(value string) string {
	value = normalizeText(value)
	value = strings.TrimSuffix(value, ":")
	return strings.TrimSuffix(value, "：")
}

func normalizeText(value string) string {
	return strings.Join(strings.Fields(value), " ")
}
