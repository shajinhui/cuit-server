import { describe, expect, it } from 'vitest'

import {
  AUTORUN_UPSTREAM_PATHS,
  buildAutoRunLoginPayload,
  buildClubActivityMutationQuery,
  buildClubActivityQuery,
  buildClubJoinNumQuery,
  buildClubSignPayload,
  buildRunInfoQuery,
  buildRunStandardQuery,
  buildSchoolBoundQuery,
  buildSignInTaskQuery,
  serializeAutoRunBody,
} from './request'

describe('校园跑上游请求参数', () => {
  it('生成带 MD5 密码的登录请求体且不携带服务器密钥', () => {
    const payload = buildAutoRunLoginPayload('13800000000', 'example-password')
    expect(payload).toMatchObject({
      appVersion: '1.8.5',
      brand: 'Xiaomi',
      deviceType: '1',
      mobileType: 'Mi 11',
      sysVersion: 'Android 11',
      userPhone: '13800000000',
      password: 'cc4436eff149ba9761aaac07b36360ea',
    })
    expect(JSON.stringify(payload)).not.toContain('example-password')
    expect(Object.keys(payload)).not.toContain('appSecret')
  })

  it('按上游协议构造查询参数', () => {
    expect(buildSchoolBoundQuery(33)).toEqual({ schoolId: '33' })
    expect(buildRunStandardQuery(33)).toEqual({ schoolId: '33' })
    expect(buildRunInfoQuery(11, '2026-1')).toEqual({ userId: '11', yearSemester: '2026-1' })
    expect(buildSignInTaskQuery(22)).toEqual({ studentId: '22' })
    expect(buildClubActivityQuery(22, '2026-09-07', 33)).toEqual({
      queryTime: '2026-09-07',
      studentId: '22',
      schoolId: '33',
      pageNo: '1',
      pageSize: '15',
    })
    expect(buildClubJoinNumQuery(33, 22)).toEqual({ schoolId: '33', studentId: '22' })
    expect(buildClubActivityMutationQuery(22, 456)).toEqual({ studentId: '22', activityId: '456' })
  })

  it('校验并规范化签到请求体', () => {
    expect(
      buildClubSignPayload({
        activityId: 456,
        latitude: 30.123456,
        longitude: '104.123456',
        signType: '1',
        studentId: 22,
      }),
    ).toEqual({
      activityId: 456,
      latitude: '30.123456',
      longitude: '104.123456',
      signType: '1',
      studentId: 22,
    })
    expect(() => buildClubSignPayload({
      activityId: 456,
      latitude: '',
      longitude: '104.1',
      signType: '1',
      studentId: 22,
    })).toThrow('签到坐标格式无效')
  })

  it('保留请求体字节序列并暴露固定上游路径', () => {
    expect(serializeAutoRunBody({ x: 1 })).toBe('{"x":1}')
    expect(AUTORUN_UPSTREAM_PATHS.recordNew).toBe('/v1/unirun/save/run/record/new')
    expect(AUTORUN_UPSTREAM_PATHS.signInOrSignBack).toBe('/v1/clubactivity/signInOrSignBack')
  })
})
