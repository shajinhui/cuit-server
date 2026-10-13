# 公共 UI 组件

页面负责业务，公共组件负责外观和交互。下拉框、操作菜单、对话框、底部弹层统一放在 `lib/ui/components/`，页面直接传入选项、当前值和回调，不另外增加组件工厂或配置框架。

```text
业务页面：准备选项、维护状态、校验业务输入、调用接口
    ↓ 组合
公共 UI：显示选项、弹出容器、返回选择、处理主题与布局
    ↓ 使用
Flutter：焦点、表单校验、路由、键盘和系统交互
```

## 从哪里找组件

| 文件 | 组件 / 函数 | 使用场景 |
| --- | --- | --- |
| `page_layout.dart` | `PageScaffold`、分组卡片和表单布局等 | 公共页面骨架与分组样式 |
| `page_selection.dart` | `PageDropdown<T>` | 标题栏排序、外观设置、课表编辑中的紧凑选择 |
| 同上 | `PageDropdownField<T>` | 学期、校区、自修室等表单选择 |
| `page_menu.dart` | `PageActionMenu<T>`、`PageMenuAction<T>` | 更多操作、举报、删除 |
| 同上 | `showPagePopover<T>` | 课表周次、学期等锚定到按钮的定位菜单 |
| `page_dialog.dart` | `showPageDialog<T>`、`PageAlertDialog` | 提示、公告、带按钮的对话框 |
| 同上 | `PageDialog` | 预约等自定义表单的滚动容器 |
| 同上 | `showPageConfirmation` | 取消预约、结束预约等确认操作 |
| 同上 | `showPageChoice<T>` | 续座时长等短列表单选 |
| `page_sheet.dart` | `showPageSheet<T>`、`PageSheetHandle` | 筛选条件、头像选择、课程详情和编辑 |

对话框、操作菜单、定位菜单和底部弹层挂在根导航器上，避免被页面内部导航挡住。下拉框沿用 Flutter 的选择路由和表单行为。

## 下拉选择

选项用有序的 `Map<值类型, String>` 表达，页面只保存选中的值。需要禁用时将 `onChanged` 设为 `null`。如果当前值不在选项里，组件显示“请选择”，不会偷偷修改页面状态。

```dart
PageDropdownField<String>(
  value: selectedCampus,
  values: const {'airport': '航空港校区', 'longquan': '龙泉校区'},
  decoration: const InputDecoration(labelText: '校区'),
  onChanged: loading
      ? null
      : (value) => setState(() => selectedCampus = value),
)
```

“不限”等空值是有效业务选项时，使用可空值类型，如 `PageDropdownField<int?>` 和 `{null: '不限', 20: '20 人以上'}`。组件同步页面传来的当前值，不再保存第二份选中状态。菜单中的长名称可以换行，收起后单行省略；菜单高度受屏幕限制，选项至少留出 48 的点击高度。

表单使用 `PageDropdownField`，紧凑行使用 `PageDropdown`。需要布满行宽时设置 `expanded: true`，为没有可见标签的选择控件提供 `semanticLabel`。

## 操作菜单与定位菜单

权限、可用性和执行逻辑都由页面决定。公共菜单只根据传入的动作显示内容，`destructive` 用于突出删除等操作，`enabled` 控制单项是否可点。

```dart
PageActionMenu<String>(
  actions: [
    const PageMenuAction(value: 'report', label: '举报'),
    if (canDelete)
      const PageMenuAction(
        value: 'delete',
        label: '删除',
        destructive: true,
      ),
  ],
  onSelected: handleAction,
)
```

只有需要自定义内容或精确定位时才使用 `showPagePopover`，通过 `GlobalKey` 指向已显示的按钮。组件负责控制宽度和可用高度，在下方空间不足时向上弹出；长列表由调用方提供 `ListView` 或 `SingleChildScrollView`。点击空白处取消，取消返回 `null`；开启系统减少动画设置时不播放进场动画。

## 对话框

常规确认直接调用 `showPageConfirmation`，仅返回 `true` 时执行操作。返回键、点击外部和取消按钮都返回 `false`。

```dart
final confirmed = await showPageConfirmation(
  context,
  title: '取消预约',
  content: const Text('确定取消这条预约吗？'),
  confirmLabel: '取消预约',
  destructive: true,
);
if (!confirmed || !mounted) return;
await cancelReservation();
```

