package upstream

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strconv"
)

func decodeUserInfo(raw json.RawMessage) (UserInfo, error) {
	object, err := objectValue(raw)
	if err != nil {
		return UserInfo{}, err
	}
	oauthRaw, ok := object["oauthToken"]
	if !ok {
		return UserInfo{}, errors.New("oauthToken missing")
	}
	oauth, err := objectValue(oauthRaw)
	if err != nil {
		return UserInfo{}, errors.New("oauthToken is not an object")
	}
	userID, err := integerField(object, "userId")
	if err != nil {
		return UserInfo{}, err
	}
	studentID, err := integerField(object, "studentId")
	if err != nil {
		return UserInfo{}, err
	}
	schoolID, err := integerField(object, "schoolId")
	if err != nil {
		return UserInfo{}, err
	}
	token, err := stringField(oauth, "token")
	if err != nil {
		return UserInfo{}, err
	}
	result := UserInfo{UserID: userID, StudentID: studentID, SchoolID: schoolID}
	result.OAuthToken.Token = token
	return result, nil
}

func decodeSchoolBounds(raw json.RawMessage) ([]SchoolBound, error) {
	var values []json.RawMessage
	if err := json.Unmarshal(raw, &values); err != nil {
		return nil, errors.New("response is not an array")
	}
	result := make([]SchoolBound, 0, len(values))
	for _, value := range values {
		object, err := objectValue(value)
		if err != nil {
			return nil, errors.New("bound item is not an object")
		}
		siteBound, err := stringField(object, "siteBound")
		if err != nil {
			return nil, err
		}
		result = append(result, SchoolBound{SiteBound: siteBound})
	}
	return result, nil
}

func decodeRunStandard(raw json.RawMessage) (RunStandard, error) {
	object, err := objectValue(raw)
	if err != nil {
		return RunStandard{}, err
	}
	semesterYear, ok := rawString(object["semesterYear"])
	if !ok {
		return RunStandard{}, errors.New("semesterYear must be a string")
	}
	result := RunStandard{SemesterYear: semesterYear}
	if err := assignInt(object, "standardId", &result.StandardID); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "schoolId", &result.SchoolID); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyOnceTimeMin", &result.BoyOnceTimeMin); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyOnceTimeMax", &result.BoyOnceTimeMax); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyOnceDistanceMin", &result.BoyOnceDistanceMin); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyOnceDistanceMax", &result.BoyOnceDistanceMax); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyAllRunDistance", &result.BoyAllRunDistance); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyAllRunTime", &result.BoyAllRunTime); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlOnceTimeMin", &result.GirlOnceTimeMin); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlOnceTimeMax", &result.GirlOnceTimeMax); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlOnceDistanceMin", &result.GirlOnceDistanceMin); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlOnceDistanceMax", &result.GirlOnceDistanceMax); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlAllRunDistance", &result.GirlAllRunDistance); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlAllRunTime", &result.GirlAllRunTime); err != nil {
		return RunStandard{}, err
	}
	if err := assignString(object, "firstSemesterDateStart", &result.FirstSemesterStart); err != nil {
		return RunStandard{}, err
	}
	if err := assignString(object, "firstSemesterDateEnd", &result.FirstSemesterEnd); err != nil {
		return RunStandard{}, err
	}
	if err := assignString(object, "secondSemesterDateStart", &result.SecondSemesterStart); err != nil {
		return RunStandard{}, err
	}
	if err := assignString(object, "secondSemesterDateEnd", &result.SecondSemesterEnd); err != nil {
		return RunStandard{}, err
	}
	if err := assignString(object, "instanceSemester", &result.InstanceSemester); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyRunSpeed", &result.BoyRunSpeed); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlRunSpeed", &result.GirlRunSpeed); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyMaxSpeed", &result.BoyMaxSpeed); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "boyMinSpeed", &result.BoyMinSpeed); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlMaxSpeed", &result.GirlMaxSpeed); err != nil {
		return RunStandard{}, err
	}
	if err := assignInt(object, "girlMinSpeed", &result.GirlMinSpeed); err != nil {
		return RunStandard{}, err
	}
	if err := assignString(object, "effectiveRangeType", &result.EffectiveRangeType); err != nil {
		return RunStandard{}, err
	}
	return result, nil
}

