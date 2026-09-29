import type { Classroom, ClassroomOptions, ClassroomSchedule } from '@/features/classrooms/api'
import type { Exam, ExamType } from '@/features/exams/api'
import type { Grade } from '@/features/grades/api'
import type { PlanCompletion } from '@/features/plan-completion/api'
import type { StudentProfile } from '@/features/profile/api'
import type { Course, CourseTable } from '@/features/schedule/api'
import type { Semester } from '@/shared/models/academic'

/**
 * 本地开发用的演示数据。
 *
 * 内容全部是编造的，不对应任何真实学生、课程、成绩或考场。
 * 只在 dev server 且 VITE_MOCK_API=true 时由 mock-api 插件返回，
 * 不会进入生产构建，也不需要真实教务账号。
 */

/** 演示账号：登录页填这一组就能进入。 */
export const mockStudentNo = '20240000'
export const mockPassword = 'demo'

export const currentSemesterID = '2025-2026-2'
const previousSemesterID = '2025-2026-1'
const earliestSemesterID = '2024-2025-2'

/** weeks 生成一段连续教学周，例如 weeks(1, 16)。 */
function weeks(from: number, to: number): number[] {
  const result: number[] = []
  for (let week = from; week <= to; week += 1) result.push(week)
  return result
}

export const mockProfile: StudentProfile = {
  StudentNo: mockStudentNo,
  Name: '演示同学',
  EnglishName: 'Demo Student',
  Gender: '女',
  Grade: '2024',
  StudyDuration: '4',
  Project: '软件工程',
  EducationLevel: '本科',
  StudentCategory: '普通本科生',
  College: '软件工程学院',
  Major: '软件工程',
  Direction: '软件开发',
  EnrollmentDate: '2024-09-01',
  ExpectedGraduationDate: '2028-07-01',
  AdministrativeCollege: '软件工程学院',
  StudyMode: '普通全日制',
  Campus: '航空港校区',
  ClassName: '软件工程 242 班',
  TrainingLevel: '本科',
  Counselor: '演示辅导员',
  StatusEffectiveDate: '2024-09-01',
  StudentStatus: '在校',
  Remark: '本地演示数据',
}

export const mockSemesters: Semester[] = [
  { ID: currentSemesterID, SchoolYear: '2025-2026', Term: '2', Current: true },
  { ID: previousSemesterID, SchoolYear: '2025-2026', Term: '1' },
  { ID: earliestSemesterID, SchoolYear: '2024-2025', Term: '2' },
]

