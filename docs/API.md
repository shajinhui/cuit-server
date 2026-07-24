# Campus Assistant API 接口文档

本文档只记录当前代码已经实现的 HTTP API。

## 1. 基本约定

本地默认地址：

```text
http://127.0.0.1:8888
```

除健康检查外，业务接口统一使用以下响应结构：

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `code` | number | 业务状态码，`0` 表示成功 |
| `message` | string | 面向调用方的结果说明 |
| `data` | any | 成功时为业务数据，失败时为 `null` |

JWXT 业务响应包含：

```http
Cache-Control: no-store
```

## 2. 登录与会话

登录成功后，服务端通过 `campus_session` Cookie 识别当前用户：

- `Path=/`
- `HttpOnly`
- `SameSite=Lax`
- `APP_COOKIE_SECURE=true` 时启用 `Secure`
- 服务端 Session 不设置业务过期时间，新登录会覆盖同一学号的旧 Session
- 浏览器 Cookie 使用长期有效期；查询会话状态成功时会续写有效期

浏览器请求必须携带 Cookie。前端 `fetch` 应设置：

```ts
credentials: 'include'
```

学校的 CAS Cookie、EAMS Cookie 和 `JSESSIONID` 不会返回给前端。

### 2.1 登录教务系统

```http
POST /api/v1/jwxt/session
Content-Type: application/json
```

请求体：

```json
{
  "username": "<学号>",
  "password": "<密码>"
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `username` | string | 是 | 学号 |
| `password` | string | 是 | 教务系统密码 |

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "authenticated": true
  }
}
```

注意：客户端不得记录或持久化明文密码。

### 2.2 查询会话状态

```http
GET /api/v1/jwxt/session
```

该接口只检查本应用会话，不访问学校教务系统。没有 Cookie 或应用会话不存在时仍返回 HTTP 200：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "authenticated": false
  }
}
```

### 2.3 退出登录

```http
DELETE /api/v1/jwxt/session
```

接口会清除 SQLite 中的应用 Session Token 哈希、清理内存中的 JWXT Client，并使 `campus_session` Cookie 失效。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "authenticated": false
  }
}
```

### 2.4 查询个人学籍信息

```http
GET /api/v1/jwxt/profile
```

需要有效的 `campus_session` Cookie。后端通过当前用户的独立 JWXT 会话读取教务系统“学籍信息”页面；教务 Session 失效时会自动重新登录并只重试一次。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "StudentNo": "test-student",
    "Name": "测试同学",
    "EnglishName": "Test Student",
    "Gender": "男",
    "Grade": "2024",
    "StudyDuration": "4",
    "Project": "本科",
    "EducationLevel": "本科",
    "StudentCategory": "普通本科生",
    "College": "测试学院",
    "Major": "测试专业",
    "Direction": "",
    "EnrollmentDate": "2024-08-31",
    "ExpectedGraduationDate": "2028-06-30",
    "AdministrativeCollege": "测试学院",
    "StudyMode": "普通全日制",
    "Campus": "测试校区",
    "ClassName": "测试班",
    "TrainingLevel": "本科",
    "Counselor": "测试老师",
    "StatusEffectiveDate": "2024-08-31",
    "StudentStatus": "注册学籍",
    "Remark": ""
  }
}
```

所有字段均为字符串；教务系统中的空字段返回空字符串。

### 2.5 查询计划完成情况

```http
GET /api/v1/jwxt/plan-completion
```

需要有效的 `campus_session` Cookie。返回顶部审核摘要以及按教务页面原始顺序排列的要求分类和课程明细。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "Summary": {
      "StudentNo": "test-student",
      "Name": "测试同学",
      "Grade": "2024",
      "RequiredCredits": "160",
      "EarnedCredits": "100",
      "GPA": "3.20",
      "AuditResult": "预审通过"
    },
    "Items": [
      {
        "Kind": "requirement",
        "Name": "一 测试必修",
        "RequiredCredits": "10",
        "EarnedCredits": "8",
        "Status": "缺 2 学分"
      },
      {
        "Kind": "course",
        "Sequence": "1",
        "CourseCode": "TEST001",
        "Name": "测试课程",
        "RequiredCredits": "2",
        "EarnedCredits": "2",
        "Score": "80",
        "Status": "是",
        "Remark": ""
      }
    ]
  }
}
```

