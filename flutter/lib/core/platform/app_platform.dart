import 'package:flutter/foundation.dart';

/// 官方 Flutter 没有 ohos 枚举，用名称识别以便两套工具链共用源码。
bool get isHarmonyOS => !kIsWeb && defaultTargetPlatform.name == 'ohos';