const currentSemesterCourses: Course[] = [
  {
    LessonID: 'demo-lesson-001',
    Code: 'DEMO101',
    Name: '数据结构',
    Credits: '4.0',
    Sequence: '1',
    TeachingClass: '数据结构-01班',
    Teachers: ['演示老师甲'],
    Activities: [
      {
        TeacherIDs: null,
        Teachers: ['演示老师甲'],
        RoomID: 'demo-room-h6407',
        RoomName: 'H6407',
        Weekday: 1,
        StartSection: 1,
        EndSection: 2,
        Weeks: weeks(1, 16),
      },
      {
        TeacherIDs: null,
        Teachers: ['演示老师甲'],
        RoomID: 'demo-room-h6407',
        RoomName: 'H6407',
        Weekday: 3,
        StartSection: 3,
        EndSection: 4,
        Weeks: weeks(1, 16),
      },
    ],
  },
  {
    LessonID: 'demo-lesson-002',
    Code: 'DEMO102',
    Name: '操作系统原理',
    Credits: '3.5',
    Sequence: '1',
    TeachingClass: '操作系统原理-02班',
    Teachers: ['演示老师乙'],
    Activities: [
      {
        TeacherIDs: null,
        Teachers: ['演示老师乙'],
        RoomID: 'demo-room-h1208',
        RoomName: 'H1208',
        Weekday: 2,
        StartSection: 1,
        EndSection: 2,
        Weeks: weeks(1, 16),
      },
      {
        TeacherIDs: null,
        Teachers: ['演示老师乙'],
        RoomID: 'demo-room-h1208',
        RoomName: 'H1208',
        Weekday: 4,
        StartSection: 5,
        EndSection: 6,
        Weeks: weeks(1, 16),
      },
    ],
  },
  {
    LessonID: 'demo-lesson-003',
    Code: 'DEMO103',
    Name: '计算机网络',
    Credits: '3.0',
    Sequence: '1',
    TeachingClass: '计算机网络-01班',
    Teachers: ['演示老师丙'],
    Activities: [
      {
        TeacherIDs: null,
        Teachers: ['演示老师丙'],
        RoomID: 'demo-room-h6502',
        RoomName: 'H6502',
        Weekday: 1,
        StartSection: 3,
        EndSection: 4,
        Weeks: weeks(1, 8),
      },
      {
        // 单周实验课：用来验证不规则周次和自定义上下课时间的排版。
        TeacherIDs: null,
        Teachers: ['演示老师丙'],
        RoomID: 'demo-room-lab-b412',
        RoomName: '实验楼B412',
        Weekday: 5,
        StartSection: 5,
        EndSection: 8,
        Weeks: [3, 5, 7, 9, 11],
        StartTime: '14:00',
        EndTime: '17:30',
        ActivityType: '实验',
        ProjectName: '网络协议分析实验',
      },
    ],
  },
  {
    LessonID: 'demo-lesson-004',
    Code: 'DEMO104',
    Name: '软件工程',
    Credits: '3.0',
    Sequence: '1',
    TeachingClass: '软件工程-03班',
    Teachers: ['演示老师丁'],
    Activities: [
      {
        TeacherIDs: null,
        Teachers: ['演示老师丁'],
        RoomID: 'demo-room-h4313',
        RoomName: 'H4313',
        Weekday: 3,
        StartSection: 5,
        EndSection: 6,
        Weeks: weeks(1, 16),
      },
      {
        TeacherIDs: null,
        Teachers: ['演示老师丁'],
        RoomID: 'demo-room-h4313',
        RoomName: 'H4313',
        Weekday: 5,
        StartSection: 1,
        EndSection: 2,
        Weeks: weeks(1, 16),
      },
    ],
  },
  {
    LessonID: 'demo-lesson-005',
    Code: 'DEMO105',
    Name: '大学英语（四）',
    Credits: '2.0',
    Sequence: '1',
    TeachingClass: '大学英语-05班',
    Teachers: ['演示老师戊'],
    Activities: [
      {
        TeacherIDs: null,
        Teachers: ['演示老师戊'],
        RoomID: 'demo-room-h2205',
        RoomName: 'H2205',
        Weekday: 4,
        StartSection: 7,
        EndSection: 8,
        Weeks: weeks(1, 16),
      },
    ],
  },
]

/** 非当前学期返回空课表：切换学期时能看出数据确实换了。 */
export function mockCourseTable(semesterID: string): CourseTable {
  return {
    SemesterID: semesterID,
    WeekCount: 18,
    SectionsPerDay: 12,
    Courses: semesterID === currentSemesterID ? currentSemesterCourses : [],
  }
}

