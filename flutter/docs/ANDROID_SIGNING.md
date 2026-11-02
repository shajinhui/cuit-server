# Android 发布签名

Flutter 客户端使用独立包名 `org.dpdns.fanxiaogao05.chengxin.flutter`。Android Release 已使用独立的 RSA-4096、SHA256withRSA、PKCS12 发布密钥，证书有效期为 10000 天。密钥由 Android 的标准 `keytool` 生成，后续安装包更新应持续使用同一密钥。

当前发布证书的 SHA-256（公开指纹，用于核对安装包签名）：

```text
52865C02D8D28A0D6169FA82655631828478C7F56FB1292AF1759D4F19FCF371
```

## 本机密钥与备份

密钥和密码配置保存在用户私有目录：

```text
~/.local/share/cuit-flutter-signing/
  chengxin-youyou-release.p12
  chengxin-youyou-release-certificate.pem
  key.properties
```

目录权限为 `0700`，文件权限为 `0600`。`flutter/android/key.properties` 是指向上述配置的本机符号链接，已由 `android/.gitignore` 排除；私钥、证书导出包和密码不得提交到 Git，也不要粘贴到聊天或构建日志。

请将整个签名目录备份到安全的离线位置。`key.properties` 保存密钥密码和别名；只备份 `.p12` 而丢失密码仍无法恢复发布签名。升级 CLI、重新绑定 Shorebird 或构建新版本均不需要重新生成密钥。

## 其他开发机

通过安全方式恢复签名目录，并在 `flutter/android/key.properties` 配置以下四个字段：

```properties
storeFile=/absolute/path/to/chengxin-youyou-release.p12
storePassword=<从安全备份恢复的密码>
keyAlias=chengxin-youyou-release
keyPassword=<从安全备份恢复的密码>
```

`storeFile` 使用当前机器的实际绝对路径。配置文件只保存在本机，权限设置为 `0600`。Release 构建会拒绝缺失或不完整的配置，不会退回开发签名。

## 构建与验签

在 `flutter/` 目录构建包含热更新运行时的基础 APK：

```bash
./tool/shorebird.sh release android --artifact apk
```

仅构建并验证、不登记 Shorebird 基础版本时追加 `--dry-run`。普通 `./tool/flutter.sh build apk --release` 同样使用发布签名，但不包含 Shorebird 运行时。

Release 构建保留默认的依赖刷新步骤，不追加 `--no-pub`，使原生插件注册文件按当前构建模式重新生成，避免沿用 Debug 的测试插件注册信息。

使用 Android SDK 的 `apksigner verify --verbose --print-certs <APK 路径>` 验签，并将签名证书 SHA-256 与本机导出的公开证书比较。APK 的应用 ID、版本和调试标记也应核对。

此前同包名的 Debug 安装包使用另一份证书，Android 不允许发布签名包直接覆盖它；安装签名不同的包需要先处理旧安装包。已有生产安装包后，后续版本保留同一签名即可覆盖升级。

Android 发布签名不包含应用商店审核或上架。iOS 的发布证书和描述文件仍由 Apple 开发者团队管理。

## 本机引擎依赖缓存

受限网络中已通过官方存储摘要校验的 Shorebird 引擎 Maven 依赖位于 `~/.local/share/cuit-shorebird-maven`。`tool/shorebird.sh` 检测到该目录时会设置 `SHOREBIRD_MAVEN_CACHE`，Gradle 优先从此目录解析 `io.flutter`，其他依赖仍使用原有仓库。可以通过同名环境变量指定其他缓存目录；完整校验记录保存在缓存的 `verified-c663a268.json`。此缓存不包含发布密钥或账号令牌。
