<h1 align="center">image_picker_ohos</h1>

本项目基于 [image_picker](https://pub.dev/packages/image_picker) 开发，提供 OpenHarmony 平台下的图片/视频选择器能力。

## 简介

`image_picker_ohos` 是 `image_picker` 插件的 OpenHarmony 平台实现，支持从图库选择图片和视频、使用相机拍照/录像、多选媒体文件、图片压缩裁剪等功能。插件通过 Flutter Plugin 机制桥接到 OpenHarmony 原生能力，使用 `photoAccessHelper` 和 `camera` 等系统 API 实现媒体文件选择。

## 下载安装

### 配置 pubspec.yaml

在 Flutter 项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  image_picker_ohos:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_packages.git
      path: packages/image_picker/image_picker_ohos
      # ref: image_picker-v1.2.1-ohos-1.0.1
      ref: TAG  #   请根据下方TAG版本对应表选择TAG
```

### 安装依赖

```bash
# 在项目根目录执行
flutter pub get
```

**TAG 版本对应表**

| Flutter 框架版本 | TAG1 | TAG2 | 分支 |
| :--- | :--- | :--- | :--- |
| 3.41 | `image_picker-v1.2.1-ohos-1.0.0` | `image_picker-v1.2.1-ohos-1.0.1` | `br_image_picker-v1.2.1_ohos` |
| 3.35 | `image_picker-v1.2.1-ohos-1.0.0` | `image_picker-v1.2.1-ohos-1.0.1` | `br_image_picker-v1.2.1_ohos` |
| 3.27 | `image_picker-v1.1.2-ohos-1.0.0` | `image_picker-v1.1.2-ohos-1.0.1` | `br_image_picker-v1.1.2_ohos` |
| 3.22 | `image_picker-v1.1.2-ohos-1.0.0` | `image_picker-v1.1.2-ohos-1.0.1` | `br_image_picker-v1.1.2_ohos` |
| 3.7 | `image_picker-v1.0.4-ohos-1.0.0` | `image_picker-v1.0.4-ohos-1.0.1` | `master` |

## 约束与限制

### 兼容性
在以下版本中已测试通过

1.Flutter: 3.35.7-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio: 6.0.1.260; ROM: 6.0.0.120 SP6;
2.Flutter: 3.41.10-ohos-0.0.1; SDK: 6.1.0(23); IDE: DevEco Studio: 6.1.0.830; ROM: 6.23.0.100 SP6;

### 权限要求

在宿主应用的 `ohos/src/main/module.json5` 中配置以下权限：

```json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "访问网络资源"
      },
      {
        "name": "ohos.permission.READ_MEDIA",
        "reason": "读取图库中的图片和视频"
      },
      {
        "name": "ohos.permission.WRITE_MEDIA",
        "reason": "写入文件到图库"
      },
      {
        "name": "ohos.permission.CAMERA",
        "reason": "使用相机拍照或录像"
      }
    ]
  }
}
```

> **注意**：`ohos.permission.INTERNET` 在部分场景下用于资源加载，请根据实际需求配置。`ohos.permission.CAMERA` 仅在调用拍照/录像功能时需要。

## 使用示例

### 完整示例（来自 example/lib/main.dart）

以下代码展示 `image_picker_ohos` 的典型使用方式。

#### 导入模块

```dart
// 导入 image_picker_ohos
import 'package:image_picker_ohos/image_picker_ohos.dart';
// 导入平台接口
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
```

#### 初始化插件

```dart
// 获取平台实例
final ImagePickerPlatform picker = ImagePickerPlatform.instance;

// 判断是否为 ohos 平台，启用原生 PhotoPicker
if (picker is ImagePickerOhos) {
  picker.useOhosPhotoPicker = true;
}
```

#### 功能实现与结果输出

**获取单张图片（从图库）**

```dart
// 从图库选择单张图片，设置最大宽高和质量
final XFile? image = await picker.getImageFromSource(
  source: ImageSource.gallery,
  options: ImagePickerOptions(
    maxWidth: 800,
    maxHeight: 600,
    imageQuality: 90,
  ),
);

if (image != null) {
  // 使用图片路径
  print('图片路径: ${image.path}');
}
```

**获取多张图片**

```dart
// 选择多张图片，最多 10 张
final List<XFile> images = await picker.getMultiImageWithOptions(
  options: MultiImagePickerOptions(
    imageOptions: ImageOptions(
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 90,
    ),
    limit: 10,
  ),
);

// 遍历多张图
for (final XFile image in images) {
  print('图片路径: ${image.path}');
}
```

**选择单张图片（传统接口）**

```dart
// 使用 pickImage 接口（返回 PickedFile）
final PickedFile? pickedFile = await picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 800,
  maxHeight: 600,
  imageQuality: 90,
);

if (pickedFile != null) {
  print('文件路径: ${pickedFile.path}');
}
```

**选择多张图片（传统接口）**

```dart
// 使用 pickMultiImage 接口
final List<PickedFile>? pickedFiles = await picker.pickMultiImage(
  maxWidth: 800,
  maxHeight: 600,
  imageQuality: 90,
);

if (pickedFiles != null) {
  print('选择了 ${pickedFiles.length} 张图片');
}
```

**获取视频**

```dart
// 从图库选择一个视频，限制最大时长 10 秒
final XFile? video = await picker.getVideo(
  source: ImageSource.gallery,
  maxDuration: const Duration(seconds: 10),
);

if (video != null) {
  print('视频路径: ${video.path}');
}
```

**选择视频（传统接口）**

```dart
// 使用 pickVideo 接口
final PickedFile? video = await picker.pickVideo(
  source: ImageSource.gallery,
  maxDuration: const Duration(seconds: 10),
);

