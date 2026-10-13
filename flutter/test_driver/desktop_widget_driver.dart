import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final device = Platform.environment['WIDGET_TEST_DEVICE'];
  if (device == null || device.isEmpty) {
    throw StateError('请设置 WIDGET_TEST_DEVICE 为已有 iOS 模拟器标识。');
  }
  Future<String> simctl(List<String> arguments) async {
    final result = await Process.run(
      '/usr/bin/xcrun',
      ['simctl', ...arguments],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return '${result.stdout}'.trim();
  }

  // iOS 截图回调在测试结束后才执行；用本机测试端点同步触发系统链接。
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18765);
  server.listen((request) async {
    try {
      if (request.uri.path == '/open-schedule') {
        final container = await simctl([
          'get_app_container',
          device,
          'org.dpdns.fanxiaogao05.chengxin.flutter',
          'group.org.dpdns.fanxiaogao05.chengxin.flutter',
        ]);
        final data =
            jsonDecode(
                  await File(
                    '$container/schedule-widget-v1.json',
                  ).readAsString(),
                )
                as Map;
        if (data['status'] != 'ready' || (data['days'] as List).isEmpty) {
          throw StateError('原生共享文件没有收到课表。');
        }
        await simctl(['openurl', device, 'chengxinyouyou://widget/schedule']);
      } else if (request.uri.path == '/verify-cleared') {
        final container = await simctl([
          'get_app_container',
          device,
          'org.dpdns.fanxiaogao05.chengxin.flutter',
          'group.org.dpdns.fanxiaogao05.chengxin.flutter',
        ]);
        final data =
            jsonDecode(
                  await File(
                    '$container/schedule-widget-v1.json',
                  ).readAsString(),
                )
                as Map;
        if (data['status'] != 'loggedOut' ||
            (data['days'] as List).isNotEmpty) {
          throw StateError('退出后原生共享文件仍然包含课程。');
        }
      } else {
        throw StateError('未知测试命令。');
      }
      request.response.statusCode = HttpStatus.ok;
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(error);
    } finally {
      await request.response.close();
    }
  });
  try {
    await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final directory = Directory('screenshots');
        await directory.create(recursive: true);
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
    );
  } finally {
    await server.close(force: true);
  }
}
