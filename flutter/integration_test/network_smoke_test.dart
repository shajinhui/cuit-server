import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 真机/模拟器上的联网冒烟测试。
///
/// 目标不是登录成功，而是确认请求真的离开了设备：服务端返回 401/404 也算
/// 联通，只有 `FailureKind.network` 才说明适配器/网络栈没工作。
///
/// ```bash
/// ./tool/flutter.sh drive --profile \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/network_smoke_test.dart \
///   -d <设备标识>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('安卓网络适配器可以连到接口', (tester) async {
    final api = await ApiClient.create(
      'https://api.fanxiaogao05.dpdns.org',
      MemoryAppStorage(),
    );
    try {
      await api.request('/api/v1/jwxt/session');
    } on ApiException catch (error) {
      expect(
        error.kind,
        isNot(FailureKind.network),
        reason: '请求没有离开设备：${error.message}',
      );
      debugPrint('SMOKE_OK kind=${error.kind.name} message=${error.message}');
    } finally {
      api.dispose();
    }
  });
}
