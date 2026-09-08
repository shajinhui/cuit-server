<script setup lang="ts">
import AppSelect from '@/shared/ui/AppSelect.vue'

defineOptions({ name: 'CalendarExportSheet' })

defineProps<{
  open: boolean
  semesterLabel: string
  courseCount: number
  eventCount: number
  reminderMinutes: number
  exporting: boolean
  error: string
}>()

const emit = defineEmits<{
  close: []
  export: []
  'update:reminderMinutes': [value: number]
}>()

const reminderOptions = [
  { value: 0, label: '不提醒' },
  { value: 5, label: '提前 5 分钟' },
  { value: 10, label: '提前 10 分钟' },
  { value: 15, label: '提前 15 分钟' },
  { value: 30, label: '提前 30 分钟' },
]
</script>

<template>
  <Teleport to="body">
    <Transition name="add-course-sheet" appear>
      <div v-if="open" class="add-course-sheet-backdrop" @pointerdown.self="emit('close')">
        <section
          class="add-course-sheet calendar-export-sheet"
          role="dialog"
          aria-modal="true"
          aria-labelledby="calendar-export-title"
          @keydown.esc="emit('close')"
        >
          <div class="add-course-sheet__grabber" aria-hidden="true" />
          <header class="add-course-sheet__header">
            <button type="button" :disabled="exporting" @click="emit('close')">取消</button>
            <h2 id="calendar-export-title">导入系统日历</h2>
            <span aria-hidden="true" />
          </header>

          <div class="calendar-export-sheet__body">
            <div class="calendar-export-sheet__summary">
              <span class="calendar-export-sheet__icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <rect x="3.5" y="5" width="17" height="15.5" rx="3" />
                  <path d="M7.5 3.5v3M16.5 3.5v3M3.5 9h17" />
                  <path d="m8.5 15 2.2 2.2 4.8-5" />
                </svg>
              </span>
              <div>
                <strong>{{ semesterLabel }}</strong>
                <p>共 {{ courseCount }} 门课程，生成 {{ eventCount }} 个上课日程</p>
              </div>
            </div>

            <label class="calendar-export-sheet__setting">
              <span>上课提醒</span>
              <AppSelect
                :model-value="reminderMinutes"
                :options="reminderOptions"
                title="选择上课提醒时间"
                aria-label="选择上课提醒时间"
                @change="emit('update:reminderMinutes', Number($event))"
              />
            </label>

            <p v-if="error" class="calendar-export-sheet__error" role="alert">{{ error }}</p>
            <p class="calendar-export-sheet__note">
              将包含教务课程、手动课程和本机修改。系统日历会在下一步让你确认导入。
            </p>
            <button
              type="button"
              class="calendar-export-sheet__submit"
              :disabled="exporting"
              @click="emit('export')"
            >
              <span v-if="exporting" class="calendar-export-sheet__spinner" aria-hidden="true" />
              {{ exporting ? '正在生成…' : '生成并导入' }}
            </button>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