func decodeRunInfo(raw json.RawMessage) (RunInfo, error) {
	object, err := objectValue(raw)
	if err != nil {
		return RunInfo{}, err
	}
	result := RunInfo{}
	fields := []struct {
		name string
		out  *int64
	}{
		{"semesterId", &result.SemesterID},
		{"yearSemester", &result.YearSemester},
		{"userId", &result.UserID},
		{"studentId", &result.StudentID},
		{"schoolId", &result.SchoolID},
		{"runCount", &result.RunCount},
		{"runValidCount", &result.RunValidCount},
		{"runDistance", &result.RunDistance},
		{"runValidDistance", &result.RunValidDistance},
		{"runDay", &result.RunDay},
		{"runValidDay", &result.RunValidDay},
		{"runCalorie", &result.RunCalorie},
		{"runValidCalorie", &result.RunValidCalorie},
	}
	for _, field := range fields {
		if err := assignInt(object, field.name, field.out); err != nil {
			return RunInfo{}, err
		}
	}
	if err := assignString(object, "infoStatus", &result.InfoStatus); err != nil {
		return RunInfo{}, err
	}
	if err := assignString(object, "createTime", &result.CreateTime); err != nil {
		return RunInfo{}, err
	}
	return result, nil
}

func decodeSignInTask(raw json.RawMessage) (*SignInTask, error) {
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return nil, nil
	}
	object, err := objectValue(raw)
	if err != nil {
		return nil, err
	}
	result := SignInTask{}
	if result.ActivityID, err = integerLikeField(object, "activityId"); err != nil {
		return nil, err
	}
	if result.Longitude, err = stringLikeField(object, "longitude"); err != nil {
		return nil, err
	}
	if result.Latitude, err = stringLikeField(object, "latitude"); err != nil {
		return nil, err
	}
	if result.SignBackStatus, err = stringLikeField(object, "signBackStatus"); err != nil {
		return nil, err
	}
	if result.SignInStatus, err = stringLikeField(object, "signInStatus"); err != nil {
		return nil, err
	}
	if result.SignStatus, err = stringLikeField(object, "signStatus"); err != nil {
		return nil, err
	}
	if result.ActivityName, err = optionalStringField(object, "activityName"); err != nil {
		return nil, err
	}
	if result.ActivityType, err = optionalStringField(object, "activityType"); err != nil {
		return nil, err
	}
	if result.Address, err = optionalStringField(object, "address"); err != nil {
		return nil, err
	}
	if result.ContinueTime, err = optionalIntegerField(object, "continueTime"); err != nil {
		return nil, err
	}
	if result.StartTime, err = optionalStringField(object, "startTime"); err != nil {
		return nil, err
	}
	if result.EndTime, err = optionalStringField(object, "endTime"); err != nil {
		return nil, err
	}
	if result.SignBackLimitTime, err = optionalIntegerField(object, "signBackLimitTime"); err != nil {
		return nil, err
	}
	if result.SignInTime, err = optionalStringField(object, "signInTime"); err != nil {
		return nil, err
	}
	return &result, nil
}

func decodeClubActivities(raw json.RawMessage) ([]ClubInfo, error) {
	values, err := listValue(raw)
	if err != nil {
		return nil, err
	}
	result := make([]ClubInfo, 0, len(values))
	for _, value := range values {
		activity, err := decodeClubInfo(value)
		if err != nil {
			return nil, err
		}
		result = append(result, activity)
	}
	return result, nil
}