if (video != null) {
  print('视频路径: ${video.path}');
}
```

**获取多个视频**

```dart
// 选择多个视频，最多 5 个，每个最长 30 秒
final List<XFile> videos = await picker.getMultiVideoWithOptions(
  options: MultiVideoPickerOptions(
    maxDuration: const Duration(seconds: 30),
    limit: 5,
  ),
);

print('选择了 ${videos.length} 个视频');
```

**拍照**

```dart
// 打开相机拍照
final XFile? photo = await picker.getImageFromSource(
  source: ImageSource.camera,
);

if (photo != null) {
  print('照片路径: ${photo.path}');
}
```

**获取媒体文件（图片和视频混合）**

```dart
// 同时选择多张图片和视频
final List<XFile> media = await picker.getMedia(
  options: MediaOptions(
    allowMultiple: true,
    imageOptions: ImageOptions(
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 90,
    ),
  ),
);

print('选择了 ${media.length} 个媒体文件');
```

**恢复丢失的数据**

```dart
// 恢复应用被系统回收前未处理的媒体选择结果
final LostDataResponse response = await picker.getLostData();

if (!response.isEmpty) {
  final XFile? file = response.file;
  final PlatformException? exception = response.exception;
  
  if (file != null) {
    print('恢复的文件: ${file.path}');
  }
  if (exception != null) {
    print('恢复时出错: ${exception.message}');
  }
}
```

## 使用说明

1. **原生 PhotoPicker 支持**：通过将 `ImagePickerOhos` 实例的 `useOhosPhotoPicker` 属性设为 `true`，可启用 OpenHarmony 原生 PhotoPicker 选择界面，提供更好的用户体验。
2. **参数校验**：`imageQuality` 取值范围为 0-100，`maxWidth` 和 `maxHeight` 不能为负数，`limit` 不能低于 2。参数不合法时会抛出 `ArgumentError`。
3. **多选限制**：`getMedia()` 中当 `allowMultiple` 为 `false` 时不能设置 `limit` 参数。
4. **丢失数据处理**：`getLostData()` 用于恢复应用被系统中断（如拍照时切到后台后被回收）时未能完整处理的媒体选择结果。
5. **生命周期**：部分接口内部使用 `flutter_plugin_android_lifecycle` 管理生命周期回调。

## 接口说明

| 方法 | 返回类型 | OHOS平台支持 | 描述          |
|------|---------|--------|-------------|
| `pickImage()` | `Future<PickedFile?>` | yes | 选择单张图片（传统接口） |
| `pickMultiImage()` | `Future<List<PickedFile>?>` | yes | 选择多张图片（传统接口）|
| `pickVideo()` | `Future<PickedFile?>` | yes | 选择单个视频（传统接口）|
| `getImage()` | `Future<XFile?>` | yes | 获取单张图片 |
| `getImageFromSource()` | `Future<XFile?>` | yes | 从指定源获取图片，支持 `ImagePickerOptions` 参数 |
| `getMultiImage()` | `Future<List<XFile>?>` | yes | 获取多张图片 |
| `getMultiImageWithOptions()` | `Future<List<XFile>>` | yes | 带选项获取多张图片，支持 `MultiImagePickerOptions` |
| `getMedia()` | `Future<List<XFile>>` | yes | 获取媒体文件（图片和视频混合），支持 `MediaOptions` |
| `getVideo()` | `Future<XFile?>` | yes | 获取视频 |
| `getMultiVideoWithOptions()` | `Future<List<XFile>>` | yes | 带选项获取多个视频，支持 `MultiVideoPickerOptions` |
| `retrieveLostData()` | `Future<LostData>` | yes | 恢复丢失的数据（兼容接口，返回 `PickedFile`）|
| `getLostData()` | `Future<LostDataResponse>` | yes | 获取丢失的数据（返回 `XFile`）|

## 目录结构

```
image_picker_ohos/
├── lib/                          # Dart 源码
│   ├── image_picker_ohos.dart    # 插件入口，ImagePickerOhos 类
│   └── src/
│       └── messages.g.dart       # Pigeon 自动生成的消息通信代码
├── ohos/                         # OpenHarmony 平台实现
│   ├── BuildProfile.ets
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── index.ets                 # HAR 模块入口
│   ├── oh-package.json5          # HAR 包配置（版本 1.0.0）
│   └── src/main/
│       ├── module.json5          # 模块配置（权限声明）
│       └── ets/image_picker/     # ArkTS 原生实现
│           ├── DateTimeUtil.ts
│           ├── ExifDataCopier.ets
│           ├── FileUtils.ets
│           ├── ImagePickerCache.ets
│           ├── ImagePickerDelegate.ets   # 媒体选择核心委托
│           ├── ImagePickerPlugin.ets     # 插件入口（注册方法通道）
│           ├── ImagePickerUtils.ets
│           ├── ImageResizer.ets          # 图片压缩裁剪
│           └── Messages.ets              # 消息通信处理
├── example/                      # Flutter 示例应用
│   ├── lib/
│   │   └── main.dart             # 示例主程序
│   ├── integration_test/
│   └── test_driver/
├── test/                         # 单元测试
├── CHANGELOG.md                  # 版本变更日志
├── LICENSE                       # BSD 3-Clause 许可证
├── OAT.xml                       # 开源合规配置文件
└── pubspec.yaml                  # Dart 包配置
```

## 贡献代码

欢迎贡献代码或提交 Issue！请访问 [仓库地址](https://gitcode.com/CPF-Flutter/flutter_packages/tree/master/packages/image_picker/image_picker_ohos) 提交 Pull Request 或反馈问题。

## 开源协议

本项目基于 [BSD 3-Clause License](LICENSE) 开源。
