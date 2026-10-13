import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_storage.dart';

Future<AppStorage> createCacheStorage() async {
  final directory = await getApplicationSupportDirectory();
  return FileCacheStorage(Directory('${directory.path}/schedule_cache'));
}

class FileCacheStorage implements AppStorage {
  FileCacheStorage(this.directory);
  final Directory directory;
  Future<void> _pending = Future.value();

  File _file(String key) {
    final name = base64Url.encode(utf8.encode(key));
    return File('${directory.path}/$name.json');
  }

  @override
  Future<String?> read(String key) async {
    await _pending;
    final file = _file(key);
    return await file.exists() ? file.readAsString() : null;
  }

  // 所有写入和删除串行执行，退出清理不会被较早发起的写入覆盖。
  Future<void> _enqueue(Future<void> Function() operation) {
    final task = _pending.then((_) => operation());
    _pending = task.catchError((Object _) {});
    return task;
  }

  @override
  Future<void> write(String key, String value) => _enqueue(() async {
    await directory.create(recursive: true);
    final file = _file(key);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  });

  @override
  Future<void> delete(String key) => _enqueue(() async {
    final file = _file(key);
    if (await file.exists()) await file.delete();
  });

  @override
  Future<void> deleteByPrefix(String prefix) => _enqueue(() async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final filename = entry.uri.pathSegments.last;
      if (!filename.endsWith('.json')) continue;
      String key;
      try {
        key = utf8.decode(
          base64Url.decode(filename.substring(0, filename.length - 5)),
        );
      } on FormatException {
        continue; // 不触碰无法识别来源的文件。
      }
      if (key.startsWith(prefix)) await entry.delete();
    }
  });
}