func decodeClubInfo(raw json.RawMessage) (ClubInfo, error) {
	object, err := objectValue(raw)
	if err != nil {
		return ClubInfo{}, err
	}
	result := ClubInfo{}
	if result.ClubActivityID, err = integerLikeField(object, "clubActivityId"); err != nil {
		return ClubInfo{}, err
	}
	if result.ActivityName, err = stringField(object, "activityName"); err != nil {
		return ClubInfo{}, err
	}
	if result.SignInStudent, err = integerField(object, "signInStudent"); err != nil {
		return ClubInfo{}, err
	}
	if result.MaxStudent, err = integerField(object, "maxStudent"); err != nil {
		return ClubInfo{}, err
	}
	if result.CancelSign, err = stringField(object, "cancelSign"); err != nil {
		return ClubInfo{}, err
	}
	if result.StartTime, err = stringField(object, "startTime"); err != nil {
		return ClubInfo{}, err
	}
	if result.EndTime, err = stringField(object, "endTime"); err != nil {
		return ClubInfo{}, err
	}
	if result.AddressDetail, err = optionalStringField(object, "addressDetail"); err != nil {
		return ClubInfo{}, err
	}
	if result.ClubIntroduction, err = optionalStringField(object, "clubIntroduction"); err != nil {
		return ClubInfo{}, err
	}
	if result.TeacherName, err = optionalStringField(object, "teacherName"); err != nil {
		return ClubInfo{}, err
	}
	if result.OptionStatus, err = optionalStringLikeField(object, "optionStatus"); err != nil {
		return ClubInfo{}, err
	}
	if result.FullActivity, err = optionalStringField(object, "fullActivity"); err != nil {
		return ClubInfo{}, err
	}
	if result.YearSemester, err = optionalIntegerField(object, "yearSemester"); err != nil {
		return ClubInfo{}, err
	}
	if result.ActivityItemID, err = optionalIntegerField(object, "activityItemId"); err != nil {
		return ClubInfo{}, err
	}
	if result.SignStatus, err = optionalStringLikeField(object, "signStatus"); err != nil {
		return ClubInfo{}, err
	}
	return result, nil
}

func decodeClubJoinProgress(raw json.RawMessage) (ClubJoinProgress, error) {
	object, err := objectValue(raw)
	if err != nil {
		return ClubJoinProgress{}, err
	}
	result := ClubJoinProgress{}
	for _, field := range []struct {
		name string
		out  *int64
	}{
		{"totalNum", &result.TotalNum},
		{"joinNum", &result.JoinNum},
		{"runTotalNum", &result.RunTotalNum},
		{"runJoinNum", &result.RunJoinNum},
	} {
		if err := assignInt(object, field.name, field.out); err != nil {
			return ClubJoinProgress{}, err
		}
	}
	return result, nil
}

func decodeTopActivities(raw json.RawMessage) ([]ClubTopActivity, error) {
	var values []json.RawMessage
	if err := json.Unmarshal(raw, &values); err != nil {
		return nil, errors.New("response is not an array")
	}
	result := make([]ClubTopActivity, 0, len(values))
	for _, value := range values {
		object, err := objectValue(value)
		if err != nil {
			return nil, errors.New("activity item is not an object")
		}
		item := ClubTopActivity{}
		if item.ClubActivityID, err = stringField(object, "clubActivityId"); err != nil {
			return nil, err
		}
		if item.ActivityItemID, err = stringField(object, "activityItemId"); err != nil {
			return nil, err
		}
		if item.ItemName, err = stringField(object, "itemName"); err != nil {
			return nil, err
		}
		if item.ActivityName, err = stringField(object, "activityName"); err != nil {
			return nil, err
		}
		if item.StartTime, err = stringField(object, "startTime"); err != nil {
			return nil, err
		}
		if item.EndTime, err = stringField(object, "endTime"); err != nil {
			return nil, err
		}
		if item.AddressDetail, err = stringField(object, "addressDetail"); err != nil {
			return nil, err
		}
		if item.MaxStudent, err = stringField(object, "maxStudent"); err != nil {
			return nil, err
		}
		if item.ApplyStudentCount, err = stringField(object, "applyStudentCount"); err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	return result, nil
}

func objectValue(raw json.RawMessage) (map[string]json.RawMessage, error) {
	var value map[string]json.RawMessage
	if err := json.Unmarshal(raw, &value); err != nil || value == nil {
		return nil, errors.New("response is not an object")
	}
	return value, nil
}

func listValue(raw json.RawMessage) ([]json.RawMessage, error) {
	var direct []json.RawMessage
	if json.Unmarshal(raw, &direct) == nil {
		return direct, nil
	}
	object, err := objectValue(raw)
	if err != nil {
		return nil, errors.New("response is not a list")
	}
	for _, key := range []string{"records", "list", "rows", "items", "activityList"} {
		if value, ok := object[key]; ok {
			var list []json.RawMessage
			if json.Unmarshal(value, &list) != nil {
				return nil, errors.New("list field is not an array")
			}
			return list, nil
		}
	}
	return nil, errors.New("response is not a list")
}

func integerField(object map[string]json.RawMessage, key string) (int64, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return 0, nil
	}
	value, ok := numericIntegerRaw(raw)
	if !ok {
		return 0, fmt.Errorf("%s must be an integer", key)
	}
	return value, nil
}

