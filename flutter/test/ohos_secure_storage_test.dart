import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = OhosSecureAppStorage();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(OhosSecureAppStorage.channel, null);
  });

  test('安全存储不可用时，读写和退出清理都保留失败，避免误报成功', () async {
    messenger.setMockMethodCallHandler(OhosSecureAppStorage.channel, (_) async {
      throw PlatformException(code: 'secure_storage_failed');
    });

    for (final operation in [
      storage.read('session'),
      storage.write('session', 'token'),
      storage.delete('session'),
      storage.deleteByPrefix('cookies:https://example.test:'),
    ]) {
      await expectLater(operation, throwsA(isA<PlatformException>()));
    }
  });

  test('Cookie 账号前缀原样传给原生层，不用 readAll 暴露其他账号数据', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(OhosSecureAppStorage.channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });

    await storage.deleteByPrefix('cookies:https://example.test:');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'deleteByPrefix');
    expect(calls.single.arguments, {'prefix': 'cookies:https://example.test:'});
  });
}
