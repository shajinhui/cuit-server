export const courseToneOptions = [
  { tone: 'haze-blue', label: '雾霾蓝' },
  { tone: 'terracotta', label: '陶土橙' },
  { tone: 'sage', label: '鼠尾草绿' },
  { tone: 'dusty-purple', label: '灰紫' },
  { tone: 'mustard', label: '芥末黄' },
  { tone: 'rose-brown', label: '玫瑰棕' },
  { tone: 'blue-gray', label: '青灰' },
  { tone: 'caramel', label: '焦糖棕' },
  { tone: 'slate-blue', label: '石板蓝' },
  { tone: 'olive', label: '橄榄灰' },
  { tone: 'muted-coral', label: '柔珊瑚' },
  { tone: 'seafoam', label: '海沫青' },
  { tone: 'lavender-gray', label: '薰衣草灰' },
  { tone: 'sand', label: '沙岩色' },
  { tone: 'pine', label: '松针绿' },
] as const

export type CourseTone = (typeof courseToneOptions)[number]['tone']

export const courseTones: readonly CourseTone[] = courseToneOptions.map(({ tone }) => tone)

export interface CourseColorPreference {
  semesterID: string
  courseKey: string
  tone: CourseTone
}

export function isCourseTone(value: unknown): value is CourseTone {
  return typeof value === 'string' && courseTones.includes(value as CourseTone)
}

export function isCourseColorPreference(value: unknown): value is CourseColorPreference {
  if (!value || typeof value !== 'object') return false

  const preference = value as Partial<CourseColorPreference>
  return (
    typeof preference.semesterID === 'string' &&
    Boolean(preference.semesterID) &&
    typeof preference.courseKey === 'string' &&
    Boolean(preference.courseKey) &&
    isCourseTone(preference.tone)
  )
}
