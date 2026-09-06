<script setup lang="ts">
import type { CourseBlock, TimeSlot } from '../model/calendar'

defineProps<{
  courses: CourseBlock[]
  selectedWeek: number
  timeSlots: TimeSlot[]
}>()

const emit = defineEmits<{
  select: [course: CourseBlock]
}>()
</script>

<template>
  <div
    class="schedule-grid"
    :aria-label="`第 ${selectedWeek || 1} 周课表`"
    :style="{ gridTemplateRows: `repeat(${timeSlots.length}, minmax(0, 1fr))` }"
  >
    <template v-for="(slot, index) in timeSlots" :key="index">
      <div class="schedule-grid__time" :style="{ gridRow: index + 1 }">
        <strong>{{ index + 1 }}</strong>
        <span>{{ slot[0] }}</span>
        <span>{{ slot[1] }}</span>
      </div>
      <div
        v-for="day in 7"
        :key="`${index}-${day}`"
        class="schedule-grid__cell"
        :style="{ gridColumn: day + 1, gridRow: index + 1 }"
      />
    </template>

    <button
      v-for="course in courses"
      :key="course.id"
      type="button"
      class="course-block"
      :class="[
        `course-block--${course.tone}`,
        {
          'is-muted': course.muted,
          'has-status': course.muted || course.conflict,
        },
      ]"
      :style="{
        gridColumn: course.day + 1,
        gridRow: `${course.start} / span ${course.span}`,
      }"
      :aria-label="`${course.name}，${course.room}${course.conflict ? '，课程冲突' : ''}，查看课程详情`"
      @click="emit('select', course)"
    >
      <strong class="course-block__name">{{ course.name }}</strong>
      <span class="course-block__room">@{{ course.room }}</span>
      <small
        v-if="course.conflict"
        class="course-block__status course-block__status--conflict"
      >
        课程冲突
      </small>
      <small v-else-if="course.muted" class="course-block__status">非本周</small>
    </button>
  </div>
</template>
