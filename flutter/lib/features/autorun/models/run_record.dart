import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'autorun_models.dart';

class TrackLocation {
  const TrackLocation(this.id, this.location, this.edges);
  final int id;
  final String location;
  final List<int> edges;
  List<double> get coordinates =>
      location.split(',').map((v) => double.parse(v.trim())).toList();
}

List<TrackLocation> parseTrackMap(Object? raw) {
  List<dynamic> rows;
  if (raw is Map && raw['mapData'] is List) {
    final points = raw['mapData'] as List;
    if (points.length < 2) throw const FormatException('地图路径为空');
    rows = [
      for (var i = 0; i < points.length; i++)
        {
          'id': i,
          'location': points[i],
          'edge': [(i + 1) % points.length],
        },
    ];
  } else if (raw is List && raw.isNotEmpty) {
    rows = raw;
  } else {
    throw const FormatException('轨迹地图格式异常');
  }
  final locations = <TrackLocation>[];
  for (final raw in rows) {
    final row = autoRunMap(raw);
    final location = autoRunText(row['location']);
    if (row['id'] is! int ||
        row['edge'] is! List ||
        !RegExp(
          r'^[-+]?\d+(?:\.\d+)?\s*,\s*[-+]?\d+(?:\.\d+)?$',
        ).hasMatch(location)) {
      throw const FormatException('轨迹地图节点格式异常');
    }
    final edges = (row['edge'] as List).cast<int>();
    if (edges.any((v) => v < 0 || v >= rows.length)) {
      throw const FormatException('轨迹地图索引越界');
    }
    locations.add(TrackLocation(row['id'] as int, location, edges));
  }
  return locations;
}

String detectAutoRunCampus(
  List<dynamic> bounds,
  Map<String, dynamic> standard,
) {
  // 原版优先使用第一个非空校区名称，后续字段仅作空值兜底。
  var campusName = '';
  for (final key in ['campus', 'campusName', 'schoolCampus', 'schoolName']) {
    campusName = autoRunText(standard[key]);
    if (campusName.isNotEmpty) {
      break;
    }
  }
  if (RegExp('龙泉|longquan|lqy', caseSensitive: false).hasMatch(campusName)) {
    return 'longquan';
  }
  if (autoRunText(
        standard['campusId'] ?? standard['campusID'] ?? standard['campus_id'],
      ) ==
      '2') {
    return 'longquan';
  }
  for (final bound in bounds) {
    final numbers = RegExp(r'[+-]?\d+(?:\.\d+)?')
        .allMatches(autoRunText(autoRunMap(bound)['siteBound']))
        .take(2)
        .map((match) => double.parse(match.group(0)!))
        .toList();
    if (numbers.length == 2 &&
        ((numbers[0] - 104.306).abs() <= .02 &&
                (numbers[1] - 30.607).abs() <= .02 ||
            (numbers[1] - 104.306).abs() <= .02 &&
                (numbers[0] - 30.607).abs() <= .02)) {
      return 'longquan';
    }
  }
  return 'airport';
}

Future<Map<String, Object?>> prepareAutoRunRecord(
  Map<String, dynamic> preparation,
) async {
  final standard = autoRunMap(preparation['runStandard']);
  final bounds = preparation['bounds'] is List
      ? preparation['bounds'] as List
      : <dynamic>[];
  final campus = detectAutoRunCampus(bounds, standard);
  final filename = campus == 'longquan' ? 'map-longquan.json' : 'map.json';
  final locations = parseTrackMap(
    jsonDecode(await rootBundle.loadString('assets/data/autorun/$filename')),
  );
  return buildAutoRunRecord(preparation, locations);
}

