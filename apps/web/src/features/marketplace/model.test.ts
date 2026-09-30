import { describe, expect, it } from 'vitest'
import { formatPrice, parsePriceCents, validContact } from './model'

describe('marketplace prices', () => {
  it.each([['0.01', 1], ['0.29', 29], ['19.90', 1990], ['29', 2900], ['99999.99', 9999999]])('converts %s to exact integer cents', (value, cents) => {
    expect(parsePriceCents(value)).toBe(cents)
  })
  it.each(['', '0', '-1', '1.001', '1e3', '1,000', '100000', 'Infinity', '1.'])('rejects invalid prices %s', (value) => {
    expect(parsePriceCents(value)).toBeNull()
  })
  it('displays cents without hiding precision', () => {
    expect(formatPrice(1)).toBe('0.01')
    expect(formatPrice(1990)).toBe('19.9')
    expect(formatPrice(2900)).toBe('29')
  })
})

describe('seller contact validation', () => {
  it('requires a valid phone or QQ number and a nonempty WeChat account', () => {
    expect(validContact('phone', '13800000000')).toBe(true)
    expect(validContact('phone', '123')).toBe(false)
    expect(validContact('qq', '12345678')).toBe(true)
    expect(validContact('qq', 'abcd')).toBe(false)
    expect(validContact('wechat', 'test_seller')).toBe(true)
    expect(validContact('wechat', ' ')).toBe(false)
    expect(validContact('wechat', 'two words')).toBe(false)
  })
})
