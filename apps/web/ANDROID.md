# Android APK

`apps/web` 使用 Capacitor 8 将现有 Vue 构建产物封装为 Android APK。Android 原生工程保存在 `android/`，它是需要提交的源代码；`dist/` 和同步到原生工程的 Web 资源仍然是构建产物，不提交。

## 构建结构

- Android Application ID：`org.dpdns.fanxiaogao05.chengxinyouyou`
- 应用名称：`成信友友`
- 最低系统：Android 7（API 24）
- Web 资源目录：`dist`
- 正式 API：`https://api.fanxiaogao05.dpdns.org`

Capacitor 的本地页面使用 `https://fanxiaogao05.dpdns.org` 作为 hostname，使其与 API 子域保持同站。不要改回 `localhost`，否则当前 `Secure + SameSite=Lax` 的 HttpOnly 会话 Cookie 无法可靠用于跨站 API 请求。

原生包不注册 Service Worker，静态资源直接从 APK 加载；已有 IndexedDB 业务缓存仍保留。封装 APK 只保证应用外壳可以离线启动，不会自动缓存所有 API 数据。

## Web 热更新

从 Android `0.2.0`（`versionCode 2`）开始，APK 内置 Capgo Updater，并通过现有 Cloudflare Pages 免费分发 Web 更新，不依赖 R2：

1. App 先加载 APK 内置页面，不等待网络。
2. 启动或回到前台后，通过原生 HTTP 从 `https://fanxiaogao05.dpdns.org/app-updates/android/latest.json` 后台检查更新；这不会被 Capacitor 本地资源服务器拦截。
3. 新包通过 SHA-256 校验并静默下载完成后，弹窗提供“立即更新”和“稍后”。
4. “立即更新”会立刻重载并切换 Web 包；“稍后”会在 App 下次进入后台或冷启动时切换。
5. 新包启动后 10 秒内未完成 `notifyAppReady()`，插件自动回滚到上一个可用版本。

更新过程没有系统安装弹窗，也不会在用户选择“稍后”时强制刷新。切换 Web 包时仍会重建 WebView，因此未保存的临时表单不能只放在内存中。

Cloudflare Pages 继续执行 `pnpm run build`。构建会同时输出普通 PWA 和 Android 更新包；自定义域名作为国内网络首选下载地址，Pages 提供的 `CF_PAGES_URL` 作为该次不可变部署的备用地址。只有 `nativeVersion` 与 APK 完全一致的设备才会接收更新。

以下改动可以热更新：

- Vue 页面、样式、图片和前端业务逻辑。
- 不要求新增或升级原生插件的接口调用。

以下改动必须重新构建并安装 APK，同时递增 `versionCode` 和 `versionName`：

- Capacitor 插件、Android 权限、Gradle 或 Java 原生代码。
- 应用图标、启动图、系统栏等原生资源。
- 依赖新原生能力的前端代码。

首次启用热更新仍必须安装一次 `0.2.0` 或更高版本的基础 APK；旧 APK 本身没有更新插件，无法自动获得这项能力。

## 系统栏与安全区

`MainActivity` 为 Android 7 及以上统一启用 Edge-to-Edge，状态栏和手势导航栏保持透明，页面继续通过 `--safe-area-inset-*` 避开挖孔和系统手势区域。

部分厂商设备的 Android WebView 版本低于 140。Capacitor 会在这些设备上改由原生 WebView 父容器承载安全区，因此 `SystemBarBackgroundPlugin` 会把父容器背景同步为当前页面的主题色，避免顶部和底部露出白边。新增页面必须继续通过 `usePageTheme()` 声明页面背景色。

## GitHub 生成测试 APK

推送涉及 `apps/web` 或 Android 工作流的提交后，`Android APK` 工作流会：

1. 构建 Vue 生产资源。
2. 同步 Capacitor Android 工程。
3. 使用 Gradle 生成 Debug APK。
4. 上传 `chengxin-youyou-debug-apk` Artifact，保留 14 天。

在 GitHub 仓库打开 `Actions -> Android APK`，进入对应运行记录后即可下载。每次 GitHub Runner 生成的 Debug 签名可能不同，因此 Debug APK 只用于测试；遇到签名不一致时需要先卸载旧测试包。

## GitHub 生成正式签名 APK

签名密钥只能生成一次，并需要独立备份。不要把密钥、密码或 Base64 内容提交到仓库。

不安装 Android Studio也可以使用 JDK 自带的 `keytool` 生成 PKCS#12 密钥：

```bash
keytool -genkeypair -v \
  -storetype PKCS12 \
  -keystore chengxin-youyou-release.p12 \
  -alias chengxin-youyou \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

在 GitHub 仓库的 `Settings -> Secrets and variables -> Actions` 中添加：

| Secret | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 密钥文件的单行 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 密钥库密码 |
| `ANDROID_KEY_ALIAS` | `chengxin-youyou` |
| `ANDROID_KEY_PASSWORD` | 别名密码 |

macOS 生成单行 Base64：

```bash
base64 -i chengxin-youyou-release.p12 | tr -d '\n' | pbcopy
```

配置完成后打开 `Actions -> Android APK -> Run workflow`，将 `APK 类型` 选择为 `release`。工作流会使用 `apksigner` 生成并校验 `chengxin-youyou-release-apk` Artifact，保留 30 天。

同一 Application ID 的后续版本必须继续使用同一签名密钥，并递增 `android/app/build.gradle` 中的 `versionCode`。

## 本地同步

只更新 Web 资源和 Capacitor 插件时执行：

```bash
cd apps/web
VITE_API_BASE_URL=https://api.fanxiaogao05.dpdns.org pnpm run android:sync
```

本地没有 Android SDK 时仍可完成前端构建和 Capacitor 同步，APK 编译交给 GitHub Actions。

## 真机验收

GitHub 构建成功只证明 APK 可以编译，不代表各厂商设备已经适配完成。至少验证：

1. 首次登录、杀死进程后重开和主动退出。
2. 断网冷启动不出现白屏，并能读取允许保存的本机缓存。
3. 系统返回键、底部导航、软键盘和安全区。
4. 小米、华为、OPPO/vivo、三星中能够获取到的代表设备。
5. 安装新版本时能直接覆盖旧的正式签名版本。