`Kind=requirement` 表示培养要求分类行，`Kind=course` 表示课程行。所有业务字段均为字符串，空值返回空字符串。

## 3. 学期

### 3.1 查询学期列表

```http
GET /api/v1/jwxt/semesters
```

需要有效的 `campus_session` Cookie。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "ID": "1106",
      "SchoolYear": "2026-2027",
      "Term": "1"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `ID` | string | EAMS 学期 ID，成绩、课表和考试批次查询使用该值 |
| `SchoolYear` | string | 学年，例如 `2026-2027` |
| `Term` | string | 学期序号，例如 `1` 或 `2` |

## 4. 成绩

### 4.1 查询指定学期成绩

```http
GET /api/v1/jwxt/grades?semester_id=1106
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `semester_id` | string | 是 | `/api/v1/jwxt/semesters` 返回的 `ID` |

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "SchoolYearTerm": "2026-2027 1",
      "CourseCode": "COURSE001",
      "CourseSequence": "COURSE001.001",
      "CourseName": "示例课程",
      "CourseCategory": "专业必修",
      "Credits": "2",
      "UsualScore": "85",
      "FinalExamScore": "80",
      "OverallScore": "82",
      "FinalScore": "82",
      "GradePoint": "3.2"
    }
  ]
}
```

成绩字段均为字符串，以保留空成绩和小数学分。

## 5. 考试

前端只使用固定的 `final`（期末考试）和 `makeup`（开学补考）。同名批次在不同学期的 EAMS 内部 ID 不同，由后端在查询时解析，前端不再单独请求考试批次。

### 5.1 查询考试及考场安排

