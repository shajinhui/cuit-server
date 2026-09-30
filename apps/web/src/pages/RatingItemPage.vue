<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import {
  createRatingComment,
  createRequestID,
  deleteRatingComment,
  formatRatingTime,
  getRatingItem,
  listRatingCommentReplies,
  listRatingComments,
  submitItemRating,
  withdrawItemRating,
  type RatingComment,
  type RatingCommentSort,
  type RatingItemDetail,
} from '@/features/ratings'
import {
  RatingAvatar,
  RatingImage,
  RatingPageHeader,
  RatingReportDialog,
  RatingState,
  RatingSummaryCard,
  StarRating,
} from '@/features/ratings/components'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import GlassIconButton from '@/shared/ui/GlassIconButton.vue'
import GlassSegmented from '@/shared/ui/GlassSegmented.vue'
import GlassToolbar from '@/shared/ui/GlassToolbar.vue'

defineOptions({ name: 'RatingItemPage' })

const route = useRoute()
const router = useRouter()
const itemID = computed(() => String(route.params.itemId ?? ''))
const item = ref<RatingItemDetail | null>(null)
const comments = ref<RatingComment[]>([])
const replies = ref<Record<string, RatingComment[]>>({})
const expandedReplies = ref(new Set<string>())
const commentSort = ref<RatingCommentSort>('newest')
const loading = ref(true)
const commentsLoading = ref(false)
const error = ref('')
const commentError = ref('')
const ratingError = ref('')
const selectedStars = ref(0)
const ratingSubmitting = ref(false)
const commentBody = ref('')
const commentSubmitting = ref(false)
const replyTarget = ref<RatingComment | null>(null)
const nextCommentCursor = ref<string | null>(null)
const hasMoreComments = ref(false)
const reportTarget = ref<{ type: 'item' | 'comment'; id: string } | null>(null)
const notice = ref('')
let commentRequestID = createRequestID()
let commentRequestVersion = 0
let noticeTimer: number | undefined

const commentLength = computed(() => Array.from(commentBody.value.trim()).length)
const canSubmitComment = computed(
  () => commentLength.value >= 1 && commentLength.value <= 1000 && !commentSubmitting.value,
)
const activeRating = computed(() =>
  item.value?.my_rating?.status === 'active' ? item.value.my_rating : null,
)
const ratingChanged = computed(() => selectedStars.value !== (activeRating.value?.stars ?? 0))

usePageTheme('bg-page')
onMounted(() => void loadPage())
onBeforeUnmount(() => window.clearTimeout(noticeTimer))

async function loadPage() {
  loading.value = true
  error.value = ''
  // Comments have their own loading state and must not delay the item or its image.
  void loadComments(true)
  try {
    const loaded = await getRatingItem(itemID.value)
    item.value = loaded
    selectedStars.value = loaded.my_rating?.status === 'active' ? loaded.my_rating.stars : 0
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '评分对象加载失败'
  } finally {
    loading.value = false
  }
}

async function submitRating() {
  if (!item.value || item.value.capabilities?.can_rate === false || selectedStars.value < 1 || !ratingChanged.value || ratingSubmitting.value) return
  ratingSubmitting.value = true
  ratingError.value = ''
  try {
    const result = await submitItemRating(
      item.value.id,
      selectedStars.value,
      item.value.my_rating?.version ?? 0,
    )
    item.value.rating = result.rating
    item.value.my_rating = result.my_rating
  } catch (reason) {
    ratingError.value = reason instanceof Error ? reason.message : '评分提交失败'
  } finally {
    ratingSubmitting.value = false
  }
}

async function withdrawRating() {
  if (!item.value || !activeRating.value || ratingSubmitting.value) return
  ratingSubmitting.value = true
  ratingError.value = ''
  try {
    const result = await withdrawItemRating(item.value.id, activeRating.value.version)
    item.value.rating = result.rating
    item.value.my_rating = null
    selectedStars.value = 0
  } catch (reason) {
    ratingError.value = reason instanceof Error ? reason.message : '评分撤回失败'
  } finally {
    ratingSubmitting.value = false
  }
}

async function loadComments(reset: boolean) {
  if (!reset && !hasMoreComments.value) return
  const version = ++commentRequestVersion
  commentsLoading.value = true
  commentError.value = ''
  try {
    const page = await listRatingComments(itemID.value, {
      sort: commentSort.value,
      cursor: reset ? undefined : nextCommentCursor.value ?? undefined,
      limit: 20,
    })
    if (version !== commentRequestVersion) return
    comments.value = reset
      ? page.items
      : Array.from(new Map([...comments.value, ...page.items].map((entry) => [entry.id, entry])).values())
    nextCommentCursor.value = page.next_cursor
    hasMoreComments.value = page.has_more
  } catch (reason) {
    if (version !== commentRequestVersion) return
    commentError.value = reason instanceof Error ? reason.message : '评论加载失败'
  } finally {
    if (version === commentRequestVersion) commentsLoading.value = false
  }
}

