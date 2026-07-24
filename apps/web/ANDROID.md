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
