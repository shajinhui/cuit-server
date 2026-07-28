<script setup lang="ts">
import { useRouter } from 'vue-router'

import { usePageTheme } from '@/shared/composables/usePageTheme'

defineOptions({ name: 'PrivacyPage' })

const router = useRouter()
const repositoryIssuesURL = 'https://github.com/shajinhui/cuit-server/issues'

usePageTheme('#f2f2f7')

function goBack() {
  if (window.history.state?.back) {
    router.back()
    return
  }
  void router.replace({ name: 'login' })
}
</script>

<template>
  <main class="privacy-page">
    <header class="privacy-topbar">
      <button type="button" class="privacy-back-button" aria-label="返回上一页" @click="goBack">
        <svg aria-hidden="true" viewBox="0 0 24 24"><path d="m15 5-7 7 7 7" /></svg>
      </button>
      <h1>隐私政策</h1>
      <span aria-hidden="true" />
    </header>

    <article class="privacy-content">
      <header class="privacy-introduction">
        <p class="privacy-eyebrow">成信友友</p>
        <h2>我们只处理校园服务所必需的信息</h2>
        <p>
          本政策说明成信友友如何收集、使用、存储和保护您的个人信息，以及您可以如何查阅、更正或删除这些信息。
        </p>
        <div class="privacy-dates">
          <span>更新日期：2026 年 7 月 28 日</span>
          <span>生效日期：2026 年 7 月 28 日</span>
        </div>
      </header>

      <aside class="privacy-notice" aria-labelledby="privacy-important-title">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M12 3 5.5 5.8v5.1c0 4.2 2.7 7.7 6.5 9.1 3.8-1.4 6.5-4.9 6.5-9.1V5.8L12 3Z" />
          <path d="M12 8v4.4M12 15.8h.01" />
        </svg>
        <div>
          <h2 id="privacy-important-title">重要说明</h2>
          <p>
            成信友友是非官方学生项目，与成都信息工程大学及教务系统运营方无隶属或授权关系。为完成教务登录，
            服务端需要将您主动填写的学号和密码提交至学校统一身份认证及教务系统。
          </p>
        </div>
      </aside>

      <section class="privacy-section">
        <h2><span>1</span>谁在处理您的信息</h2>
        <p>
          个人信息处理者为成信友友项目维护者。您可以通过应用“我的—问题反馈”联系维护者；无法登录时，
          可通过
          <a :href="repositoryIssuesURL" target="_blank" rel="noopener noreferrer">GitHub Issues</a>
          联系。请勿在公开 Issue 中填写学号、姓名、密码、Cookie 或完整成绩等个人信息。
        </p>
      </section>

      <section class="privacy-section">
        <h2><span>2</span>我们处理哪些信息</h2>
        <dl class="privacy-data-list">
          <div>
            <dt>账号与身份信息</dt>
            <dd>学号、姓名、学院、专业、年级，以及您主动输入的教务系统密码。</dd>
            <dd>用于学校统一身份认证、维持登录状态和展示个人信息。</dd>
          </div>
          <div>
            <dt>学业信息</dt>
            <dd>学期、课表、成绩、考试安排、学业完成情况和教室占用信息。</dd>
            <dd>仅在您使用相应功能时，从学校教务系统查询并展示。</dd>
          </div>
          <div>
            <dt>本机离线数据</dt>
            <dd>最近课表、个人资料、手动课程、课程修改、学期与当前周、空教室快照及查询条件。</dd>
            <dd>存放在当前浏览器或 Android 应用的 IndexedDB 中，用于离线打开和减少重复查询。</dd>
          </div>
          <div>
            <dt>反馈与基础诊断信息</dt>
            <dd>反馈类型、平台、反馈内容、User-Agent、关联用户编号和提交时间。</dd>
            <dd>服务日志还可能包含请求时间、方法、接口路径、状态码、耗时和错误摘要，用于排障与安全审计。</dd>
          </div>
        </dl>
      </section>

      <section class="privacy-section">
        <h2><span>3</span>敏感信息的必要性与影响</h2>
        <p>
          教务密码、身份信息和学业信息具有较高敏感性。处理这些信息是完成统一身份认证、代您查询教务数据和恢复登录状态所必需的；
          如您不同意，将无法使用需要登录的教务功能，但公开校历等无需登录的功能不受影响。
        </p>
        <p>
          若保护措施失效，可能产生账号被冒用、学业信息泄露等风险。请使用可信设备和网络，不要向任何人提供密码或会话信息。
        </p>
      </section>

      <section class="privacy-section">
        <h2><span>4</span>我们如何存储及保存</h2>
        <ul class="privacy-bullet-list">
          <li>
            <strong>密码：</strong>
            密码经加密后保存在服务端数据库中，用于在会话恢复时重新登录教务系统；不会保存在前端离线缓存中。
          </li>
          <li>
            <strong>登录会话：</strong>
            浏览器仅保存 HttpOnly 会话 Cookie，服务端保存随机会话令牌的哈希。当前 Cookie 最长配置为 400 天，并可能在启动时续期；
            退出登录、服务端失效或清除浏览器数据会提前终止会话。
          </li>
          <li>
            <strong>后台账户记录：</strong>
            姓名、学号、院系专业和加密密码会在您持续使用服务期间保存。退出登录只会使当前会话失效，不会自动删除这些后台记录；
            您可以联系维护者申请删除。
          </li>
          <li>
            <strong>本机缓存：</strong>
            保存至被新数据替换、您退出登录、清除站点数据或卸载应用。空教室快照仅在 24 小时内作为有效缓存使用。
          </li>
          <li>
            <strong>反馈与日志：</strong>
            保存至反馈处理、排障或安全审计目的完成，或您提出删除申请；运行日志会随运维清理而删除，不作为用户档案使用。
          </li>
        </ul>
      </section>

      <section class="privacy-section">
        <h2><span>5</span>信息如何流转</h2>
        <p>
          为实现登录和查询，相关账号信息及请求会发送至成都信息工程大学统一身份认证和教务系统。托管、网络和安全服务提供方可能在提供基础设施时处理
          IP 地址及基础请求信息。除实现服务、遵守法律义务或保护用户安全所必需的情形外，我们不会出售个人信息，也不会将其用于广告或无关营销。
        </p>
      </section>

      <section class="privacy-section">
        <h2><span>6</span>您的权利与操作方式</h2>
        <ul class="privacy-bullet-list">
          <li>您可以在应用内查看个人资料、课表、成绩和其他已查询信息，并通过学校教务系统更正源数据。</li>
          <li>退出登录会清除当前设备上的课表、个人资料和空教室等离线缓存，并使当前服务端会话失效。</li>
          <li>您可以通过问题反馈申请查阅、更正、复制或删除后台个人信息，或撤回此前的同意。</li>
          <li>撤回同意不影响撤回前已经完成的处理；删除必要信息后，依赖教务登录的功能将无法继续使用。</li>
        </ul>
      </section>

      <section class="privacy-section">
        <h2><span>7</span>设备权限与未成年人</h2>
        <p>
          Android 版本目前仅申请联网权限，不主动申请定位、通讯录、相机、麦克风或存储权限。若后续新增权限，我们会在使用前说明目的并请求授权。
        </p>
        <p>
          本应用面向高校学生。如您未满 14 周岁，请勿自行注册或登录；应由监护人阅读本政策并与项目维护者联系确认后再使用。
        </p>
      </section>

      <section class="privacy-section">
        <h2><span>8</span>安全措施、变更与联系</h2>
        <p>
          我们采用 HTTPS、HttpOnly Cookie、随机会话令牌、密码加密存储、用户会话隔离和日志脱敏等措施降低风险。
          但互联网服务无法保证绝对安全；如发现异常，请立即退出登录、修改学校账号密码并联系维护者。
        </p>
        <p>
          功能、处理目的或信息种类发生重要变化时，我们会更新本政策，并在必要时重新征求同意。您可通过应用内问题反馈或
          <a :href="repositoryIssuesURL" target="_blank" rel="noopener noreferrer">GitHub Issues</a>
          提出问题或权利请求。
        </p>
      </section>

      <p class="privacy-footer">感谢您认真阅读。保护个人信息，需要项目和每一位用户共同参与。</p>
    </article>
  </main>
</template>
