import 'dart:math' as math;

Map<String, dynamic> autoRunMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
String autoRunText(Object? value) => value?.toString().trim() ?? '';
double? autoRunNumber(Object? value) {
  if (value is String && value.trim().isEmpty) return 0;
  final number = value is num
      ? value.toDouble()
      : double.tryParse(autoRunText(value));
  return number != null && number.isFinite ? number : null;
}

double? _firstNumber(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = autoRunNumber(map[key]);
    if (value != null) return value;
  }
  return null;
}

double _target(Map<String, dynamic> map, List<String> keys, double fallback) {
  final values = keys
      .map((key) => autoRunNumber(map[key]))
      .whereType<double>()
      .where((v) => v > 0)
      .toList();
  return values.isEmpty ? fallback : values.reduce(math.max);
}

class AutoRunProgress {
  const AutoRunProgress(this.title, this.current, this.target, this.unit);
  final String title, unit;
  final double current, target;
  int get percent =>
      (current / math.max(target, 1) * 100).clamp(0, 100).round();
  static List<AutoRunProgress> fromJson(Map<String, dynamic> data) {
    final info = autoRunMap(data['runInfo']),
        standard = autoRunMap(data['runStandard']);
    final count = _firstNumber(info, ['runValidCount', 'runCount']) ?? 0;
    final countTarget = _target(standard, [
      'boyAllRunTime',
      'girlAllRunTime',
      'allRunTime',
      'runTimes',
      'runCount',
      'targetRunCount',
      'minRunCount',
      'effectiveRunCount',
      'totalRunCount',
    ], 20);
    final distance = _kilometres(
      _firstNumber(info, ['runValidDistance', 'runDistance']) ?? 0,
    );
    final distanceTarget = _kilometres(
      _target(standard, [
        'boyAllRunDistance',
        'girlAllRunDistance',
        'allRunDistance',
        'runDistance',
        'targetDistance',
        'minRunDistance',
        'effectiveDistance',
        'totalDistance',
      ], 60),
    );
    return [
      AutoRunProgress('有效次数', count, math.max(countTarget, 1), '次'),
      AutoRunProgress(
        '有效距离',
        double.parse(distance.toStringAsFixed(1)),
        double.parse(math.max(distanceTarget, 1).toStringAsFixed(1)),
        'km',
      ),
    ];
  }

  static double _kilometres(double value) =>
      value.abs() >= 1000 ? value / 1000 : value;
}

class AutoRunActivity {
  const AutoRunActivity({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.address,
    required this.joined,
    required this.capacity,
    required this.isJoined,
    required this.isUnavailable,
  });
  final int id, joined, capacity;
  final String title, startTime, endTime, address;
  final bool isJoined, isUnavailable;
  bool get isFull => capacity > 0 && joined >= capacity;
  bool get canJoin => id > 0 && (isJoined || (!isFull && !isUnavailable));
  factory AutoRunActivity.fromJson(Map<String, dynamic> data) {
    final joined =
        (_firstNumber(data, ['signInStudent', 'applyStudentCount']) ?? 0)
            .toInt();
    final capacity = (autoRunNumber(data['maxStudent']) ?? 0).toInt();
    final isJoined = autoRunText(data['optionStatus']) == '1';
    return AutoRunActivity(
      id: (autoRunNumber(data['clubActivityId']) ?? 0).toInt(),
      title: autoRunText(data['activityName']).isEmpty
          ? '未命名活动'
          : autoRunText(data['activityName']),
      startTime: autoRunText(data['startTime']),
      endTime: autoRunText(data['endTime']),
      address: autoRunText(data['addressDetail']).isNotEmpty
          ? autoRunText(data['addressDetail'])
          : autoRunText(data['teacherName']).isNotEmpty
          ? autoRunText(data['teacherName'])
          : '地点待公布',
      joined: joined,
      capacity: capacity,
      isJoined: isJoined,
      isUnavailable:
          !isJoined &&
          !(capacity > 0 && joined >= capacity) &&
          (autoRunText(data['optionStatus']) == '3' ||
              autoRunText(data['fullActivity']) == '1'),
    );
  }
}

class AutoRunSignTask {
  AutoRunSignTask(Map<String, dynamic> data)
    : id = (_firstNumber(data, ['activityId', 'clubActivityId']) ?? 0).toInt(),
      name = autoRunText(data['activityName']),
      startTime = autoRunText(data['startTime']),
      endTime = autoRunText(data['endTime']),
      address = autoRunText(data['address']).isEmpty
          ? autoRunText(data['addressDetail'])
          : autoRunText(data['address']),
      latitude = autoRunText(data['latitude']),
      longitude = autoRunText(data['longitude']),
      status = autoRunText(data['signStatus']),
      signedIn = autoRunText(data['signInStatus']) == '1',
      signedBack = autoRunText(data['signBackStatus']) == '1';
  final int id;
  final String name, startTime, endTime, address, latitude, longitude, status;
  final bool signedIn, signedBack;
  String? get signType => !signedIn && status == '1'
      ? '1'
      : signedIn && !signedBack
      ? '2'
      : null;
  bool get canSign =>
      id > 0 && (signType == '1' || (signType == '2' && status == '2'));
  String get description => signedIn && signedBack
      ? '已完成签到/签退'
      : signedIn
      ? status == '2'
            ? '已签到，可签退'
            : '已签到，等待签退'
      : status == '1'
      ? '可签到'
      : '等待签到';
}

String autoRunDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String autoRunBusinessDate(DateTime value) =>
    autoRunDate(value.toUtc().add(const Duration(hours: 8)));
String autoRunFormatNumber(double value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(1);

/// 上游没有时区的活动时间按北京时间解释，避免手机时区改变签到窗口。
DateTime? autoRunEventTime(String date, String time) {
  if (time.isEmpty || time == '--:--') return null;
  var value = time.replaceAll('/', '-').replaceFirst(' ', 'T');
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)) value = '${date}T$value';
  if (!RegExp(r'Z$|[+-]\d{2}:?\d{2}$').hasMatch(value)) value += '+08:00';
  return DateTime.tryParse(value);
}
