import { ratingsRequest } from '@/features/ratings/client'
import type { RatingAuthor } from '@/features/ratings/model'

export interface CommunityProfile extends RatingAuthor {
  avatar_asset_id: string | null
  profile_version: number
}

const base = '/api/v1/ratings/community'
export const getCommunityProfile = () => ratingsRequest<CommunityProfile>(`${base}/me/profile`, { cache: 'no-store' })
export const updateCommunityProfile = (input: { display_name: string; avatar_preset: number; avatar_asset_id: string | null; expected_version: number }) =>
  ratingsRequest<CommunityProfile>(`${base}/me/profile`, { method: 'PATCH', cache: 'no-store', body: JSON.stringify(input) })
