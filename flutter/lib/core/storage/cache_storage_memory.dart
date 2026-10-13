import 'app_storage.dart';

Future<AppStorage> createCacheStorage() async => MemoryAppStorage();
