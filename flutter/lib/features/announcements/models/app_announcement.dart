/// 公告只展示纯文本和 HTTPS 按钮，不执行服务器下发的 HTML 或脚本。
class AppAnnouncement {
  const AppAnnouncement({
    required this.id,
    required this.revision,
    required this.title,
    required this.body,
    required this.autoShow,
    this.actionLabel,
    this.actionUrl,
    this.startsAt,
    this.expiresAt,
  });

  final String id;
  final int revision;
  final String title;
  final String body;
  final bool autoShow;
  final String? actionLabel;
  final Uri? actionUrl;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  String get viewKey => '$id:$revision';

  bool isActive(DateTime now) =>
      (startsAt == null || !startsAt!.isAfter(now)) &&
      (expiresAt == null || expiresAt!.isAfter(now));

  factory AppAnnouncement.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('公告格式异常');
    final id = value['id'], revision = value['revision'];
    if (id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
        revision is! int ||
        revision < 1 ||
        value['auto_show'] is! bool) {
      throw const FormatException('公告格式异常');
    }
    String? label;
    Uri? uri;
    if (value['action'] != null) {
      final action = value['action'];
      if (action is! Map) throw const FormatException('公告按钮格式异常');
      label = _text(action['label'], 30);
      final url = _text(action['url'], 2048);
      uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          RegExp(r'[\x00-\x20]').hasMatch(url)) {
        throw const FormatException('公告链接无效');
      }
    }
    final start = _date(value['starts_at']), end = _date(value['expires_at']);
    if (start != null && end != null && !end.isAfter(start)) {
      throw const FormatException('公告时间无效');
    }
    return AppAnnouncement(
      id: id,
      revision: revision,
      title: _text(value['title'], 80),
      body: _text(value['body'], 4000),
      autoShow: value['auto_show'] as bool,
      actionLabel: label,
      actionUrl: uri,
      startsAt: start,
      expiresAt: end,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'title': title,
    'body': body,
    'auto_show': autoShow,
    'action': actionUrl == null
        ? null
        : {'label': actionLabel, 'url': actionUrl.toString()},
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'expires_at': expiresAt?.toUtc().toIso8601String(),
  };
}

String _text(Object? value, int limit) {
  if (value is! String || value.trim().isEmpty || value.runes.length > limit) {
    throw const FormatException('公告文本格式异常');
  }
  return value.trim();
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('公告时间格式异常');
  }
  final date = DateTime.tryParse(value);
  if (date == null) throw const FormatException('公告时间格式异常');
  return date;
}
