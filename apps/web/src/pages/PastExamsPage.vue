<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import pastExamsIcon from '@/assets/icons/tool-past-exams.png'
import {
  browsePastExamDirectory,
  downloadPastExamFile,
  formatPastExamSize,
  isIOSWebDevice,
  loadPastExamsIndex,
  parentPastExamDirectory,
  pastExamBreadcrumbs,
  pastExamFileDownloadURL,
  pastExamFileKind,
  pastExamFileURL,
  searchPastExamFiles,
  type PastExamBrowserItem,
  type PastExamFile,
  type PastExamsIndex,
} from '@/features/past-exams'
import { usePageTheme } from '@/shared/composables/usePageTheme'
import HamsterLoader from '@/shared/ui/HamsterLoader.vue'

defineOptions({ name: 'PastExamsPage' })

const router = useRouter()
const index = ref<PastExamsIndex>()
const loading = ref(true)
const errorMessage = ref('')
const currentPath = ref('')
const query = ref('')
const downloadingPath = ref('')
const notice = ref('')
const abortController = new AbortController()
let downloadAbortController: AbortController | undefined
let noticeTimer: number | undefined

const searching = computed(() => query.value.trim().length > 0)
const directoryItems = computed(() =>
  index.value ? browsePastExamDirectory(index.value.files, currentPath.value) : [],
)
const searchResults = computed(() =>
  index.value ? searchPastExamFiles(index.value.files, query.value) : [],
)
const breadcrumbs = computed(() => pastExamBreadcrumbs(currentPath.value))
const visibleItemCount = computed(() =>
  searching.value ? searchResults.value.length : directoryItems.value.length,
)
const rootDirectoryCount = computed(() => {
  if (!index.value) return 0
  return browsePastExamDirectory(index.value.files, '').filter((item) => item.type === 'directory')
    .length
})
const currentTitle = computed(() => {
  if (searching.value) return '搜索结果'
  return currentPath.value.split('/').filter(Boolean).at(-1) || '全部课程'
})

usePageTheme('#f2f2f7')

onMounted(() => void loadIndex())
onBeforeUnmount(() => {
  abortController.abort()
  downloadAbortController?.abort()
  window.clearTimeout(noticeTimer)
})

async function loadIndex() {
  loading.value = true
  errorMessage.value = ''
  try {
    index.value = await loadPastExamsIndex(abortController.signal)
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return
    errorMessage.value = error instanceof Error ? error.message : '资料目录读取失败'
  } finally {
    loading.value = false
  }
}

function goBack() {
  if (searching.value) {
    query.value = ''
    return
  }
  if (currentPath.value) {
    currentPath.value = parentPastExamDirectory(currentPath.value)
    scrollToListTop()
    return
  }
  void router.push({ name: 'tools' })
}

function openDirectory(item: PastExamBrowserItem) {
  if (item.type !== 'directory') return
  currentPath.value = item.path
  query.value = ''
  scrollToListTop()
}

function openBreadcrumb(path: string) {
  currentPath.value = path
  query.value = ''
  scrollToListTop()
}

function fileURL(file: PastExamFile) {
  return index.value ? pastExamFileURL(index.value.commit, file) : '#'
}

function fileDownloadURL(file: PastExamFile) {
  return index.value ? pastExamFileDownloadURL(index.value.commit, file) : '#'
}

async function downloadFile(file: PastExamFile) {
  if (downloadingPath.value) return

  downloadingPath.value = file.path
  downloadAbortController = new AbortController()
  try {
    const result = await downloadPastExamFile(
      fileDownloadURL(file),
      file.name,
      downloadAbortController.signal,
    )
    showNotice(result === 'shared' ? '已打开系统存储菜单' : '已开始下载')
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return
    showNotice(error instanceof Error ? error.message : '下载失败，请稍后重试')
  } finally {
    downloadingPath.value = ''
    downloadAbortController = undefined
  }
}

function openFile(event: MouseEvent, file: PastExamFile) {
  if (!isIOSWebDevice()) return
  event.preventDefault()
  void downloadFile(file)
}

function showNotice(message: string) {
  notice.value = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => (notice.value = ''), 2400)
}

function fileLocation(file: PastExamFile) {
  const separator = file.path.lastIndexOf('/')
  return separator < 0 ? '根目录' : file.path.slice(0, separator)
}

function fileExtension(file: PastExamFile) {
  return file.extension.slice(0, 4).toUpperCase()
}

function formatUpdatedAt(value: string) {
  const date = new Date(value)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function scrollToListTop() {
  requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: 'auto' }))
}
</script>

