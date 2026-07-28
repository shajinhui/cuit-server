import { request } from '@/shared/api/client'

export type FeedbackType = 'suggestion' | 'bug'
export type FeedbackPlatform = 'android' | 'ios'

export interface FeedbackInput {
  type: FeedbackType
  platform: FeedbackPlatform
  content: string
}

export interface FeedbackReceipt {
  id: number
  created_at: string
}

export function submitFeedback(input: FeedbackInput) {
  return request<FeedbackReceipt>('/api/v1/feedback', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}
