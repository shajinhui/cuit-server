<script setup lang="ts">
import type { CourseBlock, TimeSlot } from '../model/calendar'

defineProps<{
  courses: CourseBlock[]
  selectedWeek: number
  timeSlots: TimeSlot[]
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

    <article
      v-for="course in courses"
      :key="course.id"
      class="course-block"
      :class="[`course-block--${course.tone}`, { 'is-muted': course.muted }]"
      :style="{
        gridColumn: course.day + 1,
        gridRow: `${course.start} / span ${course.span}`,
      }"
    >
      <strong>{{ course.name }}</strong>
      <span>@{{ course.room }}</span>
      <small v-if="course.muted" class="course-block__status">非本周</small>
    </article>
  </div>
</template>
