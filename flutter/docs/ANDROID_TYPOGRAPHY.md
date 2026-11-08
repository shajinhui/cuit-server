# 安卓字体

更新日期：2026-11-09。安卓单独使用 **HarmonyOS Sans SC**，iOS 继续用系统苹方 / SF Pro。本文记录原因、许可限制、字重映射和回退方式。

## 为什么只换安卓

iOS 的 `PingFang SC` + `SF Pro` 由系统提供，Flutter 通过 `CupertinoSystemText` / `CupertinoSystemDisplay` 直接拿到，观感统一。安卓上 Flutter 请求 `Roboto`，ROM 不一定有；小米实际回落到 `sans-serif`（MiSans），Pixel 则是 Roboto + Noto Sans CJK，同一份代码在不同机器上字面宽度和黑度都不一样。

苹方和 SF Pro 都不允许再分发，不能内嵌到安装包里。选区时按“接近苹方、允许商用”筛，最后选了 HarmonyOS Sans SC：它是华为免费商用的字体，字面比 MiSans 收，拉丁 x-height 也更接近苹方。

## 许可限制：不能 subset

`assets/fonts/HARMONYOS_SANS_LICENSE.txt` 是官方许可全文，关键两条：

- 允许 **embed、bundle、redistribute unmodified copies**，但 **不得修改字体或其中任何组件**；
- 必须在软件中显著声明使用了该字体，并保留版权声明与许可全文。

所以 `pyftsubset` 那套方案对这个字体**不合法**，只能原样打包。以后如果要压体积，只能换一款允许修改的字体（思源黑体 / Noto Sans SC，SIL OFL），而不是删这里的字形。

许可合规做了两件事：

1. 「我的 → 关于 → 开源许可」里登记了许可全文（[font_licenses.dart](../lib/ui/theme/font_licenses.dart)，`LicenseRegistry`）；
2. 「关于我们」页脚注明安卓字体与版权方。

## 文件与体积

| 文件 | 大小 |
| --- | --- |
| `HarmonyOS_Sans_SC_Regular.ttf` | 8.26 MB |
| `HarmonyOS_Sans_SC_Medium.ttf` | 8.23 MB |
| `HarmonyOS_Sans_SC_Bold.ttf` | 8.16 MB |
| 合计（未压缩） | 24.6 MB |

实测 APK 从 **69.1 MB → 86.0 MB（+16.9 MB）**，zip 会压缩一部分 TTF。Shorebird 的基础包也会跟着变大；字体属于 assets，**不能通过补丁下发**，要发新的基础版本。

## 字重映射

HarmonyOS Sans SC 只有 Thin / Light / Regular / Medium / Bold / Black，**没有 Semibold**。App 里 `w600` 用了 99 处，如果只登记 400/500/700，`w600` 会按 CSS 规则落到 700（Bold），比现在更粗。

所以 `pubspec.yaml` 把 Medium 登记了两次：

```yaml
fonts:
  - family: HarmonyOS Sans SC
    fonts:
      - asset: assets/fonts/HarmonyOS_Sans_SC_Regular.ttf
        weight: 400
      - asset: assets/fonts/HarmonyOS_Sans_SC_Medium.ttf
        weight: 500
      - asset: assets/fonts/HarmonyOS_Sans_SC_Medium.ttf
        weight: 600
      - asset: assets/fonts/HarmonyOS_Sans_SC_Bold.ttf
        weight: 700
```

同一个文件登记两次不会被打包两份（`FontManifest.json` 里是两条记录、APK 里只有一个文件）。效果：

| 代码里的字重 | 实际字形 |
| --- | --- |
| 400 | Regular |
| 500 / 600 | Medium |
| 700 / 800 | Bold（800 取最近） |

`w600` 和 `w500` 在视觉上会一致，这是这个字体的取舍；`w700` 仍与它们拉开层级，标题不会塌。

## 代码位置

| 位置 | 作用 |
| --- | --- |
| `pubspec.yaml` | 声明字体家族与四个字重 |
| `lib/ui/theme/app_theme.dart` | `_platformFontFamily`：仅 `defaultTargetPlatform == android` 时返回 `HarmonyOS Sans SC`；iOS 传 null |
| `lib/ui/theme/font_licenses.dart` | 把许可文本挂到 Flutter 的开源许可页 |
| `lib/features/profile/presentation/about_page.dart` | 关于页脚注 |
| `assets/fonts/` | 三个未修改的 TTF + 许可全文 |

鸿蒙（`defaultTargetPlatform.name == 'ohos'`）不会命中 `TargetPlatform.android`，继续用系统字体。

## 验证与回退

模拟器（Android 15 AOSP）实测：登录页、课表、工具页均正常显示 HarmonyOS Sans SC，`w700` 标题仍明显重于 `w600` 工具名，没有溢出。

| 课表 | 工具 |
| --- | --- |
| ![课表](../screenshots/android-harmonyos-schedule.png) | ![工具](../screenshots/android-harmonyos-tools.png) |

「我的 → 关于 → 开源许可」里能看到 HarmonyOS Sans SC 的许可条目；关于页脚注也显示了字体与版权方。

注意：`flutter test` 里的组件测试不加载内置字体（测试环境用 Ahem），所以 **320 宽 / 3 倍字体的布局回归要在真机或模拟器上看**，不能只看测试通过。

回退到系统字体：

1. 删除 `pubspec.yaml` 里的 `fonts:` 段和 `assets/fonts/...` 资产项；
2. 删除 `AppTheme._platformFontFamily` 并在 `ThemeData` 去掉 `fontFamily`；
3. 删除 `main.dart` 的 `registerBundledFontLicenses()`、`font_licenses.dart`、关于页脚注；
4. 删除 `assets/fonts/`。
