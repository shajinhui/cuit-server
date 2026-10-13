import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

/// 私密数据与普通课表缓存分开保存，便于分别清理和测试。
abstract interface class AppStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// 删除明确账号前缀下的全部条目，避免学期目录更新后遗漏旧课表。
  Future<void> deleteByPrefix(String prefix);
}

class SecureAppStorage implements AppStorage {
  const SecureAppStorage(this.storage);
  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: key);

  @override
  Future<void> deleteByPrefix(String prefix) async {
    final values = await storage.readAll();
    for (final key in values.keys) {
      if (key.startsWith(prefix)) await storage.delete(key: key);
    }
  }
}

/// 鸿蒙用 ASSET 保护密钥、AES-GCM 加密数据；原生错误直接交给会话处理。
class OhosSecureAppStorage implements AppStorage {
  const OhosSecureAppStorage();
  static const channel = MethodChannel('chengxin_youyou/secure_storage');

  @override
  Future<String?> read(String key) =>
      channel.invokeMethod<String>('read', {'key': key});

  @override
  Future<void> write(String key, String value) =>
      channel.invokeMethod<void>('write', {'key': key, 'value': value});

  @override
  Future<void> delete(String key) =>
      channel.invokeMethod<void>('delete', {'key': key});

  @override
  Future<void> deleteByPrefix(String prefix) =>
      channel.invokeMethod<void>('deleteByPrefix', {'prefix': prefix});
}

/// 演示和测试只使用内存，不接触用户已有的本机数据。
class MemoryAppStorage implements AppStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    values.removeWhere((key, _) => key.startsWith(prefix));
  }
}
