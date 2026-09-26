import { describe, expect, it } from 'vitest'

import { md5Hex, md5Password } from './md5'

describe('校园跑 MD5 兼容逻辑', () => {
  it('匹配标准 MD5 向量', () => {
    expect(md5Hex('')).toBe('d41d8cd98f00b204e9800998ecf8427e')
    expect(md5Hex('abc')).toBe('900150983cd24fb0d6963f7d28e17f72')
    expect(md5Password('example-password')).toBe(md5Hex('example-password'))
  })

  it('按 UTF-8 字节计算非 ASCII 输入', () => {
    expect(md5Hex('校园跑')).toBe('908aba5c3353c41e56140c6361bbb549')
  })
})
