import rawMap from './map.json'

const EARTH_RADIUS_METERS = 6_371_000
const MAX_TRACK_HOPS = 10_000
const MAX_TRACK_DISTANCE_METERS = 100_000

export interface TrackLocation {
  id: number
  location: string
  edge: number[]
}

export type RandomSource = () => number

function secureRandom(): number {
  const value = new Uint32Array(1)
  globalThis.crypto.getRandomValues(value)
  return (value[0] ?? 0) / 0x1_0000_0000
}

function randomInt(maxExclusive: number, random: RandomSource): number {
  if (maxExclusive <= 1) return 0
  return Math.min(maxExclusive - 1, Math.floor(random() * maxExclusive))
}

/** Load the campus path bundled with the feature and validate its graph indices. */
export function loadTrackMap(): TrackLocation[] {
  return parseTrackMap(rawMap)
}

export function parseTrackMap(value: unknown): TrackLocation[] {
  if (!Array.isArray(value) || value.length === 0) throw new Error('map.json 为空或格式无效')

  const locations: TrackLocation[] = []
  for (const entry of value) {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
      throw new Error('map.json 节点格式无效')
    }
    if (!('id' in entry) || !('location' in entry) || !('edge' in entry)) {
      throw new Error('map.json 节点字段缺失')
    }

    const id = entry.id
    const location = entry.location
    const edge = entry.edge
    if (
      typeof id !== 'number' ||
      !Number.isInteger(id) ||
      typeof location !== 'string' ||
      !/^[-+]?\d+(?:\.\d+)?\s*,\s*[-+]?\d+(?:\.\d+)?$/.test(location) ||
      !isIntegerArray(edge)
    ) {
      throw new Error('map.json 节点字段无效')
    }
    locations.push({ id, location, edge })
  }

  for (const location of locations) {
    for (const edge of location.edge) {
      if (edge < 0 || edge >= locations.length) throw new Error('map.json edge 索引越界')
    }
  }
  return locations
}

/**
 * Generate the upstream track-point wire format. Randomness is injectable for
 * deterministic tests; production uses Web Crypto and does not use randomness
 * for authentication.
 */
export function generateTrack(
  distance: number,
  locations: readonly TrackLocation[],
  random: RandomSource = secureRandom,
  now = new Date(),
): string {
  if (!Number.isSafeInteger(distance) || distance <= 0 || distance > MAX_TRACK_DISTANCE_METERS) {
    throw new Error('跑步距离无效')
  }
  if (locations.length === 0) throw new Error('轨迹地图为空')

  let currentDistance = 0
  const initial = locations[randomInt(locations.length, random)] ?? locations[0]
  if (initial === undefined) throw new Error('轨迹地图为空')

  let current = initial
  let startTime = now.getTime() - 30 * 60 * 1000
  let lastIndex = -1
  let hops = 0
  const result: string[] = []
  let currentCoords = parseCoords(current.location)
  result.push(formatPoint(currentCoords, startTime, randomAccuracy(random)))

  while (currentDistance < distance && hops < MAX_TRACK_HOPS) {
    const edges = current.edge
    if (edges.length === 0) break

    const randomPosition = randomInt(edges.length, random)
    let edgeIndex = edges[randomPosition] ?? edges[0] ?? -1
    if (edgeIndex === lastIndex && edges.length > 1) {
      edgeIndex = edges[(randomPosition + 1) % edges.length] ?? edgeIndex
    }
    if (edgeIndex < 0 || edgeIndex >= locations.length) break

    const next = locations[edgeIndex]
    if (next === undefined) break
    const endCoords = parseCoords(next.location)
    currentDistance += calculateDistance(currentCoords, endCoords)

    let lastRandomPosition = currentCoords
    for (let index = 0; index < 10; index += 1) {
      const newPosition = randomPositionOnSegment(lastRandomPosition, endCoords, random)
      const segmentDistance = calculateDistance(lastRandomPosition, newPosition)
      lastRandomPosition = newPosition
      const speed = randomInt(4, random) + 1
      startTime += Math.trunc((segmentDistance / speed) * 1000)
      result.push(formatPoint(lastRandomPosition, startTime, randomAccuracy(random)))
    }

    const finalDistance = calculateDistance(lastRandomPosition, endCoords)
    const finalSpeed = randomInt(4, random) + 1
    startTime += Math.trunc((finalDistance / finalSpeed) * 1000)
    result.push(formatPoint(endCoords, startTime, randomAccuracy(random)))

    lastIndex = current.id
    current = next
    currentCoords = endCoords
    hops += 1
  }

  startTime += (randomInt(6, random) + 5) * 1000
  result.push(`${current.location.replaceAll(',', '-')}-${startTime}-${randomAccuracy(random).toFixed(1)}`)
  return JSON.stringify(result)
}

/** Haversine distance in meters between [longitude, latitude] pairs. */
export function calculateDistance(start: readonly number[], end: readonly number[]): number {
  if (start.length < 2 || end.length < 2) return 0
  const lat1 = (start[1] ?? 0) * Math.PI / 180
  const lat2 = (end[1] ?? 0) * Math.PI / 180
  const deltaLat = ((end[1] ?? 0) - (start[1] ?? 0)) * Math.PI / 180
  const deltaLng = ((end[0] ?? 0) - (start[0] ?? 0)) * Math.PI / 180
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng / 2) ** 2
  return EARTH_RADIUS_METERS * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function isIntegerArray(value: unknown): value is number[] {
  return Array.isArray(value) && value.every((item: unknown) => typeof item === 'number' && Number.isInteger(item))
}

function parseCoords(value: string): [number, number] {
  const parts = value.split(',')
  const longitude = Number(parts[0]?.trim())
  const latitude = Number(parts[1]?.trim())
  if (!Number.isFinite(longitude) || !Number.isFinite(latitude)) throw new Error('map.json 坐标无效')
  return [longitude, latitude]
}

function randomPositionOnSegment(
  start: readonly number[],
  end: readonly number[],
  random: RandomSource,
): [number, number] {
  const ratio = Math.min(1, Math.max(0, random()))
  return [
    (start[0] ?? 0) + ((end[0] ?? 0) - (start[0] ?? 0)) * ratio,
    (start[1] ?? 0) + ((end[1] ?? 0) - (start[1] ?? 0)) * ratio,
  ]
}

function randomAccuracy(random: RandomSource): number {
  return 10 * Math.min(1, Math.max(0, random()))
}

function formatPoint(coords: readonly number[], timestamp: number, accuracy: number): string {
  return `${(coords[0] ?? 0).toFixed(6)}-${(coords[1] ?? 0).toFixed(6)}-${timestamp}-${accuracy.toFixed(1)}`
}
