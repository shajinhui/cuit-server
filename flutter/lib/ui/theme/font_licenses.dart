import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 内置字体的授权文本登记到 Flutter 的「开源许可」页。
///
/// HarmonyOS Sans 的许可要求：软件中要显著声明使用了该字体、保留版权声明
/// 和许可全文，且不得修改字体文件本身。这里按需加载许可文本，不参与启动。
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/HARMONYOS_SANS_LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['HarmonyOS Sans SC'], license);
  });
}
