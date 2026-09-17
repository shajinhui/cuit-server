export type InstallGuideKind =
  | 'ios'
  | 'android-pwa'
  | 'embedded'
  | 'firefox'
  | 'samsung'
  | 'chromium'
  | 'generic'

export interface InstallGuide {
  kind: InstallGuideKind
  browserName: string
  description: string
  steps: string[]
}

export interface InstalledDisplayInput {
  displayModes: string[]
  referrer: string
  standalone?: boolean
}

export interface InitialInstallGuideInput {
  installed: boolean
  guideKind: InstallGuideKind
  promptSeen: boolean
}

export function shouldOpenInitialInstallGuide({
  installed,
  guideKind,
  promptSeen,
}: InitialInstallGuideInput): boolean {
  return !installed && guideKind === 'ios' && !promptSeen
}

export function resolveInstallGuide(userAgent: string): InstallGuide {
  if (isIOSBrowser(userAgent)) {
    return manualInstallGuide('ios', isSafari(userAgent) ? 'Safari' : 'iPhone / iPad 浏览器')
  }

  if (isEmbeddedBrowser(userAgent)) {
    return {
      kind: 'embedded',
      browserName: '当前应用内浏览器',
      description: '应用内浏览器通常不能直接安装 PWA，请先在系统浏览器中打开。',
      steps: ['点击右上角菜单', '选择“在浏览器打开”', '再从浏览器菜单安装到桌面'],
    }
  }

  if (/SamsungBrowser/i.test(userAgent)) {
    return {
      kind: 'samsung',
      browserName: '三星浏览器',
      description: '三星浏览器会在符合条件时提供自己的安装入口。',
      steps: ['点击地址栏中的安装图标', '或打开浏览器菜单', '选择“添加到主屏幕”'],
    }
  }

  if (/Firefox|FxiOS/i.test(userAgent)) {
    return {
      kind: 'firefox',
      browserName: 'Firefox',
      description: 'Firefox Android 通过浏览器菜单安装 Web 应用。',
      steps: ['打开右上角浏览器菜单', '选择“安装”或“添加到主屏幕”', '确认添加到桌面'],
    }
  }

  if (isChromiumBrowser(userAgent)) {
    return {
      kind: 'chromium',
      browserName: '当前浏览器',
      description: '如果没有出现系统安装弹窗，可以从浏览器菜单手动安装。',
      steps: ['打开右上角浏览器菜单', '选择“安装应用”或“添加到主屏幕”', '确认安装'],
    }
  }

  return {
    kind: 'generic',
    browserName: '当前浏览器',
    description: '不同浏览器的菜单名称可能略有差异。',
    steps: ['打开浏览器菜单', '查找“安装应用”或“添加到主屏幕”', '如果没有该选项，请改用 Chrome、Edge 或 Firefox'],
  }
}

export type ManualInstallGuideKind = 'ios' | 'android-pwa'

export function manualInstallGuide(
  kind: ManualInstallGuideKind,
  browserName = kind === 'ios' ? 'iPhone / iPad' : 'Chrome / Edge',
): InstallGuide {
  if (kind === 'ios') {
    return {
      kind: 'ios',
      browserName,
      description: 'iPhone 和 iPad 不提供网页主动调用的系统安装弹窗，需要通过分享菜单添加。',
      steps: [
        '使用 Safari 打开本页面',
        '点击浏览器的“分享”按钮',
        '向下滑动并选择“添加到主屏幕”',
        '开启“打开为 Web App”后点击“添加”',
      ],
    }
  }

  return {
    kind: 'android-pwa',
    browserName,
    description: 'Android 浏览器可以把成信友友添加到桌面，之后像 App 一样打开。',
    steps: [
      '用 Chrome 或 Edge 打开本页面',
      '点击浏览器右上角的菜单按钮',
      '选择“安装应用”或“添加到主屏幕”',
      '确认后从桌面图标打开',
    ],
  }
}

export function isInstalledDisplay({
  displayModes,
  referrer,
  standalone = false,
}: InstalledDisplayInput): boolean {
  return (
    standalone ||
    referrer.startsWith('android-app://') ||
    displayModes.some((mode) => mode === 'standalone' || mode === 'fullscreen' || mode === 'minimal-ui')
  )
}

function isEmbeddedBrowser(userAgent: string): boolean {
  return /MicroMessenger|DingTalk|AlipayClient|Weibo|; wv\)|\bQQ\/[\d.]+/i.test(userAgent)
}

function isIOSBrowser(userAgent: string): boolean {
  return /iPhone|iPad|iPod|Macintosh.*Mobile/i.test(userAgent)
}

function isSafari(userAgent: string): boolean {
  return /Safari/i.test(userAgent) && !/CriOS|FxiOS|EdgiOS|OPiOS/i.test(userAgent)
}

function isChromiumBrowser(userAgent: string): boolean {
  return /Chrome|Chromium|CriOS|EdgA|OPR|UCBrowser|MQQBrowser|HuaweiBrowser|MiuiBrowser|VivoBrowser|HeyTapBrowser/i.test(
    userAgent,
  )
}
