import { afterEach, describe, expect, it, vi } from 'vitest'

import { cachedRatingAssetSource, clearRatingAssetCache } from './assetCache'

afterEach(() => {
  clearRatingAssetCache()
})

describe('rating asset cache', () => {
  it('shares one image request across concurrent and later page renders', async () => {
    const load = vi.fn().mockResolvedValue(new Blob(['rating-image'], { type: 'image/jpeg' }))

    const [first, concurrent] = await Promise.all([
      cachedRatingAssetSource('asset-1', load),
      cachedRatingAssetSource('asset-1', load),
    ])
    const laterPage = await cachedRatingAssetSource('asset-1', load)

    expect(load).toHaveBeenCalledTimes(1)
    expect(concurrent).toBe(first)
    expect(laterPage).toBe(first)
  })

  it('removes failed requests so a later render can retry', async () => {
    const load = vi
      .fn<() => Promise<Blob>>()
      .mockRejectedValueOnce(new Error('network error'))
      .mockResolvedValueOnce(new Blob(['recovered']))

    await expect(cachedRatingAssetSource('asset-2', load)).rejects.toThrow('network error')
    await expect(cachedRatingAssetSource('asset-2', load)).resolves.toMatch(/^blob:/)
    expect(load).toHaveBeenCalledTimes(2)
  })

  it('drops cached object URLs when the rating session is cleared', async () => {
    const revoke = vi.spyOn(URL, 'revokeObjectURL')
    const load = vi.fn().mockResolvedValue(new Blob(['private-image']))
    const first = await cachedRatingAssetSource('asset-3', load)

    clearRatingAssetCache()
    const second = await cachedRatingAssetSource('asset-3', load)

    expect(revoke).toHaveBeenCalledWith(first)
    expect(load).toHaveBeenCalledTimes(2)
    expect(second).not.toBe(first)
  })
})