export function mockGrades(semesterID: string): Grade[] {
  if (semesterID === currentSemesterID) {
    return [
      {
        SchoolYearTerm: '2025-2026-2',
        CourseCode: 'DEMO101',
        CourseSequence: '1',
        CourseName: '数据结构',
        CourseCategory: '专业必修',
        Credits: '4.0',
        UsualScore: '88',
        FinalExamScore: '91',
        MakeupScore: '',
        OverallScore: '90',
        FinalScore: '90',
        GradePoint: '4.0',
      },
      {
        SchoolYearTerm: '2025-2026-2',
        CourseCode: 'DEMO103',
        CourseSequence: '1',
        CourseName: '计算机网络',
        CourseCategory: '专业必修',
        Credits: '3.0',
        UsualScore: '82',
        FinalExamScore: '76',
        MakeupScore: '',
        OverallScore: '78',
        FinalScore: '78',
        GradePoint: '3.0',
      },
      {
        SchoolYearTerm: '2025-2026-2',
        CourseCode: 'DEMO105',
        CourseSequence: '1',
        CourseName: '大学英语（四）',
        CourseCategory: '公共必修',
        Credits: '2.0',
        UsualScore: '90',
        FinalExamScore: '85',
        MakeupScore: '',
        OverallScore: '87',
        FinalScore: '87',
        GradePoint: '3.7',
      },
    ]
  }

  if (semesterID === previousSemesterID) {
    return [
      {
        SchoolYearTerm: '2025-2026-1',
        CourseCode: 'DEMO201',
        CourseSequence: '1',
        CourseName: '离散数学',
        CourseCategory: '专业必修',
        Credits: '3.0',
        UsualScore: '85',
        FinalExamScore: '79',
        MakeupScore: '',
        OverallScore: '81',
        FinalScore: '81',
        GradePoint: '3.3',
      },
      {
        // 补考过的课程：平时分、补考分、总评都有值，用来验证成绩页的展示分支。
        SchoolYearTerm: '2025-2026-1',
        CourseCode: 'DEMO202',
        CourseSequence: '1',
        CourseName: '计算机组成原理',
        CourseCategory: '专业必修',
        Credits: '4.0',
        UsualScore: '78',
        FinalExamScore: '52',
        MakeupScore: '71',
        OverallScore: '71',
        FinalScore: '71',
        GradePoint: '2.3',
      },
      {
        SchoolYearTerm: '2025-2026-1',
        CourseCode: 'DEMO203',
        CourseSequence: '1',
        CourseName: '大学英语（三）',
        CourseCategory: '公共必修',
        Credits: '2.0',
        UsualScore: '92',
        FinalExamScore: '88',
        MakeupScore: '',
        OverallScore: '89',
        FinalScore: '89',
        GradePoint: '3.9',
      },
    ]
  }

  return []
}

const currentSemesterExams: Exam[] = [
  {
    CourseSequence: '1',
    CourseName: '数据结构',
    ExamType: 'final',
    ExamDate: '2026-01-06',
    ExamTime: '09:00-11:00',
    Location: 'H6407',
    ExamRoomID: 'demo-exam-room-1',
    Credits: '4.0',
    Status: '已安排',
    Remark: '',
  },
  {
    CourseSequence: '1',
    CourseName: '操作系统原理',
    ExamType: 'final',
    ExamDate: '2026-01-08',
    ExamTime: '14:30-16:30',
    Location: 'H1208',
    ExamRoomID: 'demo-exam-room-2',
    Credits: '3.5',
    Status: '已安排',
    Remark: '',
  },
  {
    CourseSequence: '1',
    CourseName: '计算机网络',
    ExamType: 'makeup',
    ExamDate: '2026-01-15',
    ExamTime: '09:00-11:00',
    Location: 'H6502',
    ExamRoomID: 'demo-exam-room-3',
    Credits: '3.0',
    Status: '待确认',
    Remark: '补考安排，请以教务系统通知为准',
  },
]

export function mockExams(semesterID: string, examType: ExamType | null): Exam[] {
  if (semesterID !== currentSemesterID) return []
  if (!examType) return currentSemesterExams
  return currentSemesterExams.filter((exam) => exam.ExamType === examType)
}

