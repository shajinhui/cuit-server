# 安卓流畅度

更新日期：2026-11-08。目标是把安卓上“滑一下掉帧、切页顿一下”的已知来源逐个拆开，先改掉确定存在的 UI 线程开销，再给出可以在真机上复测的步骤。

本文只记录代码层已经做的处理。**本次没有在安卓真机（用户日常使用的那台）上采集帧耗时**，因此不能据此宣称安卓卡顿已经解决；下面的测量步骤就是用来验收的。

## 先确认测的是哪种包

`flutter run` 默认装的是 **debug** 包：Dart 不做 AOT 编译，还带着断言、调试检查和 JIT 预热，帧耗时通常比正式包高一个数量级。2026-11-08 检查开发机上已安装的包时，`pkgFlags` 里有 `DEBUGGABLE`，说明当时手机上跑的就是 debug 包；这种情况下的“不流畅”不能归因于业务代码。

| 模式 | 用途 | 能否用来判断流畅度 |
| --- | --- | --- |
| debug | 热重载开发 | 不能 |
| profile | 帧耗时采样 | 能，接近 release |
| release | 实际交付 | 能 |

排查顺序应该是：先用 profile 包复现，再用本文的采样脚本量化，最后才改代码。直接拿 debug 包的体感调优，很容易把正常开销当成 bug。

## 为什么安卓比 iOS 更容易不流畅

| 差异 | iOS | 安卓 |
| --- | --- | --- |
| 底部导航 | `NativeTabBar`，UIKit 原生 `UITabBar` | `liquid_glass_easy` 实时折射导航，每帧用 `BackdropFilter` 采样背后的页面 |
| 页面转场 | Cupertino 横向推入 | 系统默认缩放 + 淡入（`ZoomPageTransitionsBuilder`） |
| 字体与阴影 | 系统合成较重 | 中低端 GPU 对多层模糊、`saveLayer` 更敏感 |

液态玻璃不是“静态图片”：只要它后面的页面在滚动，采样层就要重画。所以任何叠加在它上面的额外合成（例如淡出动画）都会成倍放大开销。

## 这次改了什么

### 1. 底部导航隐藏不再叠加 `Opacity`

`lib/ui/components/auto_hide_scaffold.dart`

隐藏导航时原来的实现是 `AnimatedSlide` + `AnimatedOpacity`。`Opacity` 会给整条导航（包括折射层）套一个 `saveLayer`，每帧都要离屏合成；同时 `BackdropFilter` 被包在透明层里，采样的不再是真实页面背景。滚动一开始正好是这条动画最忙的时候。

现在只保留 `AnimatedSlide`：整条导航完整滑出屏幕即可隐藏，不再需要淡出，也就没有额外的离屏层。

### 2. 校园顶部收起不再重建整页

`lib/features/campus/presentation/campus_page.dart`

原实现把 `_headerVisible` 放在页面 State 里，滚动通知里 `setState`。每换一次滚动方向，整页都会重建：顶部栏、筛选栏、全部帖子卡片，以及整份校园主题。

现在：

- `_headerVisible` 改为 `ValueNotifier<bool>`，用 `ValueListenableBuilder` 只重建那 180ms 的收起动画；
- 帖子列表的 widget 实例保持不变，滚动本身不再触发卡片重建；
- 同时读取 `MediaQuery.disableAnimationsOf`，系统开启“减少动态效果”时直接切换、不做动画。

### 3. 论坛和评分列表按需构建

同一文件，`_buildFeedList`。

原来是 `ListView(children: [...全部卡片])`：进入校园页时会把全部帖子和板块一次性 build 出来，屏幕外的封面图也会立刻发起请求。现在改成 `ListView.builder`：筛选栏是第 0 项，帖子/板块按需创建，`LoadMoreButton` 和错误提示仍然是普通列表项。

这与二手列表此前的做法一致（`_buildMarketplaceList` 已经使用 builder）。

### 4. 校园主题只构造一次

`lib/features/campus/presentation/campus_theme.dart`

