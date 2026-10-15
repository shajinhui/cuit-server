<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { listAdminAnnouncements, saveAdminAnnouncement, type AdminAnnouncement, type AnnouncementInput, type AnnouncementStatus } from '../api'

const items = ref<AdminAnnouncement[]>([]), loading = ref(false), saving = ref(false), canManage = ref(false)
const error = ref(''), notice = ref(''), cursor = ref<string | null>(null)
const id = ref<string>(crypto.randomUUID()), version = ref(0)
const form = reactive<AnnouncementInput>({ title: '', body: '', platform: 'android', status: 'draft', auto_show: true,
  action: null, starts_at: null, expires_at: null, expected_version: 0 })
const actionLabel = ref(''), actionUrl = ref(''), startsAt = ref(''), expiresAt = ref('')
onMounted(() => void load())
async function load(more = false) {
  if (loading.value) return
  loading.value = true
  error.value = ''
  try { const result = await listAdminAnnouncements(more ? cursor.value ?? undefined : undefined)
    canManage.value = true
    items.value = more ? [...items.value, ...result.items] : result.items
    cursor.value = result.next_cursor
  } catch (reason) { error.value = reason instanceof Error ? reason.message : '公告加载失败' }
  finally { loading.value = false }
}
function edit(item?: AdminAnnouncement) {
  if (saving.value) return
  id.value = item?.id ?? crypto.randomUUID()
  version.value = item?.version ?? 0
  Object.assign(form, { title: item?.title ?? '', body: item?.body ?? '', platform: item?.platform ?? 'android', status: item?.status ?? 'draft', auto_show: item?.auto_show ?? true })
  actionLabel.value = item?.action?.label ?? ''
  actionUrl.value = item?.action?.url ?? ''
  startsAt.value = localDate(item?.starts_at)
  expiresAt.value = localDate(item?.expires_at)
  notice.value = ''; error.value = ''
}
function localDate(value?: string | null) {
  if (!value) return ''
  const date = new Date(value)
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}
async function save(status: AnnouncementStatus) {
  if (saving.value) return
  if (status === 'published' && !window.confirm('确认发布？符合目标平台的用户下次打开或返回 App 时会获取此公告。')) return
  if (status === 'archived' && !window.confirm('确认下架此公告？在线客户端下次检查后将不再展示。')) return
  saving.value = true; error.value = ''; notice.value = ''
  try {
    const input: AnnouncementInput = { ...form, status, expected_version: version.value,
      action: actionUrl.value || actionLabel.value ? { label: actionLabel.value.trim(), url: actionUrl.value.trim() } : null,
      starts_at: startsAt.value ? new Date(startsAt.value).toISOString() : null,
      expires_at: expiresAt.value ? new Date(expiresAt.value).toISOString() : null }
    const saved = await saveAdminAnnouncement(id.value, input)
    version.value = saved.version; form.status = saved.status
    notice.value = status === 'published' ? '公告已发布，无需重新打包 App' : status === 'archived' ? '公告已下架' : '草稿已保存'
    await load()
  } catch (reason) { error.value = reason instanceof Error ? reason.message : '公告保存失败' }
  finally { saving.value = false }
}
</script>

<template>
  <section class="announcement-admin">
    <header><h2>公告管理</h2><button type="button" :disabled="saving || !canManage" @click="edit()">新建公告</button></header>
    <p>按平台发布，自动提醒最多两次。修改并重新发布会生成新版本；内容仅展示纯文本。</p>
    <p v-if="error" role="alert">{{ error }}</p>
    <p v-if="notice" role="status">{{ notice }}</p>
    <form @submit.prevent="save('draft')">
      <fieldset :disabled="saving || !canManage">
        <label>标题<input v-model="form.title" required maxlength="80" /></label>
        <label>正文<textarea v-model="form.body" required maxlength="4000" rows="5" /></label>
        <label>目标平台<select v-model="form.platform"><option value="all">所有平台</option><option value="android">Android</option><option value="ios">iOS</option><option value="ohos">鸿蒙</option><option value="web">Web / PWA</option></select></label>
        <label class="announcement-admin-check"><input v-model="form.auto_show" type="checkbox" />启动时自动提醒（最多两次）</label>
        <label>按钮文字（可选）<input v-model="actionLabel" maxlength="30" /></label>
        <label>按钮 HTTPS 链接（可选）<input v-model="actionUrl" type="url" maxlength="2048" /></label>
        <label>开始时间（本地时间，可选）<input v-model="startsAt" type="datetime-local" /></label>
        <label>结束时间（本地时间，可选）<input v-model="expiresAt" type="datetime-local" /></label>
        <small>当前状态：{{ form.status }} · 版本 {{ version }}</small>
        <footer><button type="submit">保存草稿</button><button type="button" @click="save('published')">{{ saving ? '正在保存…' : '发布公告' }}</button><button v-if="version > 0" type="button" @click="save('archived')">下架</button></footer>
      </fieldset>
    </form>
    <header><h3>已有公告</h3><button type="button" :disabled="loading || saving" @click="load()">刷新</button></header>
    <p v-if="loading">正在加载…</p>
    <p v-else-if="items.length === 0 && !error">暂无公告</p>
    <button v-for="item in items" :key="item.id" class="announcement-admin-item" type="button" :disabled="saving" @click="edit(item)">
      <strong>{{ item.title }}</strong><span>{{ item.platform }} · {{ item.status }} · v{{ item.version }}</span>
    </button>
    <button v-if="cursor" type="button" :disabled="loading" @click="load(true)">加载更多</button>
  </section>
</template>

<style scoped>
.announcement-admin { display: grid; gap: 12px; margin: 18px; padding: 18px; border-radius: 20px; background: var(--bg-surface); color: var(--text-primary); }
.announcement-admin header, .announcement-admin footer { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px; }
.announcement-admin h2, .announcement-admin h3, .announcement-admin p { margin: 0; }
.announcement-admin p, .announcement-admin small, .announcement-admin-item span { color: var(--text-secondary); font-size: 13px; }
.announcement-admin fieldset { display: grid; min-width: 0; gap: 12px; border: 0; padding: 0; }
.announcement-admin label { display: grid; gap: 6px; font-size: 14px; }
.announcement-admin input, .announcement-admin textarea, .announcement-admin select { width: 100%; min-height: 44px; padding: 10px; border: 1px solid var(--line-faint); border-radius: 12px; color: var(--text-primary); background: var(--bg-page); box-sizing: border-box; font: inherit; }
.announcement-admin-check { display: flex !important; align-items: center; }
.announcement-admin-check input { width: 20px; }
.announcement-admin button { min-height: 44px; padding: 8px 14px; color: var(--blue-bright); background: var(--bg-page); border: 0; border-radius: 12px; }
.announcement-admin button:disabled { opacity: .5; }
.announcement-admin-item { display: grid; gap: 6px; text-align: left; }
</style>