```http
GET /api/v1/jwxt/exams?semester_id=1006&exam_type=final
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `semester_id` | string | 是 | `/api/v1/jwxt/semesters` 返回的 `ID` |
| `exam_type` | string | 是 | `final`（期末考试）或 `makeup`（开学补考） |

目标学期尚未设置对应考试批次时，`data` 返回空数组。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "CourseSequence": "COURSE001.001",
      "CourseName": "示例课程",
      "ExamType": "期末考试",
      "ExamDate": "2026-01-10",
      "ExamTime": "09:30~11:30",
      "Location": "A101",
      "ExamRoomID": "8001",
      "Credits": "2",
      "Status": "正常",
      "Remark": ""
    }
  ]
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `CourseSequence` | string | 课程序号 |
| `CourseName` | string | 课程名称 |
| `ExamType` | string | 考试类别，例如“期末考试”或“补考” |
| `ExamDate` | string | 考试日期；未安排时保留学校返回的“时间未安排” |
| `ExamTime` | string | 考试时间；未安排时保留学校返回的“时间未安排” |
| `Location` | string | 考试地点；未安排时保留学校返回的“地点未安排” |
| `ExamRoomID` | string | 考场内部 ID；地点没有考场链接时为空字符串 |
| `Credits` | string | 课程学分 |
| `Status` | string | 考试状态 |
| `Remark` | string | 考试备注 |

该批次没有考试安排时，`data` 为空数组。

## 6. 课表与教室

### 6.1 查询指定学期课表

```http
GET /api/v1/jwxt/course-table?semester_id=1106
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `semester_id` | string | 是 | `/api/v1/jwxt/semesters` 返回的 `ID` |

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "SemesterID": "1106",
    "WeekCount": 19,
    "SectionsPerDay": 12,
    "Courses": [
      {
        "LessonID": "101",
        "Code": "COURSE001",
        "Name": "示例课程",
        "Credits": "2",
        "Sequence": "COURSE001.001",
        "TeachingClass": "示例班",
        "Teachers": ["教师甲"],
        "Activities": [
          {
            "TeacherIDs": ["11"],
            "Teachers": ["教师甲"],
            "RoomID": "20",
            "RoomName": "A101",
            "Weekday": 1,
            "StartSection": 1,
            "EndSection": 2,
            "Weeks": [1, 2, 3, 4]
          }
        ]
      }
    ]
  }
}
```

课表字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `SemesterID` | string | 查询的 EAMS 学期 ID |
| `WeekCount` | number | 该学期课表覆盖的最大教学周 |
| `SectionsPerDay` | number | 每天的总节次数量 |
| `Courses` | array | 该学期课程及上课安排 |

课程字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `LessonID` | string | EAMS 教学任务 ID |
| `Code` | string | 课程代码 |
| `Name` | string | 课程名称 |
| `Credits` | string | 学分，保留小数形式 |
| `Sequence` | string | 课程序号 |
| `TeachingClass` | string | 教学班名称 |
| `Teachers` | string[] | 课程教师列表 |
| `Activities` | array | 该课程的具体上课安排；暂未排课时为空数组 |

上课安排字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `TeacherIDs` | string[] | EAMS 教师内部 ID |
| `Teachers` | string[] | 本次上课的教师列表 |
| `RoomID` | string | EAMS 教室内部 ID |
| `RoomName` | string | 教室名称 |
| `Weekday` | number | `1` 至 `7` 分别表示周一至周日 |
| `StartSection` | number | 起始节次，从 `1` 开始，包含该节 |
| `EndSection` | number | 结束节次，从 `1` 开始，包含该节 |
| `Weeks` | number[] | 实际上课周次，可表达连续周、单双周和不规则周次 |

### 6.2 查询空教室筛选项

```http
GET /api/v1/jwxt/classroom-options?semester_id=905&campus_id=1
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `semester_id` | string | 是 | `/api/v1/jwxt/semesters` 返回的 `ID` |
| `campus_id` | string | 否 | 校区 ID；传入后同时返回该校区的教学楼 |

校区和教室类型是固定枚举，前端直接使用，不需要调用本接口。只有用户打开“更多筛选”并需要教学楼列表时，才携带 `campus_id` 请求一次。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "Campuses": [
      {
        "ID": "1",
        "Name": "航空港"
      }
    ],
    "ClassroomTypes": [
      {
        "ID": "2",
        "Name": "多媒体"
      }
    ],
    "Buildings": [
      {
        "ID": "2",
        "Name": "航空港第二教学楼"
      }
    ]
  }
}
```

未传 `campus_id` 时，`Buildings` 为空数组。

### 6.3 查询空教室

```http
GET /api/v1/jwxt/available-classrooms?semester_id=905&week=8&weekday=3&sections=3,4&campus_id=1&building_id=2&classroom_type_id=2&min_capacity=50
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `semester_id` | string | 是 | `/api/v1/jwxt/semesters` 返回的 `ID` |
| `week` | number | 是 | 教学周，范围为 `1` 至 `53` |
| `weekday` | number | 是 | 星期，`1` 至 `7` 分别表示周一至周日 |
| `sections` | string | 是 | 节次列表，以英文逗号分隔；每个节次范围为 `1` 至 `12` |
| `campus_id` | string | 是 | 固定校区 ID：`1` 航空港、`2` 龙泉、`22` 芯谷 |
| `building_id` | string | 否 | 指定校区下的教学楼 `ID` |
| `classroom_type_id` | string | 否 | 教室类型 `ID` |
| `min_capacity` | number | 否 | 最小容纳人数，必须大于或等于 `0` |