短列表单选用 `showPageChoice<T>`，选中返回对应的值，取消返回 `null`。带说明与操作按钮的弹窗用 `showPageDialog` 配合 `PageAlertDialog`；预约等复杂表单用 `PageDialog`。两种容器统一圆角、主题、最大宽度和滚动行为，避免窄屏、大字体和键盘遮挡内容。

文本控制器由弹窗自身的 `State` 创建并在 `dispose()` 中释放，不能在 `Navigator.pop()` 后立即释放，否则退场动画仍可能访问它。校园举报的原因长度校验保留在 `campus_report_dialog.dart`，没有放进公共 UI。

## 底部弹层

```dart
final avatar = await showPageSheet<String>(
  context,
  builder: (sheetContext) => AvatarPicker(
    onSelected: (value) => Navigator.pop(sheetContext, value),
  ),
);
if (avatar != null) await saveAvatar(avatar);
```

组件统一处理底部安全区、键盘高度、最大宽度和可用高度。内部已经移除重复的底部安全区与键盘 inset，内容不要再手动累加这两个值。长内容仍由业务组件提供滚动列表。

默认显示公共拖动条；已有拖动条的内容传 `showHandle: false`。`floating: true` 用于四周留白的浮动弹层，`blurBackdrop: true` 用于需要背景模糊的课程弹层。课表的 `showScheduleSheet` 保留为薄封装，转调公共组件并保留原来的课表外观。

## 已接入的页面

- 课表：周次、学期与更多菜单，课程编辑选择框，提醒时间，详情与编辑弹层。
- 工具：学期选择、空教室筛选、图书馆自修室选择、预约表单、确认操作、续座单选、工具公告。
- 校园：评分排序、评论排序与操作菜单、二手发布的校区与联系方式选择、共享举报弹窗。
- 我的：外观设置、头像选择、隐私说明。
- 校园地图：全屏预览复用公共对话框入口，保留全屏内容容器。

系统日期与时间选择仍使用 Flutter 的 `showDatePicker` / `showTimePicker`；iOS 根导航仍走既有原生实现。它们有各自完整的交互职责，不再增加仅转发参数的包装层。本次组件整理不修改课程网格和业务请求规则。

## 维护规则

1. 新增同类控件先使用上面的公共组件，不在页面复制 `DropdownButton`、`PopupMenuButton` 或弹层容器样式。
2. 公共组件不得导入 `features/`，不读取业务接口、不判断用户权限。确有业务含义的复用组件留在所属模块。
3. 当前值与业务加载状态只保存在页面或 ViewModel 中，公共组件通过参数与返回值通信。
4. 注释解释边界、空值和生命周期等容易误解的地方，使用清晰中文；不复述每行代码。
5. 只有确有差异的布局才新增参数，不为未来假设增加继承层或通用配置对象。

测试位于 `test/page_controls_test.dart`，覆盖状态同步、取消结果、禁用选项、根导航、长文本、键盘避让和举报弹窗控制器生命周期。模拟器截图由正式页面配合隔离的假数据生成，不使用真实账号，也不提交实际预约、举报或反馈。

## 验证记录（2026-10-08）

| 检查 | 结果 |
| --- | --- |
| Dart 格式与 Flutter analyze | 通过 |
| 全部数据、业务及组件测试 | 235 项通过，含本次新增的 6 项公共控件测试 |
| 工具页模拟器流程 | 通过，覆盖筛选弹层、展开下拉框、预约表单及切页 |
| 其他页面模拟器流程 | 通过，覆盖课表周次菜单、课程编辑、头像选择、举报输入及取消 |
| 正常 iOS Simulator 应用构建、安装与启动 | 通过；测试后已恢复正常应用 |
| Android release APK 构建与签名检查 | 通过，约 67.6 MB，使用既有本地测试签名 |

本次使用已有的 iPhone 17 Pro / iOS 26.5 模拟器，没有下载新模拟器。键盘避让通过组件测试模拟键盘高度验证；截图中的举报输入由测试注入文本，没有展示真实系统键盘。未进行 Android 真机验证。

可查看 [展开的教室下拉框](../screenshots/tools-classrooms-dropdown.png)、[图书馆预约表单](../screenshots/tools-library-confirm.png)、[课表周次菜单](../screenshots/pages-week-menu.png)和[举报输入弹窗](../screenshots/pages-report-input.png)。新版安装包为 `build/app/outputs/flutter-apk/chengxin-youyou-common-ui.apk`。
