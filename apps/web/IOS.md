# iOS IPA

`apps/web/ios` 是成信友友的 Capacitor 8 iOS 工程，使用 Swift Package Manager，最低支持 iOS 15。

## 已完成的迁移

- Bundle ID：`org.dpdns.fanxiaogao05.chengxinyouyou`
- iOS 工程版本：`0.2.0`，Build `2`
- 默认内置从 APK 提取的 `0.1.0` Web 资源快照（68 个文件），不需要重新下载业务页面
- 可切换为公开源码当前的 `0.2.0` Web 构建
- iOS 原生 HTTP/Cookie 接管 API 请求，支持后端 `HttpOnly` 登录会话
- 已接入 App、Device、Filesystem、Share 插件
- 已生成正式 App Icon 和启动图
- Android 专用 Capgo 热更新不进入 iOS 包

## 在 Mac 上生成 IPA

需要 Xcode 16 或更高版本、Node.js 24、pnpm 10.26.1，以及与 Bundle ID 匹配的 Apple 证书和 provisioning profile。先在钥匙串中导入带私钥的证书，并安装 `.mobileprovision`。

```bash
cd apps/web
export IOS_TEAM_ID='你的 Team ID'
export IOS_PROVISIONING_PROFILE_NAME='描述文件名称'
export IOS_EXPORT_METHOD='release-testing'
export IOS_WEB_MODE='apk'
pnpm run build:ipa
```

`IOS_WEB_MODE=apk` 打包 APK 原始页面，`IOS_WEB_MODE=source` 打包公开源码当前页面。安装到已登记 UDID 的设备使用 `release-testing`；开发证书使用 `debugging`；上传 App Store Connect 使用 `app-store-connect`。生成文件位于 `ios/output/ipa/`。

如果 Mac 已经执行过一次 `pnpm install` 且 Xcode 已解析 Swift Packages，后续可以断网重复归档。依赖缓存不完整时仍需短暂联网一次；Windows 无法运行 Xcode，因此不能在本机直接生成已签名 IPA。

## GitHub Actions 签名

工作流 `.github/workflows/ios.yml` 在 GitHub 的 macOS Runner 上构建。只需在网络可用的短时间内把源码推送并配置 Secrets，之后下载最终 Artifact；远端构建不依赖本机 VPN 持续在线。仓库 Secrets 需要配置：

| Secret | 内容 |
| --- | --- |
| `IOS_CERTIFICATE_P12_BASE64` | 含私钥的 `.p12` 文件 Base64 |
| `IOS_CERTIFICATE_PASSWORD` | `.p12` 密码 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` 文件 Base64 |
| `IOS_TEAM_ID` | Apple Developer Team ID |

不要把证书、密码、provisioning profile 或 Base64 内容提交进仓库。配置后运行 `iOS IPA` 工作流，默认选择 `apk` 页面模式，再选择导出类型；即使本地 VPN 随后断开，Runner 仍会继续。重新联网后下载 `chengxin-youyou-ipa` Artifact。

## 不稳定网络建议

工程已锁定 npm 依赖版本，并使用国内 npm 镜像进行本地安装。GitHub 只用于一次源码推送和之后下载 Artifact，不需要在云端构建期间保持 VPN。

如果连接经常中断，可在仓库根目录使用可重试推送脚本。脚本每轮先直连，Clash `127.0.0.1:7890` 可用时再尝试代理，不修改全局或仓库 Git 配置。把 URL 换成你自己的空 GitHub 仓库；脚本不会向上游源码仓库推送：

```powershell
.\scripts\push-github-with-clash.ps1 -RepositoryUrl 'https://github.com/你的账号/你的仓库.git'
```

推送成功后，本机可以立即断开 VPN。GitHub 的 macOS Runner 会在云端独立完成构建。

## 验收重点

1. 首次登录、杀进程重开、退出登录。
2. 断网冷启动和课表离线缓存。
3. 分享 `.ics` 到系统日历。
4. 校历外链、GitHub 外链和地图缩放。
5. iPhone 刘海/灵动岛、底部手势区和键盘遮挡。
