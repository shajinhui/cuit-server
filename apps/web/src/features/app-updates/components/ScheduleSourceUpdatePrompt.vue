<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { recordScheduleSourceUpdatePrompt } from '../scheduleSourceUpdate'

defineOptions({ name: 'ScheduleSourceUpdatePrompt' })

const props = defineProps<{
  open: boolean
}>()

const emit = defineEmits<{
  close: []
}>()

const dialog = ref<HTMLElement | null>(null)

watch(
  () => props.open,
  async (open) => {
    if (!open) return
    await nextTick()
    dialog.value?.focus()
  },
  { immediate: true },
)

onMounted(() => document.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown))

function closePrompt() {
  recordScheduleSourceUpdatePrompt()
  emit('close')
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape' && props.open) closePrompt()
}
</script>

<template>
  <Teleport to="body">
    <Transition name="app-update">
      <div v-if="open" class="app-update-backdrop" @click.self="closePrompt">
        <section
          ref="dialog"
          class="app-update-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="schedule-source-update-title"
          aria-describedby="schedule-source-update-description"
          tabindex="-1"
        >
          <div class="app-update-dialog__handle" aria-hidden="true"></div>
          <header>
            <img src="/icons/app-icon-192.png" alt="" />
            <div>
              <p>课表更新</p>
              <h2 id="schedule-source-update-title">课表数据源已升级</h2>
            </div>
          </header>

          <p id="schedule-source-update-description" class="app-update-dialog__description">
            课表已全量切换至学校实验教学系统，实验课程会显示更准确的上课时间与地点。
          </p>
          <p class="app-update-dialog__notice">
            如果仍看到旧课表，请点击课表右上角的同步按钮刷新本机缓存。
          </p>
          <div class="app-update-dialog__actions app-update-dialog__actions--single">
            <button class="app-update-dialog__apply" type="button" @click="closePrompt">
              我知道了
            </button>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
