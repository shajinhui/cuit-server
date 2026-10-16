// 所有客户端使用固定入口；换包时只更新服务器跳转目标，旧页面也能下载最新版。
export const ANDROID_DOWNLOAD_URL = 'https://fanxiaogao05.dpdns.org/downloads/android'
export const LATEST_ANDROID_APK_URL =
  'https://gitee.com/fanxiaogao05/cuit-server/releases/download/1.0.0/chengxin-youyou-android-layout-fix2.apk'

// iOS 以 TestFlight 测试版为主要安装方式，PWA 保留为备用。
export const IOS_TESTFLIGHT_URL = 'https://testflight.apple.com/join/rzDV8bN5'
