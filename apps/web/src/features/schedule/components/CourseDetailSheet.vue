<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'

import type { CourseBlock, CourseSlotCourse } from '../model/calendar'

defineOptions({ name: 'CourseDetailSheet' })

const props = defineProps<{
  course: CourseBlock | null
  removing?: boolean
  removeError?: string
}>()

const emit = defineEmits<{
  close: []
  edit: [course: CourseSlotCourse]
  remove: [courseID: string]
}>()

const detailCard = ref<HTMLElement | null>(null)
const pendingRemoval = ref<CourseSlotCourse | null>(null)
const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

const timeLabel = computed(() => {
  if (!props.course) return ''
  const end = props.course.start + props.course.span - 1
  const sections = end === props.course.start ? `第 ${props.course.start} 节` : `第 ${props.course.start}–${end} 节`
  return `${weekdays[props.course.day - 1] ?? '上课日期待定'} · ${sections}`
})

const detailRows = computed(() => {
  if (!props.course) return []

  if (props.course.courses.length > 1) {
    return [
      { label: '上课时间', value: timeLabel.value },
      {
        label: '课程安排',
        value: props.course.courses.map(formatSlotCourse).join('\n\n'),
      },
    ]
  }

  const arrangementRows =
    props.course.arrangements.length > 1
      ? [
          {
            label: '上课安排',
            value: props.course.arrangements
              .map((arrangement) => `${formatWeeks(arrangement.weeks)} · ${arrangement.room}`)
              .join('\n'),
          },
        ]
      : [
          { label: '上课地点', value: props.course.room },
          { label: '教学周', value: formatWeeks(props.course.weeks) },
        ]

  return [
    { label: '上课时间', value: timeLabel.value },
    ...arrangementRows,
    { label: '任课教师', value: props.course.teachers.join('、') || '教师待定' },
    ...(props.course.code ? [{ label: '课程代码', value: props.course.code }] : []),
    ...(props.course.credits ? [{ label: '学分', value: props.course.credits }] : []),
    ...(props.course.teachingClass ? [{ label: '教学班', value: props.course.teachingClass }] : []),
  ]
})

const removableCourses = computed(() => {
  if (!props.course) return []
  return props.course.courses.filter((course) => course.source === 'manual')
})

const editableCourses = computed(() => props.course?.courses ?? [])

watch(
  () => props.course,
  (course) => {
    pendingRemoval.value = null
    if (course) void nextTick(() => detailCard.value?.focus({ preventScroll: true }))
  },
)

function close() {
  if (props.removing) return
  pendingRemoval.value = null
  emit('close')
}

function requestRemoval(course: CourseSlotCourse) {
  pendingRemoval.value = course
}

function editCourse(course: CourseSlotCourse) {
  if (props.removing) return
  emit('edit', course)
}

function cancelRemoval() {
  if (!props.removing) pendingRemoval.value = null
}

function confirmRemoval() {
  if (!pendingRemoval.value || props.removing) return
  emit('remove', pendingRemoval.value.id)
}

function formatSlotCourse(course: CourseSlotCourse) {
  const arrangements = course.arrangements
    .map((arrangement) => `${formatWeeks(arrangement.weeks)} · ${arrangement.room}`)
    .join('；')
  const teachers = course.teachers.length > 0 ? ` · ${course.teachers.join('、')}` : ''
  return `${course.name}\n${arrangements}${teachers}`
}

function formatWeeks(weeks: number[]) {
  if (weeks.length === 0) return '每周'

  const sortedWeeks = [...new Set(weeks)].sort((left, right) => left - right)
  const ranges: string[] = []
  let rangeStart = sortedWeeks[0]
  let previous = sortedWeeks[0]

  for (const week of sortedWeeks.slice(1)) {
    if (week === previous + 1) {
      previous = week
      continue
    }
    ranges.push(rangeStart === previous ? `${rangeStart}` : `${rangeStart}–${previous}`)
    rangeStart = week
    previous = week
  }
  ranges.push(rangeStart === previous ? `${rangeStart}` : `${rangeStart}–${previous}`)

  return `第 ${ranges.join('、')} 周`
}
</script>

<template>
  <Teleport to="body">
    <Transition name="course-detail-sheet" appear>
      <div
        v-if="course"
        class="course-detail-backdrop"
        role="presentation"
        @pointerdown.self="close"
      >
        <section
          ref="detailCard"
          class="course-detail-card"
          role="dialog"
          aria-modal="true"
          aria-labelledby="course-detail-title"
          tabindex="-1"
          @keydown.esc="close"
        >
          <header class="course-detail-card__header">
            <span
              class="course-detail-card__swatch"
              :class="`course-detail-card__swatch--${course.tone}`"
              aria-hidden="true"
            />
            <div>
              <p>
                {{
                  course.courses.length > 1
                    ? '时段详情'
                    : course.source === 'manual'
                      ? '本机添加'
                      : '课程详情'
                }}
                <span v-if="course.conflict">课程冲突</span>
                <span v-else-if="course.muted">非本周</span>
              </p>
              <h2 id="course-detail-title">{{ course.name }}</h2>
            </div>
            <button type="button" aria-label="关闭课程详情" :disabled="removing" @click="close">
              <svg aria-hidden="true" viewBox="0 0 20 20">
                <path d="m6 6 8 8M14 6l-8 8" />
              </svg>
            </button>
          </header>

          <dl class="course-detail-card__details">
            <div v-for="row in detailRows" :key="row.label">
              <dt>{{ row.label }}</dt>
              <dd>{{ row.value }}</dd>
            </div>
          </dl>

          <div v-if="editableCourses.length > 0" class="course-detail-card__actions">
            <template v-if="pendingRemoval">
              <p>
                确定删除“{{ pendingRemoval.name }}”吗？
                <small>删除后无法恢复。</small>
              </p>
              <div>
                <button type="button" :disabled="removing" @click="cancelRemoval">取消</button>
                <button
                  type="button"
                  class="is-destructive"
                  :disabled="removing"
                  @click="confirmRemoval"
                >
                  {{ removing ? '正在删除…' : '确认删除' }}
                </button>
              </div>
            </template>
            <template v-else>
              <button
                v-for="editableCourse in editableCourses"
                :key="`edit-${editableCourse.id}`"
                type="button"
                class="course-detail-card__edit"
                @click="editCourse(editableCourse)"
              >
                {{
                  editableCourses.length > 1
                    ? `修改“${editableCourse.name}”`
                    : '修改课程'
                }}
              </button>
              <button
                v-for="manualCourse in removableCourses"
                :key="`remove-${manualCourse.id}`"
                type="button"
                class="course-detail-card__delete"
                @click="requestRemoval(manualCourse)"
              >
                {{
                  removableCourses.length > 1
                    ? `删除“${manualCourse.name}”`
                    : '删除本机课程'
                }}
              </button>
            </template>
            <p v-if="removeError" class="course-detail-card__remove-error" role="alert">
              {{ removeError }}
            </p>
          </div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>
