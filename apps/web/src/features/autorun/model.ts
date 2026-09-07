import type {
  AutoRunClubActivity,
  AutoRunClubSignTask,
  AutoRunRunData,
} from './api'

export interface AutoRunProgressCard {
  id: string
  title: string
  current: number
  target: number
  unit: string
  subtitle: string
  accent: string
}

export interface AutoRunClubActivityView {
  id: string
  activityId: number
  title: string
  startTime: string
  endTime: string
  address: string
  joined: number
  capacity: number
  isJoined: boolean
  isFull: boolean
}

export interface AutoRunClubSignTaskView {
  activityId: number
  activityName: string
  startTime: string
  endTime: string
  address: string
  signStatus: string
  signInStatus: string
  signBackStatus: string
  signInTime: string
}

export interface AutoRunClubSignAction {
  signType: '1' | '2'
  label: string
  pendingLabel: string
  disabled: boolean
}

export interface AutoRunWeekDate {
  day: string
  date: string
  full: string
}

export function buildAutoRunProgressCards(data: AutoRunRunData): AutoRunProgressCard[] {
  const currentCount = firstNumber(data.runInfo, ['runValidCount', 'runCount']) ?? 0
  const countTarget = Math.max(
    maxPositiveNumber(data.runStandard, [
      'boyAllRunTime',
      'girlAllRunTime',
      'allRunTime',
      'runTimes',
      'runCount',
      'targetRunCount',
      'minRunCount',
      'effectiveRunCount',
      'totalRunCount',
    ]) ?? 20,
    1,
  )
  const currentDistance = toKilometres(
    firstNumber(data.runInfo, ['runValidDistance', 'runDistance']) ?? 0,
  )
  const distanceTarget = Math.max(
    toKilometres(
      maxPositiveNumber(data.runStandard, [
        'boyAllRunDistance',
        'girlAllRunDistance',
        'allRunDistance',
        'runDistance',
        'targetDistance',
        'minRunDistance',
        'effectiveDistance',
        'totalDistance',
      ]) ?? 60,
    ),
    1,
  )

  return [
    {
      id: 'count-progress',
      title: '校园跑次数进度',
      current: currentCount,
      target: countTarget,
      unit: '次',
      subtitle: '本学期有效打卡次数',
      accent: 'linear-gradient(90deg, #4f8cff, #55d6ff)',
    },
    {
      id: 'distance-progress',
      title: '校园跑距离进度',
      current: Number(currentDistance.toFixed(1)),
      target: Number(distanceTarget.toFixed(1)),
      unit: 'km',
      subtitle: '本学期累计有效距离',
      accent: 'linear-gradient(90deg, #ff9f43, #ffd166)',
    },
  ]
}

export function normalizeAutoRunClubActivities(
  activities: AutoRunClubActivity[],
): AutoRunClubActivityView[] {
  return activities
    .map((activity, index) => {
      const joined = firstNumber(activity, ['signInStudent', 'applyStudentCount']) ?? 0
      const capacity = firstNumber(activity, ['maxStudent']) ?? 0
      const optionStatus = String(activity.optionStatus ?? '').trim()
      const isFull =
        optionStatus === '3' ||
        String(activity.fullActivity ?? '') === '1' ||
        (capacity > 0 && joined >= capacity)

      return {
        id: String(activity.clubActivityId || index),
        activityId: asNumber(activity.clubActivityId) ?? 0,
        title: String(activity.activityName || '未命名活动'),
        startTime: String(activity.startTime || '--:--'),
        endTime: String(activity.endTime || '--:--'),
        address: String(activity.addressDetail || activity.teacherName || '地点待公布'),
        joined,
        capacity,
        isJoined: optionStatus === '1',
        isFull,
      }
    })
    .filter((activity) => activity.activityId > 0)
}

export function normalizeAutoRunClubSignTask(
  task: AutoRunClubSignTask | null,
): AutoRunClubSignTaskView | null {
  if (!task) return null
  const activityId = firstNumber(task, ['activityId', 'clubActivityId']) ?? 0
  if (activityId <= 0) return null

  return {
    activityId,
    activityName: readString(task.activityName) || '未命名活动',
    startTime: readString(task.startTime) || '--:--',
    endTime: readString(task.endTime) || '--:--',
    address: readString(task.address) || readString(task.addressDetail) || '地点待公布',
    signStatus: readString(task.signStatus),
    signInStatus: readString(task.signInStatus),
    signBackStatus: readString(task.signBackStatus),
    signInTime: readString(task.signInTime),
  }
}

export function resolveAutoRunClubSignAction(
  task: AutoRunClubSignTaskView | null,
): AutoRunClubSignAction | null {
  if (!task) return null
  if (!isSignedStatus(task.signInStatus) && task.signStatus === '1') {
    return { signType: '1', label: '签到', pendingLabel: '签到中…', disabled: false }
  }
  if (isSignedStatus(task.signInStatus) && !isSignedStatus(task.signBackStatus)) {
    return {
      signType: '2',
      label: '签退',
      pendingLabel: '签退中…',
      disabled: task.signStatus !== '2',
    }
  }
  return null
}

export function describeAutoRunClubSignTask(task: AutoRunClubSignTaskView | null) {
  if (!task) return '当前没有可执行签到/签退任务'
  if (isSignedStatus(task.signInStatus) && isSignedStatus(task.signBackStatus)) {
    return '已完成签到/签退'
  }
  if (isSignedStatus(task.signInStatus)) {
    return task.signStatus === '2' ? '已签到，可签退' : '已签到，等待签退'
  }
  return task.signStatus === '1' ? '可签到' : '等待签到'
}

export function createAutoRunWeekDates(start = new Date()): AutoRunWeekDate[] {
  const weekLabels = ['日', '一', '二', '三', '四', '五', '六']
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    return {
      day: weekLabels[date.getDay()] ?? '',
      date: String(date.getDate()).padStart(2, '0'),
      full: formatLocalDate(date),
    }
  })
}

export function formatLocalDate(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(
    date.getDate(),
  ).padStart(2, '0')}`
}

export function formatAutoRunNumber(value: number) {
  return Math.abs(value - Math.round(value)) < 1e-6 ? String(Math.round(value)) : value.toFixed(1)
}

export function autoRunProgressPercent(current: number, target: number) {
  return Math.round(Math.max(0, Math.min(100, (current / Math.max(target, 1)) * 100)))
}

export function isSignedStatus(value: unknown) {
  return String(value ?? '').trim() === '1'
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value
  if (typeof value === 'string') {
    const parsed = Number(value)
    if (Number.isFinite(parsed)) return parsed
  }
  return null
}

function firstNumber(value: unknown, keys: string[]): number | null {
  if (!value || typeof value !== 'object') return null
  const record = value as Record<string, unknown>
  for (const key of keys) {
    const number = asNumber(record[key])
    if (number !== null) return number
  }
  return null
}

function maxPositiveNumber(value: unknown, keys: string[]): number | null {
  if (!value || typeof value !== 'object') return null
  const record = value as Record<string, unknown>
  const values = keys
    .map((key) => asNumber(record[key]))
    .filter((number): number is number => number !== null && number > 0)
  return values.length > 0 ? Math.max(...values) : null
}

function toKilometres(value: number) {
  return Math.abs(value) >= 1000 ? value / 1000 : value
}

function readString(value: unknown) {
  return value === null || value === undefined ? '' : String(value).trim()
}