export const mockPlanCompletion: PlanCompletion = {
  Summary: {
    StudentNo: mockStudentNo,
    Name: '演示同学',
    Grade: '2024',
    EducationLevel: '本科',
    StudentCategory: '普通本科生',
    College: '软件工程学院',
    Major: '软件工程',
    RequiredCredits: '170',
    EarnedCredits: '42.5',
    GPA: '3.52',
    AuditResult: '通过',
    AuditTime: '2026-01-20 10:00',
    Auditor: '演示审核员',
    Remark: '',
  },
  Items: [
    {
      Kind: 'requirement',
      Sequence: '1',
      CourseCode: '',
      Name: '公共必修课',
      RequiredCredits: '40',
      EarnedCredits: '12',
      Score: '',
      Status: '进行中',
      Remark: '',
    },
    {
      Kind: 'requirement',
      Sequence: '2',
      CourseCode: '',
      Name: '专业必修课',
      RequiredCredits: '80',
      EarnedCredits: '25.5',
      Score: '',
      Status: '进行中',
      Remark: '',
    },
    {
      Kind: 'course',
      Sequence: '1',
      CourseCode: 'DEMO101',
      Name: '数据结构',
      RequiredCredits: '4.0',
      EarnedCredits: '4.0',
      Score: '90',
      Status: '已通过',
      Remark: '',
    },
    {
      Kind: 'course',
      Sequence: '2',
      CourseCode: 'DEMO202',
      Name: '计算机组成原理',
      RequiredCredits: '4.0',
      EarnedCredits: '4.0',
      Score: '71',
      Status: '已通过',
      Remark: '',
    },
    {
      Kind: 'course',
      Sequence: '3',
      CourseCode: 'DEMO104',
      Name: '软件工程',
      RequiredCredits: '3.0',
      EarnedCredits: '0',
      Score: '',
      Status: '在读',
      Remark: '',
    },
  ],
}

const demoClassrooms: Classroom[] = [
  {
    ID: 'demo-room-h6407',
    Code: 'H6407',
    Name: 'H6407',
    Building: 'H 教学楼',
    Campus: '航空港校区',
    Type: '多媒体教室',
    Capacity: 120,
  },
  {
    ID: 'demo-room-h6502',
    Code: 'H6502',
    Name: 'H6502',
    Building: 'H 教学楼',
    Campus: '航空港校区',
    Type: '多媒体教室',
    Capacity: 120,
  },
  {
    ID: 'demo-room-h4313',
    Code: 'H4313',
    Name: 'H4313',
    Building: 'H 教学楼',
    Campus: '航空港校区',
    Type: '普通教室',
    Capacity: 90,
  },
  {
    ID: 'demo-room-h2205',
    Code: 'H2205',
    Name: 'H2205',
    Building: 'H 教学楼',
    Campus: '航空港校区',
    Type: '普通教室',
    Capacity: 60,
  },
]

export const mockClassroomOptions: ClassroomOptions = {
  Campuses: [{ ID: 'demo-campus-1', Name: '航空港校区' }],
  ClassroomTypes: [
    { ID: 'demo-type-1', Name: '多媒体教室' },
    { ID: 'demo-type-2', Name: '普通教室' },
  ],
  Buildings: [{ ID: 'demo-building-h', Name: 'H 教学楼' }],
}

/** 演示用的空闲教室：简单地返回全部教室，筛选条件不参与计算。 */
export function mockAvailableClassrooms(): Classroom[] {
  return demoClassrooms
}

export function mockClassroomSchedule(semesterID: string, campusID: string): ClassroomSchedule {
  return {
    SemesterID: semesterID,
    CampusID: campusID,
    Rooms: demoClassrooms.map((classroom) => ({
      Classroom: classroom,
      Occupancies: [
        { Weekday: 1, StartSection: 1, EndSection: 2, Weeks: weeks(1, 16) },
        { Weekday: 3, StartSection: 3, EndSection: 4, Weeks: weeks(1, 16) },
      ],
    })),
  }
}

/** 当前教学周：固定第 4 周，前端不会因为日期不同而每次结果都不一样。 */
export const mockCurrentWeek = 4