function changeCommentSort(value: RatingCommentSort) {
  if (commentSort.value === value) return
  commentSort.value = value
  void loadComments(true)
}

function beginReply(comment: RatingComment) {
  replyTarget.value = comment
  commentBody.value = ''
  requestAnimationFrame(() => document.querySelector<HTMLTextAreaElement>('#rating-comment-input')?.focus())
}

async function submitComment() {
  if (!item.value || !canSubmitComment.value) return
  commentSubmitting.value = true
  commentError.value = ''
  try {
    const created = await createRatingComment(item.value.id, {
      body: commentBody.value.trim(),
      parent_id: replyTarget.value?.id,
      create_request_id: commentRequestID,
    })
    if (replyTarget.value) {
      const rootID = replyTarget.value.id
      replies.value[rootID] = [...(replies.value[rootID] ?? []), created]
      expandedReplies.value = new Set(expandedReplies.value).add(rootID)
      const root = comments.value.find((entry) => entry.id === rootID)
      if (root) root.reply_count += 1
    } else if (commentSort.value === 'newest') {
      comments.value.unshift(created)
    } else {
      comments.value.push(created)
    }
    if (!created.parent_id) item.value.comment_count += 1
    commentBody.value = ''
    replyTarget.value = null
    commentRequestID = createRequestID()
  } catch (reason) {
    commentError.value = reason instanceof Error ? reason.message : '评论发布失败'
  } finally {
    commentSubmitting.value = false
  }
}

async function toggleReplies(comment: RatingComment) {
  const next = new Set(expandedReplies.value)
  if (next.has(comment.id)) {
    next.delete(comment.id)
    expandedReplies.value = next
    return
  }
  if (!replies.value[comment.id]) {
    try {
      const page = await listRatingCommentReplies(comment.id, { limit: 50 })
      replies.value[comment.id] = page.items
    } catch (reason) {
      commentError.value = reason instanceof Error ? reason.message : '回复加载失败'
      return
    }
  }
  next.add(comment.id)
  expandedReplies.value = next
}

async function removeComment(comment: RatingComment, rootID?: string) {
  if (!comment.capabilities?.can_delete) return
  try {
    await deleteRatingComment(comment.id, comment.version)
    if (rootID) {
      replies.value[rootID] = (replies.value[rootID] ?? []).filter((entry) => entry.id !== comment.id)
    } else {
      comments.value = comments.value.filter((entry) => entry.id !== comment.id)
    }
    if (item.value && !rootID) item.value.comment_count = Math.max(0, item.value.comment_count - 1)
  } catch (reason) {
    commentError.value = reason instanceof Error ? reason.message : '评论删除失败'
  }
}

function showNotice() {
  notice.value = '举报已提交'
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 2200)
}
</script>

