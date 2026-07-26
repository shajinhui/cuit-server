<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import AppSelect from '@/shared/ui/AppSelect.vue'

import type { ManualCourseInput, ManualCourseRepeat } from '../model/manualCourse'

defineOptions({ name: 'AddCourseSheet' })

const props = defineProps<{
  open: boolean
  selectedWeek: number
  selectedWeekday: number
  weekCount: number
  sectionsPerDay: number
  saving: boolean
  error: string
}>()

const emit = defineEmits<{
  close: []
  submit: [input: ManualCourseInput]
}>()

const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
const weekdayOptions = weekdays.map((label, index) => ({ value: index + 1, label }))
const repeats: Array<{ value: ManualCourseRepeat; label: string }> = [
  { value: 'weekly', label: '每周' },
  { value: 'odd', label: '单周' },
  { value: 'even', label: '双周' },
]

const name = ref('')
const room = ref('')
const weekday = ref(1)
const startSection = ref(1)
const endSection = ref(2)
const startWeek = ref(1)
const endWeek = ref(1)
const repeat = ref<ManualCourseRepeat>('weekly')
const localError = ref('')

const maximumWeek = computed(() => Math.max(props.weekCount, props.selectedWeek, 1))
const maximumSection = computed(() => Math.max(props.sectionsPerDay, 11))
const weekOptions = computed(() => Array.from({ length: maximumWeek.value }, (_, index) => index + 1))
const sectionOptions = computed(() =>
  Array.from({ length: maximumSection.value }, (_, index) => index + 1),
)
const sectionSelectOptions = computed(() =>
  sectionOptions.value.map((section) => ({ value: section, label: `第 ${section} 节` })),
)
const weekSelectOptions = computed(() =>
  weekOptions.value.map((week) => ({ value: week, label: `第 ${week} 周` })),
)
const errorMessage = computed(() => props.error || localError.value)

watch(
  () => props.open,
  (open) => {
    if (!open) return
    name.value = ''
    room.value = ''
    weekday.value = props.selectedWeekday
    startSection.value = 1
    endSection.value = 2
    startWeek.value = 1
    endWeek.value = maximumWeek.value
    repeat.value = 'weekly'
    localError.value = ''
  },
)

function close() {
  if (!props.saving) emit('close')
}

function submit() {
  localError.value = ''
  if (!name.value.trim()) {
    localError.value = '请输入课程名称'
    return
  }
  if (endSection.value < startSection.value) {
    localError.value = '结束节次不能早于开始节次'
    return
  }
  if (endWeek.value < startWeek.value) {
    localError.value = '结束周不能早于开始周'
    return
  }

  emit('submit', {
    name: name.value,
    room: room.value,
    weekday: weekday.value,
    startSection: startSection.value,
    endSection: endSection.value,
    startWeek: startWeek.value,
    endWeek: endWeek.value,
    repeat: repeat.value,
  })
}
</script>

<template>
  <Teleport to="body">
    <Transition name="add-course-sheet" appear>
      <div v-if="open" class="add-course-sheet-backdrop" @pointerdown.self="close">
        <section
          class="add-course-sheet"
          role="dialog"
          aria-modal="true"
          aria-labelledby="add-course-title"
          @keydown.esc="close"
        >
          <div class="add-course-sheet__grabber" aria-hidden="true" />
          <header class="add-course-sheet__header">
            <button type="button" :disabled="saving" @click="close">取消</button>
            <h2 id="add-course-title">添加课程</h2>
            <button type="button" class="is-primary" :disabled="saving" @click="submit">
              {{ saving ? '保存中' : '添加' }}
            </button>
          </header>

          <form class="add-course-form" @submit.prevent="submit">
            <div class="add-course-form__group">
              <label>
                <span>课程名称</span>
                <input
                  v-model="name"
                  name="course-name"
                  autocomplete="off"
                  enterkeyhint="next"
                  maxlength="40"
                  placeholder="例如：高等数学"
                />
              </label>
              <label>
                <span>上课地点</span>
                <input
                  v-model="room"
                  name="course-room"
                  autocomplete="off"
                  enterkeyhint="done"
                  maxlength="30"
                  placeholder="选填"
                />
              </label>
            </div>

            <div class="add-course-form__group">
              <label>
                <span>星期</span>
                <AppSelect
                  v-model="weekday"
                  :options="weekdayOptions"
                  title="选择星期"
                  aria-label="选择星期"
                />
              </label>
              <div class="add-course-form__split-row">
                <label>
                  <span>开始节次</span>
                  <AppSelect
                    v-model="startSection"
                    :options="sectionSelectOptions"
                    title="选择开始节次"
                    aria-label="选择开始节次"
                  />
                </label>
                <label>
                  <span>结束节次</span>
                  <AppSelect
                    v-model="endSection"
                    :options="sectionSelectOptions"
                    title="选择结束节次"
                    aria-label="选择结束节次"
                  />
                </label>
              </div>
            </div>

            <div class="add-course-form__group">
              <div class="add-course-form__split-row">
                <label>
                  <span>开始周</span>
                  <AppSelect
                    v-model="startWeek"
                    :options="weekSelectOptions"
                    title="选择开始周"
                    aria-label="选择开始周"
                  />
                </label>
                <label>
                  <span>结束周</span>
                  <AppSelect
                    v-model="endWeek"
                    :options="weekSelectOptions"
                    title="选择结束周"
                    aria-label="选择结束周"
                  />
                </label>
              </div>
              <div class="add-course-form__repeat" role="group" aria-label="上课周次规则">
                <button
                  v-for="item in repeats"
                  :key="item.value"
                  type="button"
                  :class="{ 'is-active': repeat === item.value }"
                  :aria-pressed="repeat === item.value"
                  @click="repeat = item.value"
                >
                  {{ item.label }}
                </button>
              </div>
            </div>

            <p v-if="errorMessage" class="add-course-form__error" role="alert">{{ errorMessage }}</p>
            <p class="add-course-form__note">手动课程仅保存在本机，不会修改教务系统课表。</p>
          </form>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
