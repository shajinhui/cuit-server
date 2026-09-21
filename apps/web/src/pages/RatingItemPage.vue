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
let noticeTimer: number | undefined

const commentLength = computed(() => Array.from(commentBody.value.trim()).length)
const canSubmitComment = computed(
  () => commentLength.value >= 1 && commentLength.value <= 1000 && !commentSubmitting.value,
)
const activeRating = computed(() =>
  item.value?.my_rating?.status === 'active' ? item.value.my_rating : null,
)
const ratingChanged = computed(() => selectedStars.value !== (activeRating.value?.stars ?? 0))

usePageTheme('#f2f2f7')
onMounted(() => void loadPage())
onBeforeUnmount(() => window.clearTimeout(noticeTimer))

async function loadPage() {
  loading.value = true
  error.value = ''
  try {
    const loaded = await getRatingItem(itemID.value)
    item.value = loaded
    selectedStars.value = loaded.my_rating?.status === 'active' ? loaded.my_rating.stars : 0
    await loadComments(true)
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
  commentsLoading.value = true
  commentError.value = ''
  try {
    const page = await listRatingComments(itemID.value, {
      sort: commentSort.value,
      cursor: reset ? undefined : nextCommentCursor.value ?? undefined,
      limit: 20,
    })
    comments.value = reset
      ? page.items
      : Array.from(new Map([...comments.value, ...page.items].map((entry) => [entry.id, entry])).values())
    nextCommentCursor.value = page.next_cursor
    hasMoreComments.value = page.has_more
  } catch (reason) {
    commentError.value = reason instanceof Error ? reason.message : '评论加载失败'
  } finally {
    commentsLoading.value = false
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
  <main class="ratings-page ratings-page--with-composer">
    <RatingPageHeader title="评分详情" @back="item ? router.push({ name: 'rating-board', params: { boardId: item.board_id } }) : router.back()" />

    <RatingState v-if="loading" title="正在加载评分详情" loading />
    <RatingState v-else-if="error || !item" title="无法打开这个评分对象" :description="error" action-label="重新加载" @action="loadPage" />

    <template v-else>
      <section class="rating-item-hero">
        <RatingImage :asset="item.image_asset" :alt="item.name" />
        <div>
          <RouterLink :to="{ name: 'rating-board', params: { boardId: item.board.id } }">{{ item.board.title }} ›</RouterLink>
          <h1>{{ item.name }}</h1>
          <p>{{ item.description || '添加者还没有填写介绍。' }}</p>
          <span><RatingAvatar :author="item.creator" />{{ item.creator.display_name }} 添加</span>
          <button type="button" class="rating-report-link" @click="reportTarget = { type: 'item', id: item.id }">举报对象</button>
        </div>
      </section>

      <div class="ratings-detail-content">
        <RatingSummaryCard :summary="item.rating" />

        <section class="rating-action-card">
          <header><div><small>我的评分</small><h2>{{ item.my_rating?.status === 'excluded' ? '评分已被管理员排除' : activeRating ? `已评 ${activeRating.stars * 2} 分` : '选择星级' }}</h2></div><strong v-if="selectedStars">{{ selectedStars * 2 }}.0</strong></header>
          <StarRating v-model="selectedStars" :disabled="ratingSubmitting || item.capabilities?.can_rate === false" />
          <p v-if="item.my_rating?.status === 'excluded'">这份评分当前为只读状态，如有疑问请联系管理员。</p>
          <p v-if="ratingError" role="alert">{{ ratingError }}</p>
          <div>
            <button v-if="activeRating" type="button" class="is-secondary" :disabled="ratingSubmitting" @click="withdrawRating">撤回评分</button>
            <button v-if="item.capabilities?.can_rate !== false" type="button" :disabled="!ratingChanged || selectedStars === 0 || ratingSubmitting" @click="submitRating">{{ ratingSubmitting ? '正在保存…' : activeRating ? '更新评分' : '提交评分' }}</button>
          </div>
        </section>

        <section class="rating-comments">
          <header class="ratings-section-heading">
            <div><small>讨论</small><h2>全部评论 {{ item.comment_count }}</h2></div>
            <div class="ratings-segment" role="group" aria-label="评论排序">
              <button type="button" :class="{ 'is-active': commentSort === 'newest' }" @click="changeCommentSort('newest')">最新</button>
              <button type="button" :class="{ 'is-active': commentSort === 'oldest' }" @click="changeCommentSort('oldest')">最早</button>
            </div>
          </header>
          <p v-if="commentError" class="ratings-inline-error" role="alert">{{ commentError }}</p>
          <RatingState v-if="commentsLoading && comments.length === 0" title="正在加载评论" loading />
          <RatingState v-else-if="comments.length === 0" title="还没有评论" description="说说你对这个对象的看法。" />
          <div v-else class="rating-comment-list">
            <article v-for="comment in comments" :key="comment.id" class="rating-comment">
              <RatingAvatar :author="comment.author" />
              <div>
                <header><strong>{{ comment.author.display_name }}</strong><span v-if="comment.stars_snapshot">发言时 {{ comment.stars_snapshot * 2 }} 分</span></header>
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

      <form class="rating-comment-composer" @submit.prevent="submitComment">
        <div v-if="replyTarget" class="rating-comment-composer__reply">回复 {{ replyTarget.author.display_name }}<button type="button" aria-label="取消回复" @click="replyTarget = null">×</button></div>
        <div>
          <textarea id="rating-comment-input" v-model="commentBody" rows="1" maxlength="1000" :placeholder="replyTarget ? '写下回复…' : '写下你的看法…'" aria-label="评论内容" />
          <button type="submit" :disabled="!canSubmitComment">{{ commentSubmitting ? '发送中' : '发送' }}</button>
        </div>
      </form>
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
