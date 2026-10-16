import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./LandingPage.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../styles/landing.css', import.meta.url), 'utf8')

function section(id: string) {
  const start = source.indexOf(`<section id="${id}"`)
  expect(start).toBeGreaterThan(-1)
  return source.slice(start, source.indexOf('</section>', start))
}

describe('官网能力与发布边界', () => {
  it('校园区展示评分、二手与论坛，论坛明确要求新版原生客户端', () => {
    const campus = section('landing-campus')
    for (const name of ['校园评分', '校园二手', '校园论坛']) expect(campus).toContain(name)
    const forum = campus.slice(campus.lastIndexOf('<article'))
    expect(forum).toContain('新版原生客户端')
    expect(forum).toContain('需安装支持论坛的新版客户端')
    expect(campus).toContain('不处理支付或担保交易')
  })

  it('下载区区分当前公开 APK、新版基础包和 iOS PWA，不许诺未提供的原生分发', () => {
    const platforms = section('landing-platforms')
    expect(platforms).toContain(':href="ANDROID_DOWNLOAD_URL"')
    expect(platforms).toContain('当前入口仍为原版客户端')
    expect(platforms).toContain('首次仍需安装对应基础包')
    expect(platforms).toContain('iOS 暂未提供 App Store / TestFlight 公开分发')
    expect(platforms).toContain('原生鸿蒙仍在验证中')
  })

  it('下载按钮只使用不缓存的固定入口，不将包地址写死在页面', () => {
    expect(source.match(/:href="ANDROID_DOWNLOAD_URL"/g)).toHaveLength(2)
    expect(source).not.toContain('.apk')
    expect(source).not.toContain('releases/download/')
  })

  it('本机个性化、公告与小组件不误导为云同步或离线系统推送', () => {
    expect(source).toContain('不会自动同步到其他设备或公开资料')
    expect(source).toContain('不是关闭 App 后的系统推送')
    expect(source).toContain('需要安装带小组件的对应客户端')
  })

  it('不把静态装饰写成实时库存，也不误称开源许可或文档全文检索', () => {
    for (const misleading of ['63 个座位可约', '69 个课程目录', '开源透明', '全文搜索', '一个账号']) {
      expect(source).not.toContain(misleading)
    }
    expect(source).toContain('校园跑使用独立服务，需要单独登录')
    expect(source).toContain('代码公开可查')
    expect(source).toContain('非官方学生项目')
  })

  it('新的跳转和悬浮交互尊重减少动态效果，弹窗可滚动且触摸关闭目标为 44px', () => {
    expect(source).toContain("reduceMotion ? 'auto' : 'smooth'")
    expect(styles).toContain('.landing-usage-backdrop *')
    expect(styles).toMatch(/\.landing-usage-dialog \{[^}]*overflow-y: auto;/)
    expect(styles).toMatch(/\.landing-usage-dialog__close \{[^}]*width: 44px;[^}]*height: 44px;/)
  })
})
