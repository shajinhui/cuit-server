import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chengxin_youyou/core/storage/cache_storage_native.dart';

void main() {
  late Directory directory;
  late FileCacheStorage cache;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cuit-cache-test-');
    cache = FileCacheStorage(directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('按账号清理包括目录中已不存在的历史学期，保留其他账号', () async {
    await cache.write('v1:api:one:table:old', 'old-course');
    await cache.write('v1:api:two:table:old', 'another-account');
    await cache.deleteByPrefix('v1:api:one:');
    expect(await cache.read('v1:api:one:table:old'), isNull);
    expect(await cache.read('v1:api:two:table:old'), 'another-account');
  });

  test('在途写入完成后再执行清理，不留下账号缓存', () async {
    final writing = cache.write('v1:api:one:table:new', 'new-course');
    final clearing = cache.deleteByPrefix('v1:api:one:');
    await Future.wait([writing, clearing]);
    expect(await cache.read('v1:api:one:table:new'), isNull);
    expect(await directory.list().toList(), isEmpty);
  });
}