<template>
  <main class="ratings-page ratings-page--with-composer ratings-item-page">
    <RatingPageHeader title="评分详情" @back="item ? router.push({ name: 'rating-board', params: { boardId: item.board_id } }) : router.back()">
      <GlassIconButton v-if="item" class="ratings-icon-button" aria-label="举报对象" @click="reportTarget = { type: 'item', id: item.id }">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M6 21V4m0 0c4-3 8 3 12 0v10c-4 3-8-3-12 0" /></svg>
      </GlassIconButton>
    </RatingPageHeader>

    <RatingState v-if="loading" title="正在加载评分详情" loading />
    <RatingState v-else-if="error || !item" title="无法打开这个评分对象" :description="error" action-label="重新加载" @action="loadPage" />

    <template v-else>
      <section class="rating-item-hero">
        <RatingImage :asset="item.image_asset" :alt="item.name" />
        <div>
          <h1>{{ item.name }}</h1>
          <span><RatingAvatar :author="item.creator" />{{ item.creator.display_name }} 添加</span>
          <RouterLink :to="{ name: 'rating-board', params: { boardId: item.board.id } }">{{ item.board.title }} ›</RouterLink>
        </div>
        <p v-if="item.description" class="rating-hero-description">{{ item.description }}</p>
      </section>

      <div class="ratings-detail-content">
        <RatingSummaryCard :summary="item.rating">
          <section class="rating-action-card" aria-label="我的评分">
            <div class="rating-action-card__selection">
              <h2>{{ item.my_rating?.status === 'excluded' ? '评分已排除' : activeRating ? `已评 ${activeRating.stars * 2} 分` : '立即评分' }}</h2>
              <StarRating v-model="selectedStars" :disabled="ratingSubmitting || item.capabilities?.can_rate === false" compact />
            </div>
            <p v-if="item.my_rating?.status === 'excluded'">这份评分当前为只读状态，如有疑问请联系管理员。</p>
            <p v-if="ratingError" role="alert">{{ ratingError }}</p>
            <div v-if="activeRating || ratingChanged" class="rating-action-card__buttons">
              <button v-if="activeRating" type="button" class="is-secondary" :disabled="ratingSubmitting" @click="withdrawRating">撤回评分</button>
              <button v-if="ratingChanged && selectedStars > 0 && item.capabilities?.can_rate !== false" type="button" :disabled="ratingSubmitting" @click="submitRating">{{ ratingSubmitting ? '正在保存…' : `${activeRating ? '更新' : '提交'}评分 · ${selectedStars * 2} 分` }}</button>
            </div>
          </section>
        </RatingSummaryCard>

        <section class="rating-comments">
          <header class="ratings-section-heading ratings-section-heading--inline">
            <h2>全部评论 <span class="ratings-section-count">/ {{ item.comment_count }}</span></h2>
            <GlassSegmented
              class="ratings-segment"
              :model-value="commentSort"
              :options="[{ value: 'newest', label: '最新' }, { value: 'oldest', label: '最早' }] as const"
              aria-label="评论排序"
              @update:model-value="changeCommentSort"
            />
          </header>
          <p v-if="commentError" class="ratings-inline-error" role="alert">{{ commentError }}</p>
          <RatingState v-if="commentsLoading && comments.length === 0" title="正在加载评论" loading />
          <RatingState v-else-if="comments.length === 0" title="还没有评论" description="说说你对这个对象的看法。" />
          <div v-else class="rating-comment-list">
            <article v-for="comment in comments" :key="comment.id" class="rating-comment">
              <RatingAvatar :author="comment.author" />
              <div>
                <header>
                  <strong>{{ comment.author.display_name }}</strong>
                  <span v-if="comment.stars_snapshot" class="rating-comment__stars" role="img" :aria-label="`发言时评分 ${comment.stars_snapshot * 2} 分`"><span aria-hidden="true">{{ '★'.repeat(comment.stars_snapshot) }}<span class="rating-comment__empty-stars">{{ '★'.repeat(5 - comment.stars_snapshot) }}</span></span></span>
                </header>
                <p>{{ comment.body }}</p>
                <footer>
                  <time>{{ formatRatingTime(comment.created_at) }}</time>
                  <button type="button" @click="beginReply(comment)">回复</button>
                  <button type="button" @click="reportTarget = { type: 'comment', id: comment.id }">举报</button>
                  <button v-if="comment.capabilities?.can_delete" type="button" @click="removeComment(comment)">删除</button>
                </footer>
                <button v-if="comment.reply_count" type="button" class="rating-comment__replies-button" @click="toggleReplies(comment)">{{ expandedReplies.has(comment.id) ? '收起回复' : `查看 ${comment.reply_count} 条回复` }}</button>
                <div v-if="expandedReplies.has(comment.id)" class="rating-replies">
                  <article v-for="reply in replies[comment.id] ?? []" :key="reply.id">
                    <RatingAvatar :author="reply.author" />
                    <div><strong>{{ reply.author.display_name }}</strong><p>{{ reply.body }}</p><footer><time>{{ formatRatingTime(reply.created_at) }}</time><button type="button" @click="reportTarget = { type: 'comment', id: reply.id }">举报</button><button v-if="reply.capabilities?.can_delete" type="button" @click="removeComment(reply, comment.id)">删除</button></footer></div>
                  </article>
                </div>
              </div>
            </article>
            <button v-if="hasMoreComments" type="button" class="ratings-load-more" :disabled="commentsLoading" @click="loadComments(false)">{{ commentsLoading ? '正在加载…' : '加载更多评论' }}</button>
          </div>
        </section>
      </div>

      <GlassToolbar as="form" class="rating-comment-composer" :corner-radius="24" @submit.prevent="submitComment">
        <div v-if="replyTarget" class="rating-comment-composer__reply">回复 {{ replyTarget.author.display_name }}<button type="button" aria-label="取消回复" @click="replyTarget = null">×</button></div>
        <div>
          <textarea id="rating-comment-input" v-model="commentBody" rows="1" maxlength="1000" :placeholder="replyTarget ? '写下回复…' : '写下你的看法…'" aria-label="评论内容" />
          <button type="submit" :disabled="!canSubmitComment">{{ commentSubmitting ? '发送中' : '发送' }}</button>
        </div>
      </GlassToolbar>
      <RatingReportDialog
        :open="Boolean(reportTarget)"
        :target-type="reportTarget?.type ?? 'item'"
        :target-id="reportTarget?.id ?? item.id"
        @close="reportTarget = null"
        @submitted="showNotice"
      />
      <div v-if="notice" class="ratings-toast" role="status">{{ notice }}</div>
    </template>
  </main>
</template>
