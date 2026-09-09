<script setup lang="ts">
defineOptions({ name: 'HamsterWheel' })
</script>

<template>
  <div class="autorun-loading__wheel" role="img" aria-label="仓鼠在滚轮中奔跑">
    <div class="wheel" />
    <div class="hamster">
      <div class="hamster__body">
        <div class="hamster__head">
          <div class="hamster__ear" />
          <div class="hamster__eye" />
          <div class="hamster__nose" />
        </div>
        <div class="hamster__limb hamster__limb--fr" />
        <div class="hamster__limb hamster__limb--fl" />
        <div class="hamster__limb hamster__limb--br" />
        <div class="hamster__limb hamster__limb--bl" />
        <div class="hamster__tail" />
      </div>
    </div>
    <div class="spoke" />
  </div>
</template>
