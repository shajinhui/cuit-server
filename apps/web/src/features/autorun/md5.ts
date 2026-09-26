const SHIFT_AMOUNTS: readonly number[] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

const ROUND_CONSTANTS: readonly number[] = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
  0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
  0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
  0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
  0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
  0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
  0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
  0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
]

function rotateLeft(value: number, amount: number): number {
  return ((value << amount) | (value >>> (32 - amount))) >>> 0
}

function readWord(bytes: Uint8Array, offset: number): number {
  return (
    (bytes[offset] ?? 0) |
    ((bytes[offset + 1] ?? 0) << 8) |
    ((bytes[offset + 2] ?? 0) << 16) |
    ((bytes[offset + 3] ?? 0) << 24)
  )
}

function wordToHex(value: number): string {
  return [value & 0xff, (value >>> 8) & 0xff, (value >>> 16) & 0xff, (value >>> 24) & 0xff]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

/** MD5 is required by the unirun login protocol; it is not used for storage. */
export function md5Hex(input: string): string {
  const source = new TextEncoder().encode(input)
  const paddedLength = (((source.length + 9) + 63) >> 6) << 6
  const bytes = new Uint8Array(paddedLength)
  bytes.set(source)
  bytes[source.length] = 0x80

  const bitLength = source.length * 8
  const view = new DataView(bytes.buffer)
  view.setUint32(paddedLength - 8, bitLength >>> 0, true)
  view.setUint32(paddedLength - 4, Math.floor(bitLength / 0x1_0000_0000) >>> 0, true)

  let a0 = 0x67452301
  let b0 = 0xefcdab89
  let c0 = 0x98badcfe
  let d0 = 0x10325476

  for (let offset = 0; offset < bytes.length; offset += 64) {
    let a = a0
    let b = b0
    let c = c0
    let d = d0

    for (let i = 0; i < 64; i += 1) {
      let functionValue: number
      let wordIndex: number
      if (i < 16) {
        functionValue = (b & c) | (~b & d)
        wordIndex = i
      } else if (i < 32) {
        functionValue = (d & b) | (~d & c)
        wordIndex = (5 * i + 1) % 16
      } else if (i < 48) {
        functionValue = b ^ c ^ d
        wordIndex = (3 * i + 5) % 16
      } else {
        functionValue = c ^ (b | ~d)
        wordIndex = (7 * i) % 16
      }

      const previousD = d
      const messageWord = readWord(bytes, offset + wordIndex * 4)
      const sum = (a + functionValue + (ROUND_CONSTANTS[i] ?? 0) + messageWord) >>> 0
      d = c
      c = b
      b = (b + rotateLeft(sum, SHIFT_AMOUNTS[i] ?? 0)) >>> 0
      a = previousD
    }

    a0 = (a0 + a) >>> 0
    b0 = (b0 + b) >>> 0
    c0 = (c0 + c) >>> 0
    d0 = (d0 + d) >>> 0
  }

  return wordToHex(a0) + wordToHex(b0) + wordToHex(c0) + wordToHex(d0)
}

/** The upstream login endpoint expects the password's MD5 digest. */
export function md5Password(password: string): string {
  return md5Hex(password)
}