后端会先取得符合筛选条件的教室，再读取这些教室在指定学期的排课情况。只有在所选周次、星期和全部节次均未排课的教室才会返回。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "ID": "67",
      "Code": "H2101",
      "Name": "H2101",
      "Building": "航空港第二教学楼",
      "Campus": "航空港",
      "Type": "多媒体",
      "Capacity": 166
    }
  ]
}
```

没有符合条件的教室时返回：

```json
{
  "code": 0,
  "message": "success",
  "data": []
}
```

### 6.4 查询教室课表快照

```http
GET /api/v1/jwxt/classroom-schedule?semester_id=905&campus_id=1
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `semester_id` | string | 是 | `/api/v1/jwxt/semesters` 返回的 `ID` |
| `campus_id` | string | 是 | 固定校区 ID：`1` 航空港、`2` 龙泉、`22` 芯谷 |

接口一次返回该学期、校区的全部教室和整学期占用时间。前端以 `semester_id + campus_id` 为键保存纯 JSON 快照，后续周次、星期、节次、教学楼、类型和容量筛选均在本地完成；只有缓存不存在、用户主动更新或切换到未缓存的学期/校区时再次请求。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "SemesterID": "905",
    "CampusID": "1",
    "Rooms": [
      {
        "Classroom": {
          "ID": "67",
          "Code": "H2101",
          "Name": "H2101",
          "Building": "航空港第二教学楼",
          "Campus": "航空港",
          "Type": "多媒体",
          "Capacity": 166
        },
        "Occupancies": [
          {
            "Weekday": 1,
            "StartSection": 1,
            "EndSection": 2,
            "Weeks": [1, 2, 3]
          }
        ]
      }
    ]
  }
}
```

### 6.5 查询当前教学周

```http
GET /api/v1/schedule/current-week
```

无需登录。后端读取教务处公开主页中的校历日期锚点，并按官网相同规则计算当前教学周。该接口表示学校当前校历周次，不与指定的历史或未来 `semester_id` 绑定。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "CurrentWeek": 21
  }
}
```

## 7. 健康检查

```http
GET /api/v1/health
```

无需登录。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "status": "ok"
  }
}
```

## 8. 错误码

| HTTP 状态码 | 业务码 | 当前含义 |
|---:|---:|---|
| 400 | `40000` | 请求参数不完整、未选择学期 |
| 401 | `40001` | 学号或密码错误 |
| 401 | `40101` | 应用会话不存在、已被新登录覆盖，或教务登录已失效 |
| 502 | `50201` | 学校教务系统暂时无法访问 |
| 502 | `50202` | 成绩查询失败 |
| 502 | `50203` | 课表查询失败 |
| 502 | `50204` | 教务处当前教学周查询失败 |
| 502 | `50205` | 个人学籍信息查询失败 |
| 502 | `50206` | 计划完成情况查询失败 |
| 502 | `50207` | 教室筛选项、教室课表或空教室查询失败 |
| 502 | `50208` | 考试批次或考场安排查询失败 |
| 500 | `50000` | 未分类的服务端错误 |

失败响应示例：

```json
{
  "code": 40101,
  "message": "教务登录已失效，请重新登录",
  "data": null
}
```

## 9. Session 恢复规则

- 每个用户的 JWXT Client 和 CookieJar 相互独立。
- API 只向客户端发放本应用的 `campus_session` Cookie。
- 同一学号只保存一个应用 Session；新登录会使旧 Cookie 立即失效。
- 热请求通过 Token 哈希直接找到内存 Client，不会每次查询 SQLite。
- 同一用户的教务请求串行执行，避免并发操作同一个 CookieJar。
- JWXT Client 空闲 3 分钟后释放；应用 Session 仍保留，后续查询会用加密凭据重新登录。
- API 重启后，可根据 SQLite 中的应用 Session 和加密教务凭据恢复 JWXT Client。
- 查询个人学籍信息、计划完成情况、学期、成绩、考试、课表、教室筛选项、教室课表或空教室时，如果 EAMS Session 失效，后端会重新登录并只重试原查询一次。
- 客户端收到 HTTP 401 / `40101` 后，应回到登录页，不应自行保存密码重试。