`campusTheme()` 每次调用都会执行 `ColorScheme.fromSeed`（一整套 HCT 色彩换算）并复制一份 `ThemeData`。校园页每次筛选、加载、重建都会请求它。

现在按**父主题引用**缓存：只有真正切换浅色/深色主题时才重新生成。

### 5. 头像与预览图按显示尺寸解码

| 位置 | 改动 |
| --- | --- |
| `lib/features/campus/presentation/campus_widgets.dart` | 预设头像是 200KB 级 JPG；按 `2 × radius × devicePixelRatio`（上限 256）解码，自定义头像同样带 `cacheWidth`/`cacheHeight` |
| `lib/features/campus/presentation/forum_editor_page.dart` | 88px 发帖缩略图按 88 逻辑像素解码 |
| `lib/features/community/presentation/community_pages.dart` | 资料页 88px 头像预览同上 |
| `lib/features/profile/presentation/profile_avatar_button.dart` | 本机头像按显示尺寸解码 |
| `lib/features/campus/presentation/marketplace_editor_page.dart`、`rating_editor_page.dart` | 二手/评分编辑预览按屏幕宽度解码，不再按 1920px 原图解码 |

选图时已经限制到 1920px / 质量 82，原图解码仍有约 11MB/张；列表滚动时反复解码小图会直接体现为掉帧和内存抖动。

## 没改、留待真机数据决定

1. **安卓默认开“轻量效果”**：磨砂降级少一层 shader 采样。`docs/LIQUID_GLASS.md` 的验收要求就是“若折射持续造成超预算帧，默认开启轻量模式后重新验证”。这会改变视觉，需要真机数据支持后再决定。
2. **页面转场**：把安卓的 `ZoomPageTransitionsBuilder` 换成 `CupertinoPageTransitionsBuilder` 或 `FadeUpwardsPageTransitionsBuilder`，可以减少转场首帧的缩放/快照开销，但会偏离安卓平台习惯。
3. **课表格子的 `Opacity`**：非本周课程每块一个透明层，滚动时整张网格重绘。可以改成预乘 alpha 的颜色，视觉几乎不变。
4. **帖子详情回复列表**：仍是 `ListView(children:)`，一页 20 条；点赞、展开楼中楼会重建整页。
5. **发布包 R8**：`build.gradle.kts` 没有显式开启 `isMinifyEnabled`/`isShrinkResources`（Flutter 插件对 release 有默认处理）。对启动速度有轻微帮助，对滚动帧率帮助不大。

## 真机测量步骤

Flutter 的帧耗时只在 **profile** 模式下有代表性；debug 模式的 Dart 是解释执行，必然掉帧，release 模式又拿不到 timeline。

```bash
cd flutter
./tool/flutter.sh devices
./tool/flutter.sh run --profile -d <设备标识>
```

打开 DevTools → **Performance**，在下面三个场景各录 20～30 秒：

1. 课表上下滚动，再连续切 10 次周；
2. 校园帖子列表连续滚动，再上滑/下滑交替触发顶部收起；
3. 四个底部 Tab 来回切 20 次，并进出一次帖子详情。

看两行帧时间：

| 指标 | 60Hz 预算 | 120Hz 预算 | 关注点 |
| --- | --- | --- | --- |
| UI（Dart build/layout） | 16.7ms | 8.3ms | 超过预算的帧说明重建/布局过多 |
| Raster（GPU） | 16.7ms | 8.3ms | 超过预算说明模糊、阴影、折射太重 |

判定标准建议：**90 分位帧时间低于预算，掉帧率低于 1%**；滚动时不再出现连续两帧超预算。安卓中低端机与 120Hz 机型都要看一遍。

如果安装的是正式签名包，profile 包的签名不同，`adb install -r` 会失败，测试机需要先卸载（会清掉本机登录与课表缓存）。建议在专门的测试机或模拟器上做，不要直接覆盖日常使用的那台。

### 自动采样脚本

