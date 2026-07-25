import type { Pinia } from 'pinia'

import {
  clearClassroomScheduleCache,
  hasClassroomScheduleCache,
  useClassroomsStore,
} from '@/features/classrooms'
import { useExamsStore } from '@/features/exams'
import { usePlanCompletionStore } from '@/features/plan-completion'
import { clearProfileCache, hasProfileCache, useProfileStore } from '@/features/profile'
import { clearScheduleCache, hasScheduleCache, useScheduleStore } from '@/features/schedule'
import { useSessionStore } from '@/features/session'

let userDataReset: Promise<void> | undefined

export function registerSessionLifecycle(pinia: Pinia) {
  const session = useSessionStore(pinia)
  let previousStatus = session.status

  session.$subscribe(
    (_mutation, state) => {
      const becameAnonymous = previousStatus !== 'anonymous' && state.status === 'anonymous'
      previousStatus = state.status
      if (becameAnonymous) void clearUserData()
    },
    { flush: 'sync' },
  )
}

export async function restoreOfflineAccess() {
  return useSessionStore().restoreOfflineAccess(hasOfflineUserData)
}

export async function checkSession(force = false) {
  const session = useSessionStore()
  const authenticated = await session.check(hasOfflineUserData, force)
  if (session.status === 'anonymous') await clearUserData()
  return authenticated
}

export async function loginSession(username: string, password: string) {
  await useSessionStore().login(username, password)
  // 新账号登录成功后先移除上一会话的本机数据，避免共享设备上串用课表和个人信息。
  await clearUserData()
}

export async function logoutSession() {
  try {
    await useSessionStore().logout()
  } finally {
    await clearUserData()
  }
}

async function clearUserData() {
  useClassroomsStore().clearData()
  useExamsStore().clearData()
  usePlanCompletionStore().clearData()
  useProfileStore().clearData()
  useScheduleStore().clearData()
  if (!userDataReset) {
    userDataReset = Promise.all([
      clearScheduleCache(),
      clearProfileCache(),
      clearClassroomScheduleCache(),
    ])
      .then(() => undefined)
      .catch(() => undefined)
      .finally(() => {
        userDataReset = undefined
      })
  }
  await userDataReset
}

async function hasOfflineUserData() {
  const [hasSchedule, hasProfile, hasClassroomSchedule] = await Promise.all([
    hasScheduleCache().catch(() => false),
    hasProfileCache().catch(() => false),
    hasClassroomScheduleCache().catch(() => false),
  ])
  return hasSchedule || hasProfile || hasClassroomSchedule
}
