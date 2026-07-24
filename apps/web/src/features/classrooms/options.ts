import type { ClassroomOption } from './api'

// 校区和教室类型来自学校公共课表的固定枚举，页面直接使用，避免每次进入都请求后端。
export const classroomCampuses: ClassroomOption[] = [
  { ID: '1', Name: '航空港' },
  { ID: '2', Name: '龙泉' },
  { ID: '22', Name: '芯谷' },
]

export const classroomTypes: ClassroomOption[] = [
  { ID: '1', Name: '普通' },
  { ID: '2', Name: '多媒体' },
  { ID: '3', Name: '精品课程录播' },
  { ID: '4', Name: '语音教室' },
  { ID: '22', Name: '体育场馆' },
  { ID: '122', Name: '智慧教室' },
]
