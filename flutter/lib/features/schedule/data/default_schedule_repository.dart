import 'dart:convert';

import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';

import '../models/course.dart';
import '../models/semester.dart';
import 'schedule_repository.dart';

class DefaultScheduleRepository extends ScheduleRepository {
  DefaultScheduleRepository(this.api, this.storage, String account)
    : _prefix = 'v1:${api.dio.options.baseUrl}:$account:';
  final ApiClient api;
  final AppStorage storage;
  final String _prefix;
  bool _active = true;
  final Map<String, Future<ScheduleSnapshot>> _pending = {};

  void _checkActive() {
    if (!_active) {
      throw const ApiException('账号已切换。', kind: FailureKind.cancelled);
    }
  }

  @override
  Future<List<Semester>> semesters({bool refresh = false}) async {
    final key = '${_prefix}semesters';
    _checkActive();
    final cached = await storage.read(key);
    List<Semester>? previous;
    if (cached != null) {
      try {
        previous = _parseSemesters(jsonDecode(cached));
        _checkActive();
        if (!refresh && previous.isNotEmpty) return previous;
      } on FormatException {
        await storage.delete(key);
      } on TypeError {
        await storage.delete(key);
      }
    }
    Object? raw;
    try {
      raw = await api.request('/api/v1/jwxt/semesters');
    } on ApiException catch (error) {
      // 学期目录定期更新，离线时仍可选择已缓存的学期。
      if (error.kind == FailureKind.network && previous != null) {
        _checkActive();
        return previous;
      }
      rethrow;
    }
    try {
      final result = _parseSemesters(raw);
      _checkActive();
      if (result.isEmpty) {
        await storage.delete(key);
      } else {
        await _writeCache(key, jsonEncode(raw));
      }
      await _writeCache(
        '${_prefix}semestersUpdatedAt',
        DateTime.now().toIso8601String(),
      );
      _checkActive();
      return result;
    } on FormatException {
      throw const ApiException(
        '学期信息不完整，请重试。',
        kind: FailureKind.invalidResponse,
      );
    } on TypeError {
      throw const ApiException(
        '学期信息格式异常，请重试。',
        kind: FailureKind.invalidResponse,
      );
    }
  }

  List<Semester> _parseSemesters(Object? raw) {
    final result = (raw as List)
        .map((item) => Semester.fromJson(item as Map<String, dynamic>))
        .toList();

    result.sort((a, b) {
      final year = b.schoolYear.compareTo(a.schoolYear);
      return year != 0 ? year : b.term.compareTo(a.term);
    });
    return List.unmodifiable(result);
  }

  @override
  Future<ScheduleSnapshot> load(String semesterId, {bool refresh = false}) {
    final requestKey = '$semesterId:$refresh';
    final pending = _pending[requestKey];
    if (pending != null) return pending;
    final task = _load(semesterId, refresh).whenComplete(() {
      _pending.remove(requestKey);
    });
    _pending[requestKey] = task;
    return task;
  }

  @override
  Future<ScheduleSnapshot> loadForWidget(
    String semesterId, {
    bool refresh = false,
  }) => _load(semesterId, refresh, allowOlderCache: true);

  Future<ScheduleSnapshot> _load(
    String semesterId,
    bool refresh, {
    bool allowOlderCache = false,
  }) async {
    _checkActive();
    final key = '${_prefix}table:$semesterId';
    final latest = await storage.read('${_prefix}latestTable');
    if (!refresh &&
        (allowOlderCache || latest == null || latest == semesterId)) {
      final cached = await storage.read(key);
      if (cached != null) {
        try {
          final body = jsonDecode(cached) as Map<String, dynamic>;
          final table = CourseTable.fromJson(
            body['table'] as Map<String, dynamic>,
          );
          if (table.semesterId != semesterId) {
            throw const FormatException('缓存学期不符');
          }
          _checkActive();
          return ScheduleSnapshot(
            table,
            DateTime.parse(body['updatedAt'] as String),
            fromCache: true,
          );
        } on FormatException {
          await storage.delete(key);
        } on TypeError {
          await storage.delete(key);
        }
      }
    }
    final raw = await api.request(
      '/api/v1/jwxt/course-table',
      query: {'semester_id': semesterId, if (refresh) 'refresh': '1'},
    );
    try {
      final table = CourseTable.fromJson(raw as Map<String, dynamic>);
      if (table.semesterId != semesterId) throw const FormatException('响应学期不符');
      final updatedAt = DateTime.now();
      _checkActive();
      await _writeCache(
        key,
        jsonEncode({
          'updatedAt': updatedAt.toIso8601String(),
          'table': table.toJson(),
        }),
      );
      _checkActive();
      await _writeCache('${_prefix}latestTable', semesterId);
      return ScheduleSnapshot(table, updatedAt);
    } on FormatException {
      throw const ApiException(
        '课表数据不完整，请稍后重试。',
        kind: FailureKind.invalidResponse,
      );
    } on TypeError {
      throw const ApiException(
        '课表数据格式异常，请稍后重试。',
        kind: FailureKind.invalidResponse,
      );
    }
  }

  Future<void> _writeCache(String key, String value) async {
    _checkActive();
    try {
      await storage.write(key, value);
    } catch (_) {
      // 缓存失败不应把已成功取得的在线课表变成加载失败。
    }
    _checkActive();
  }

  @override
  Future<int?> currentWeek({bool refresh = false}) async {
    final key = '${_prefix}currentWeek';
    if (!refresh) return int.tryParse(await storage.read(key) ?? '');
    final raw =
        await api.request('/api/v1/schedule/current-week')
            as Map<String, dynamic>;
    final week = (raw['CurrentWeek'] as num).toInt();
    await _writeCache(key, '$week');
    return week;
  }

  @override
  void invalidate() {
    _active = false;
  }

  @override
  Future<void> clear() async {
    invalidate();
    // 按账号前缀清理，即使旧学期已经从服务端目录中消失也不会遗漏。
    await storage.deleteByPrefix(_prefix);
  }
}
