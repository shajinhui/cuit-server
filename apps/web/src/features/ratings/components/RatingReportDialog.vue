<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createRatingReport } from '../api'

defineOptions({ name: 'RatingReportDialog' })

const props = defineProps<{
  open: boolean
  targetType: 'board' | 'item' | 'comment'
  targetId: string
}>()

const emit = defineEmits<{ close: []; submitted: [] }>()
const reason = ref('')
const submitting = ref(false)
const error = ref('')
const canSubmit = computed(() => {
  const length = Array.from(reason.value.trim()).length
  return length >= 5 && length <= 300 && !submitting.value
})

watch(
  () => props.open,
  (open) => {
    if (!open) return
    reason.value = ''
    error.value = ''
  },
)

async function submit() {
  if (!canSubmit.value) return
  submitting.value = true
  error.value = ''
  try {
    await createRatingReport({
      target_type: props.targetType,
      target_id: props.targetId,
      reason: reason.value.trim(),
    })
    emit('submitted')
    emit('close')
  } catch (reasonValue) {
    error.value = reasonValue instanceof Error ? reasonValue.message : '举报提交失败'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="ratings-sheet">
      <div v-if="open" class="rating-report-backdrop" role="presentation" @click.self="emit('close')">
        <form class="rating-report-dialog" role="dialog" aria-modal="true" aria-labelledby="rating-report-title" @submit.prevent="submit">
          <header>
            <button type="button" @click="emit('close')">取消</button>
            <h2 id="rating-report-title">举报内容</h2>
            <button type="submit" :disabled="!canSubmit">提交</button>
          </header>
          <p>请说明内容存在的问题，管理员会根据实际情况处理。</p>
          <textarea v-model="reason" maxlength="300" rows="5" placeholder="例如：对象重复、名称不准确或包含不当内容（至少 5 个字）" autofocus />
          <small>{{ Array.from(reason.trim()).length }}/300</small>
          <p v-if="error" class="is-error" role="alert">{{ error }}</p>
        </form>
      </div>
    </Transition>
  </Teleport>
</template>