<template>
  <main class="past-exams-page">
    <header class="past-exams-topbar">
      <button type="button" class="past-exams-icon-button" aria-label="返回" @click="goBack">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <div>
        <h1>历年试卷</h1>
        <p>课程资料文件夹</p>
      </div>
      <a
        v-if="index"
        class="past-exams-icon-button"
        :href="index.sourceURL"
        target="_blank"
        rel="noopener noreferrer"
        aria-label="查看资料来源"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17Z" />
          <path d="M9.2 9.2a3.4 3.4 0 1 1 5.6 3.6c-1 .7-2.1 1.2-2.1 2.4" />
          <path d="M12.7 17.4h.01" />
        </svg>
      </a>
      <span v-else aria-hidden="true" />
    </header>

    <div v-if="loading" class="past-exams-state" aria-busy="true">
      <HamsterLoader label="正在整理资料目录…" />
    </div>

    <div v-else-if="errorMessage" class="past-exams-state past-exams-state--error" role="alert">
      <span class="past-exams-state__icon" aria-hidden="true">!</span>
      <strong>目录加载失败</strong>
      <p>{{ errorMessage }}</p>
      <button type="button" @click="loadIndex">重新加载</button>
    </div>

    <template v-else-if="index">
      <section class="past-exams-overview" aria-label="资料库概览">
        <img :src="pastExamsIcon" alt="" />
        <div>
          <small>CUIT SHARING</small>
          <h2>考试资料库</h2>
          <p>{{ rootDirectoryCount }} 个课程目录 · {{ index.totalFiles }} 份资料</p>
        </div>
        <span>{{ formatPastExamSize(index.totalBytes) }}</span>
      </section>

      <label class="past-exams-search">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <circle cx="10.5" cy="10.5" r="6.5" />
          <path d="m15.5 15.5 4 4" />
        </svg>
        <input v-model="query" type="search" placeholder="搜索课程、年份或文件名" aria-label="搜索试卷" />
        <button v-if="query" type="button" aria-label="清空搜索" @click="query = ''">
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m8 8 8 8m0-8-8 8" /></svg>
        </button>
      </label>

      <nav v-if="!searching" class="past-exams-breadcrumbs" aria-label="当前资料路径">
        <template v-for="(crumb, crumbIndex) in breadcrumbs" :key="crumb.path">
          <span v-if="crumbIndex > 0" aria-hidden="true">›</span>
          <button
            type="button"
            :aria-current="crumbIndex === breadcrumbs.length - 1 ? 'page' : undefined"
            @click="openBreadcrumb(crumb.path)"
          >
            {{ crumb.label }}
          </button>
        </template>
      </nav>

      <section class="past-exams-browser" :aria-label="currentTitle">
        <header>
          <div>
            <small>{{ searching ? '全库搜索' : '当前位置' }}</small>
            <h2>{{ currentTitle }}</h2>
          </div>
          <span>{{ visibleItemCount }} 项</span>
        </header>

        <div v-if="visibleItemCount === 0" class="past-exams-empty">
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <path d="M3.5 7.5h6l1.5 2h9.5v9.5a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19V7.5Z" />
            <path d="M6.5 4.5h4l1.5 2" />
          </svg>
          <strong>{{ searching ? '没有找到相关资料' : '这个文件夹是空的' }}</strong>
          <p v-if="searching">试试课程简称、年份或“答案”等关键词。</p>
        </div>

        <div v-else class="past-exams-list">
          <template v-if="searching">
            <div
              v-for="file in searchResults"
              :key="file.path"
              class="past-exams-row past-exams-row--file"
            >
              <a
                class="past-exams-row__open"
                :href="fileURL(file)"
                target="_blank"
                rel="noopener noreferrer"
                @click="openFile($event, file)"
              >
                <span class="past-exams-file-icon" :data-kind="pastExamFileKind(file.extension)">
                  {{ fileExtension(file) }}
                </span>
                <span class="past-exams-row__copy">
                  <strong>{{ file.name }}</strong>
                  <small>{{ fileLocation(file) }} · {{ formatPastExamSize(file.size) }}</small>
                </span>
              </a>
              <button
                type="button"
                class="past-exams-download-button"
                :disabled="Boolean(downloadingPath)"
                :aria-busy="downloadingPath === file.path"
                :aria-label="`下载 ${file.name}`"
                @click="downloadFile(file)"
              >{{ downloadingPath === file.path ? '准备中' : '下载' }}</button>
            </div>
          </template>

          <template v-else>
            <template v-for="item in directoryItems" :key="item.path">
              <button
                v-if="item.type === 'directory'"
                type="button"
                class="past-exams-row"
                @click="openDirectory(item)"
              >
                <span class="past-exams-folder-icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24"><path d="M3.5 7.5h6l1.5 2h9.5v9.5a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19V7.5Z" /></svg>
                </span>
                <span class="past-exams-row__copy">
                  <strong>{{ item.name }}</strong>
                  <small>{{ item.fileCount }} 份资料 · {{ formatPastExamSize(item.totalBytes) }}</small>
                </span>
                <svg class="past-exams-row__chevron" aria-hidden="true" viewBox="0 0 24 24">
                  <path d="m9 5 7 7-7 7" />
                </svg>
              </button>

              <div
                v-else
                class="past-exams-row past-exams-row--file"
              >
                <a
                  class="past-exams-row__open"
                  :href="fileURL(item)"
                  target="_blank"
                  rel="noopener noreferrer"
                  @click="openFile($event, item)"
                >
                  <span class="past-exams-file-icon" :data-kind="pastExamFileKind(item.extension)">
                    {{ fileExtension(item) }}
                  </span>
                  <span class="past-exams-row__copy">
                    <strong>{{ item.name }}</strong>
                    <small>{{ formatPastExamSize(item.size) }}</small>
                  </span>
                </a>
                <button
                  type="button"
                  class="past-exams-download-button"
                  :disabled="Boolean(downloadingPath)"
                  :aria-busy="downloadingPath === item.path"
                  :aria-label="`下载 ${item.name}`"
                  @click="downloadFile(item)"
                >{{ downloadingPath === item.path ? '准备中' : '下载' }}</button>
              </div>
            </template>
          </template>
        </div>
      </section>

      <footer class="past-exams-source">
        目录更新于 {{ formatUpdatedAt(index.updatedAt) }}，文件由 Cloudflare 边缘读取 GitHub 源仓库。
      </footer>
    </template>

    <Transition name="toast">
      <div v-if="notice" class="toast-message" role="status">{{ notice }}</div>
    </Transition>
  </main>
</template>