不想手动录 DevTools 时，仓库里带了 `integration_test/perf_test.dart`：依次采样课表滚动、校园列表滚动和四次 Tab 切换，把每帧的 build/raster 分位数和超预算帧数写进 `PERF_REPORT`。

```bash
./tool/flutter.sh drive --profile -d <设备标识> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/perf_test.dart
```

结果会打印在日志里，同时写到 `build/integration_response_data.json`。脚本只采集、不设硬阈值——不同机型 GPU 差异太大，写死阈值会让低端机必然失败。

模拟器也能跑，但 **Raster 列没有参考价值**（软件渲染，单帧 100ms 以上是正常的），只有 build/layout 时间可看。2026-11-08 在 Android 15 ARM64 模拟器上的采样结果是：课表滚动 build p90 `0.60ms`，校园滚动 build p90 `0.94ms`、p99 `2.79ms`——说明 UI 线程没有异常重建；raster 一列被软件渲染拖到 100ms 以上，不能用于验收。

## 模拟器采样（只用于定位，不能代替真机）

Android 15 ARM64 模拟器、`-gpu host`、60Hz、支持 Shader Filter，用上面的 `perf_test.dart` 采样：

| 场景 | build p50 / p90 / p99 (ms) | raster p50 / p90 / p99 (ms) | 超 16.7ms 帧 |
| --- | --- | --- | --- |
| 课表滚动 | 0.35 / 0.64 / 0.86 | 2.36 / **16.67** / 18.5 | 14 / 122（11.5%） |
| 校园列表滚动 | 0.32 / 0.70 / 1.03 | 2.12 / 2.47 / 14.84 | 1 / 123（0.8%） |
| 四次 Tab 切换 | 0.48 / 0.81 / 4.24 | 3.28 / 4.58 / 14.43 | 1 / 105（1.0%） |

**UI 线程已经不再是瓶颈**：所有场景 build p99 都在 4.3ms 以内，校园滚动 p99 只有 1.03ms——说明整页重建和列表一次性构建已经消掉。

课表滚动的 11.5% 超预算帧集中在滚动开始/结束的两段 220ms 动画里（约 13～14 帧，正好等于动画帧数）。对照实验把底部导航的自动隐藏关掉后：

| 场景 | 开关自动隐藏 | raster p90 | 超预算帧 |
| --- | --- | --- | --- |
| 课表滚动 | 开（当前） | 16.67ms | 11.5% |
| 课表滚动 | 关 | 2.89ms | 0% |
| 校园滚动 | 开（当前） | 2.47ms | 0.8% |
| 校园滚动 | 关 | 16.35ms | 6.7% |

结论是玻璃导航的**移动**比静止更贵：课表页背景是整张彩色网格，玻璃条滑动时每一帧都要按新位置重新采样背景；校园页正好相反，玻璃条静止在滚动列表上方时反而更贵，收起后才便宜。

这是视觉与帧率的取舍，本次没有擅自改：

1. 把收起/展开改成瞬时（丢掉 220ms 动画，理论上拿掉这 11.5%）；
2. 安卓默认开“轻量效果”（少一层 shader 采样，`docs/LIQUID_GLASS.md` 里已有该预案）；
3. 只在课表页关闭自动收起（该页静止玻璃条实测 0% 超预算）。

真机上的绝对值会明显低于模拟器（尤其 raster），先按上面的步骤在目标机型复测再选。

## 本次回归

```bash
./tool/flutter.sh analyze   # 0 issue
./tool/flutter.sh test      # 369 项通过
```

相关测试：

- `test/auto_hide_scaffold_test.dart`：向上滚动隐藏、回滑恢复、切换主页面重现；
- `test/forum_page_test.dart`：校园顶部栏随上滑隐藏并在回滑时恢复；
- `test/campus_page_test.dart`、`test/forum_layout_test.dart`：论坛/评分/二手列表、筛选与搜索仍正常；
- `test/campus_asset_image_test.dart`：图片缩略图解码、点击预览与失败重试。

新增的采样脚本：`integration_test/perf_test.dart`。