/// 保留原 Vue 的字段、校区识别、轨迹格式与北京时间日期，服务端负责转发签名。
Map<String, Object?> buildAutoRunRecord(
  Map<String, dynamic> preparation,
  List<TrackLocation> locations, {
  DateTime? now,
  double Function()? random,
  int? distance,
  int? duration,
}) {
  now ??= DateTime.now();
  random ??= Random.secure().nextDouble;
  distance ??= 4675 + (random() * 500).floor();
  duration ??= 31 + (random() * 5).floor();
  final standard = autoRunMap(preparation['runStandard']);
  final semester = autoRunText(standard['semesterYear']);
  if (semester.isEmpty) throw const FormatException('跑步标准缺少学期');
  final userId = autoRunNumber(preparation['userId']);
  if (userId == null || userId <= 0) throw const FormatException('校园跑用户信息不完整');
  final bounds = preparation['bounds'] as List? ?? [];
  final bound = bounds.isEmpty
      ? ''
      : autoRunText(autoRunMap(bounds.first)['siteBound']);
  return {
    'againRunStatus': '0',
    'againRunTime': 0,
    'appVersions': '1.8.5',
    'brand': 'Xiaomi',
    'mobileType': 'Mi 11',
    'sysVersions': 'Android 11',
    'trackPoints': generateAutoRunTrack(
      distance,
      locations,
      random: random,
      now: now,
    ),
    'distanceTimeStatus': '1',
    'innerSchool': '1',
    'runDistance': distance,
    'runTime': duration,
    'userId': userId.toInt(),
    'vocalStatus': '1',
    'yearSemester': semester,
    'recordDate': autoRunBusinessDate(now),
    'realityTrackPoints': bound.isEmpty ? '00.000,00.000--' : '$bound--',
  };
}

double trackDistance(List<double> start, List<double> end) {
  final lat1 = start[1] * pi / 180, lat2 = end[1] * pi / 180;
  final deltaLat = (end[1] - start[1]) * pi / 180,
      deltaLng = (end[0] - start[0]) * pi / 180;
  final a =
      pow(sin(deltaLat / 2), 2) +
      cos(lat1) * cos(lat2) * pow(sin(deltaLng / 2), 2);
  return 6371000 * 2 * atan2(sqrt(a.clamp(0, 1)), sqrt((1 - a).clamp(0, 1)));
}

String generateAutoRunTrack(
  int distance,
  List<TrackLocation> locations, {
  required double Function() random,
  required DateTime now,
}) {
  if (distance <= 0 || distance > 100000 || locations.isEmpty) {
    throw const FormatException('跑步距离或轨迹地图无效');
  }
  int randomInt(int max) =>
      max <= 1 ? 0 : min(max - 1, (random() * max).floor());
  String accuracy() => (10 * random().clamp(0, 1)).toStringAsFixed(1);
  String point(List<double> coords, int time) =>
      '${coords[0].toStringAsFixed(6)}-${coords[1].toStringAsFixed(6)}-$time-${accuracy()}';
  var current = locations[randomInt(locations.length)];
  var coordinates = current.coordinates;
  var timestamp = now.millisecondsSinceEpoch - 30 * 60 * 1000;
  var previousId = -1;
  var traversed = 0.0;
  final result = <String>[point(coordinates, timestamp)];
  for (var hops = 0; traversed < distance && hops < 10000; hops++) {
    if (current.edges.isEmpty) break;
    final position = randomInt(current.edges.length);
    var edge = current.edges[position];
    if (edge == previousId && current.edges.length > 1) {
      edge = current.edges[(position + 1) % current.edges.length];
    }
    final next = locations[edge];
    final end = next.coordinates;
    traversed += trackDistance(coordinates, end);
    var previous = coordinates;
    for (var step = 0; step < 10; step++) {
      final ratio = random().clamp(0, 1);
      final intermediate = [
        previous[0] + (end[0] - previous[0]) * ratio,
        previous[1] + (end[1] - previous[1]) * ratio,
      ];
      timestamp +=
          (trackDistance(previous, intermediate) / (randomInt(4) + 1) * 1000)
              .truncate();
      result.add(point(intermediate, timestamp));
      previous = intermediate;
    }
    timestamp += (trackDistance(previous, end) / (randomInt(4) + 1) * 1000)
        .truncate();
    result.add(point(end, timestamp));
    previousId = current.id;
    current = next;
    coordinates = end;
  }
  timestamp += (randomInt(6) + 5) * 1000;
  result.add(
    '${current.location.replaceAll(',', '-')}-$timestamp-${accuracy()}',
  );
  return jsonEncode(result);
}