func integerLikeField(object map[string]json.RawMessage, key string) (int64, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || bytes.Equal(bytes.TrimSpace(raw), []byte(`""`)) {
		return 0, nil
	}
	if value, ok := numericIntegerRaw(raw); ok {
		return value, nil
	}
	var text string
	if json.Unmarshal(raw, &text) == nil {
		value, err := strconv.ParseInt(text, 10, 64)
		if err == nil {
			return value, nil
		}
	}
	return 0, fmt.Errorf("%s must be an integer", key)
}

func stringField(object map[string]json.RawMessage, key string) (string, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return "", nil
	}
	value, ok := rawString(raw)
	if !ok {
		return "", fmt.Errorf("%s must be a string", key)
	}
	return value, nil
}

func stringLikeField(object map[string]json.RawMessage, key string) (string, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return "", nil
	}
	if value, ok := rawString(raw); ok {
		return value, nil
	}
	if value, ok := finiteNumberText(raw); ok {
		return value, nil
	}
	return "", fmt.Errorf("%s must be a string or number", key)
}

func optionalStringField(object map[string]json.RawMessage, key string) (string, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || bytes.Equal(bytes.TrimSpace(raw), []byte(`""`)) {
		return "", nil
	}
	return stringField(object, key)
}

func optionalStringLikeField(object map[string]json.RawMessage, key string) (string, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || bytes.Equal(bytes.TrimSpace(raw), []byte(`""`)) {
		return "", nil
	}
	return stringLikeField(object, key)
}

func optionalIntegerField(object map[string]json.RawMessage, key string) (int64, error) {
	raw, ok := object[key]
	if !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return 0, nil
	}
	value, ok := numericIntegerRaw(raw)
	if !ok {
		return 0, fmt.Errorf("%s must be an integer", key)
	}
	if value == 0 {
		return 0, nil
	}
	return value, nil
}

func assignInt(object map[string]json.RawMessage, key string, destination *int64) error {
	value, err := integerField(object, key)
	if err == nil {
		*destination = value
	}
	return err
}

func assignString(object map[string]json.RawMessage, key string, destination *string) error {
	value, err := stringField(object, key)
	if err == nil {
		*destination = value
	}
	return err
}

func rawString(raw json.RawMessage) (string, bool) {
	var value string
	if json.Unmarshal(raw, &value) != nil {
		return "", false
	}
	return value, true
}

func numericIntegerRaw(raw json.RawMessage) (int64, bool) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || trimmed[0] == '"' || bytes.Equal(trimmed, []byte("null")) {
		return 0, false
	}
	decoder := json.NewDecoder(bytes.NewReader(trimmed))
	decoder.UseNumber()
	var number json.Number
	if err := decoder.Decode(&number); err != nil {
		return 0, false
	}
	if value, err := strconv.ParseInt(number.String(), 10, 64); err == nil {
		return value, true
	}
	value, err := strconv.ParseFloat(number.String(), 64)
	if err != nil || math.IsNaN(value) || math.IsInf(value, 0) || math.Trunc(value) != value || value < math.MinInt64 || value > math.MaxInt64 {
		return 0, false
	}
	return int64(value), true
}

func finiteNumberText(raw json.RawMessage) (string, bool) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || trimmed[0] == '"' {
		return "", false
	}
	decoder := json.NewDecoder(bytes.NewReader(trimmed))
	decoder.UseNumber()
	var number json.Number
	if err := decoder.Decode(&number); err != nil {
		return "", false
	}
	value, err := strconv.ParseFloat(number.String(), 64)
	if err != nil || math.IsNaN(value) || math.IsInf(value, 0) {
		return "", false
	}
	if math.Trunc(value) == value {
		return strconv.FormatInt(int64(value), 10), true
	}
	return number.String(), true
}

func rawStringRequired(raw json.RawMessage) (string, bool) {
	if len(raw) == 0 {
		return "", false
	}
	return rawString(raw)
}
