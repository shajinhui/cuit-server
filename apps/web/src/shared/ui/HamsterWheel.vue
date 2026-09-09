<script setup lang="ts">
withDefaults(defineProps<{ size?: number }>(), { size: 120 })

defineOptions({ name: 'HamsterWheel' })
</script>

<template>
  <div
    class="hamster-wheel"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${size / 12}px` }"
    role="img"
    aria-label="仓鼠在滚轮中奔跑"
  >
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

<style scoped>
.hamster-wheel {
  --dur: 1s;

  position: relative;
  flex: 0 0 auto;
}

.wheel,
.hamster,
.hamster div,
.spoke {
  position: absolute;
}

.wheel,
.spoke {
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border-radius: 50%;
}

.wheel {
  z-index: 2;
  background: radial-gradient(
    100% 100% at center,
    hsla(0, 0%, 60%, 0) 47.8%,
    hsl(0, 0%, 60%) 48%
  );
}

.hamster {
  z-index: 1;
  top: 50%;
  left: calc(50% - 3.5em);
  width: 7em;
  height: 3.75em;
  transform: rotate(4deg) translate(-0.8em, 1.85em);
  transform-origin: 50% 0;
  animation: hamster-run var(--dur) ease-in-out infinite;
}

.hamster__head {
  top: 0;
  left: -2em;
  width: 2.75em;
  height: 2.5em;
  background: hsl(30, 90%, 55%);
  border-radius: 70% 30% 0 100% / 40% 25% 25% 60%;
  box-shadow:
    0 -0.25em 0 hsl(30, 90%, 80%) inset,
    0.75em -1.55em 0 hsl(30, 90%, 90%) inset;
  transform-origin: 100% 50%;
  animation: hamster-head var(--dur) ease-in-out infinite;
}

.hamster__ear {
  top: -0.25em;
  right: -0.25em;
  width: 0.75em;
  height: 0.75em;
  background: hsl(0, 90%, 85%);
  border-radius: 50%;
  box-shadow: -0.25em 0 hsl(30, 90%, 55%) inset;
  transform-origin: 50% 75%;
  animation: hamster-ear var(--dur) ease-in-out infinite;
}

.hamster__eye {
  top: 0.375em;
  left: 1.25em;
  width: 0.5em;
  height: 0.5em;
  background: #000;
  border-radius: 50%;
  animation: hamster-eye var(--dur) linear infinite;
}

.hamster__nose {
  top: 0.75em;
  left: 0;
  width: 0.2em;
  height: 0.25em;
  background: hsl(0, 90%, 75%);
  border-radius: 35% 65% 85% 15% / 70% 50% 50% 30%;
}

.hamster__body {
  top: 0.25em;
  left: 2em;
  width: 4.5em;
  height: 3em;
  background: hsl(30, 90%, 90%);
  border-radius: 50% 30% 50% 30% / 15% 60% 40% 40%;
  box-shadow:
    0.1em 0.75em 0 hsl(30, 90%, 55%) inset,
    0.15em -0.5em 0 hsl(30, 90%, 80%) inset;
  transform-origin: 17% 50%;
  transform-style: preserve-3d;
  animation: hamster-body var(--dur) ease-in-out infinite;
}

.hamster__limb--fr,
.hamster__limb--fl {
  top: 2em;
  left: 0.5em;
  width: 1em;
  height: 1.5em;
  clip-path: polygon(0 0, 100% 0, 70% 80%, 60% 100%, 0% 100%, 40% 80%);
  transform-origin: 50% 0;
}

.hamster__limb--fr {
  background: linear-gradient(hsl(30, 90%, 80%) 80%, hsl(0, 90%, 75%) 80%);
  transform: rotate(15deg) translateZ(-1px);
  animation: hamster-front-right var(--dur) linear infinite;
}

.hamster__limb--fl {
  background: linear-gradient(hsl(30, 90%, 90%) 80%, hsl(0, 90%, 85%) 80%);
  transform: rotate(15deg);
  animation: hamster-front-left var(--dur) linear infinite;
}

.hamster__limb--br,
.hamster__limb--bl {
  top: 1em;
  left: 2.8em;
  width: 1.5em;
  height: 2.5em;
  border-radius: 0.75em 0.75em 0 0;
  clip-path: polygon(0 0, 100% 0, 100% 30%, 70% 90%, 70% 100%, 30% 100%, 40% 90%, 0% 30%);
  transform-origin: 50% 30%;
}

.hamster__limb--br {
  background: linear-gradient(hsl(30, 90%, 80%) 90%, hsl(0, 90%, 75%) 90%);
  transform: rotate(-25deg) translateZ(-1px);
  animation: hamster-back-right var(--dur) linear infinite;
}

.hamster__limb--bl {
  background: linear-gradient(hsl(30, 90%, 90%) 90%, hsl(0, 90%, 85%) 90%);
  transform: rotate(-25deg);
  animation: hamster-back-left var(--dur) linear infinite;
}

.hamster__tail {
  top: 1.5em;
  right: -0.5em;
  width: 1em;
  height: 0.5em;
  background: hsl(0, 90%, 85%);
  border-radius: 0.25em 50% 50% 0.25em;
  box-shadow: 0 -0.2em 0 hsl(0, 90%, 75%) inset;
  transform: rotate(30deg) translateZ(-1px);
  transform-origin: 0.25em 0.25em;
  animation: hamster-tail var(--dur) linear infinite;
}

.spoke {
  background:
    radial-gradient(100% 100% at center, hsl(0, 0%, 60%) 4.8%, hsla(0, 0%, 60%, 0) 5%),
    linear-gradient(
        hsla(0, 0%, 55%, 0) 46.9%,
        hsl(0, 0%, 65%) 47% 52.9%,
        hsla(0, 0%, 65%, 0) 53%
      )
      50% 50% / 99% 99% no-repeat;
  animation: hamster-spoke var(--dur) linear infinite;
}

@keyframes hamster-run {
  from,
  to { transform: rotate(4deg) translate(-0.8em, 1.85em); }
  50% { transform: rotate(0) translate(-0.8em, 1.85em); }
}

@keyframes hamster-head {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(0); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(8deg); }
}

@keyframes hamster-eye {
  from,
  90%,
  to { transform: scaleY(1); }
  95% { transform: scaleY(0); }
}

@keyframes hamster-ear {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(0); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(12deg); }
}

@keyframes hamster-body {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(0); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(-2deg); }
}

@keyframes hamster-front-right {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(50deg) translateZ(-1px); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(-30deg) translateZ(-1px); }
}

@keyframes hamster-front-left {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(-30deg); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(50deg); }
}

@keyframes hamster-back-right {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(-60deg) translateZ(-1px); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(20deg) translateZ(-1px); }
}

@keyframes hamster-back-left {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(20deg); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(-60deg); }
}

@keyframes hamster-tail {
  from,
  25%,
  50%,
  75%,
  to { transform: rotate(30deg) translateZ(-1px); }
  12.5%,
  37.5%,
  62.5%,
  87.5% { transform: rotate(10deg) translateZ(-1px); }
}

@keyframes hamster-spoke {
  from { transform: rotate(0); }
  to { transform: rotate(-1turn); }
}

@media (prefers-reduced-motion: reduce) {
  .hamster-wheel,
  .hamster-wheel * {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
  }
}
</style>
