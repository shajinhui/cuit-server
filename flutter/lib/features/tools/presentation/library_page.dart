import 'dart:typed_data';

import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';
import '../../../ui/components/page_selection.dart';

import 'package:url_launcher/url_launcher.dart';

import 'tool_page_scaffold.dart';
import 'library_reservation_dialog.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.api});
  final ApiClient? api;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _kinds = ['seat', 'study', 'reservations'];
  String _tab = 'seat';
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _seats = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _autoRenewals = [];
  String _roomId = '';
  String _startDate = _dateString(DateTime.now());
  String _endDate = _dateString(DateTime.now().add(const Duration(days: 6)));
  String _startTime = '08:00';
  String _endTime = '22:00';
  String? _error;
  bool _loading = true;
  bool _searched = false;
  String _captchaMode = 'none';
  String _officialUrl = '';
  bool _memoRequired = false;
  int? _memoMaximumLength;
  bool _capabilitiesLoaded = false;
  int _requestVersion = 0;

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCapabilities();
    if (mounted) await _loadTab();
  }

  @override
  void dispose() {
    _requestVersion++;
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    try {
      final raw = await widget.api!.request('/api/v1/library/capabilities');
      if (raw is Map && mounted) {
        setState(() {
          _captchaMode = (raw['CaptchaMode'] ?? 'none').toString();
          _officialUrl = (raw['OfficialURL'] ?? '').toString();
          _memoRequired = raw['MemoRequired'] == true;
          final maximum = raw['MemoMaximumLength'];
          _memoMaximumLength = maximum is num && maximum > 0
              ? maximum.toInt()
              : null;
          _capabilitiesLoaded = true;
        });
      }
    } catch (_) {
      // 筛选和读取失败时会在主区域显示实际接口错误。
    }
  }

  Future<void> _loadTab() async {
    if (!mounted) return;
    final version = ++_requestVersion;
    final tab = _tab;
    if (widget.api == null) {
      setState(() {
        _error = '服务暂不可用。';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (tab == 'reservations') {
        final raw = await widget.api!.request('/api/v1/library/reservations');
        if (raw is! List) throw const ApiException('预约列表格式异常。');
        List<Map<String, dynamic>> autoRenewals = [];
        try {
          final renewalRaw = await widget.api!.request(
            '/api/v1/library/auto-renewals',
          );
          if (renewalRaw is List) {
            autoRenewals = renewalRaw.cast<Map<String, dynamic>>();
          }
        } catch (_) {
          // 自动续座列表失败时，仍展示已有预约记录。
        }
        if (mounted && version == _requestVersion) {
          setState(() {
            _reservations = raw.cast<Map<String, dynamic>>();
            _autoRenewals = autoRenewals;
            _loading = false;
          });
        }
        return;
      }
      final raw = await widget.api!.request(
        '/api/v1/library/areas',
        query: {'kind': tab},
      );
      if (raw is! List) throw const ApiException('区域列表格式异常。');
      final areas = <Map<String, dynamic>>[];
      for (final item in raw.cast<Map<String, dynamic>>()) {
        _flattenArea(item, '', areas);
      }
      final selected = areas.any((item) => '${item['ID']}' == _roomId)
          ? _roomId
          : (areas.isEmpty ? '' : '${areas.first['ID']}');
      if (mounted && version == _requestVersion) {
        setState(() {
          _areas = areas;
          _roomId = selected;
          _seats = [];
          _searched = false;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() {
          _error = _errorText(error);
          _loading = false;
        });
      }
    }
  }

  void _flattenArea(
    Map<String, dynamic> area,
    String parent,
    List<Map<String, dynamic>> output,
  ) {
    final name = (area['Name'] ?? '').toString();
    final path = parent.isEmpty ? name : '$parent / $name';
    final children = area['Children'];
    if (children is List && children.isNotEmpty) {
      for (final child in children.cast<Map<String, dynamic>>()) {
        _flattenArea(child, path, output);
      }
    } else {
      output.add({...area, 'DisplayName': path});
    }
  }

  Future<void> _selectTab(String tab) async {
    if (!_kinds.contains(tab) || tab == _tab) return;
    setState(() {
      _tab = tab;
      _roomId = '';
      _seats = [];
      _searched = false;
      if (tab == 'study') {
        _startDate = _dateString(DateTime.now());
        _endDate = _dateString(DateTime.now().add(const Duration(days: 6)));
      }
    });
    await _loadTab();
  }

  Future<void> _searchSeats() async {
    if (!mounted) return;
    final version = ++_requestVersion;
    if (_roomId.isEmpty) {
      setState(() => _error = '请先选择预约区域。');
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });
    try {
      final raw = await widget.api!.request(
        '/api/v1/library/seats',
        query: {
          'kind': _tab,
          'room_id': _roomId,
          'start_date': _startDate,
          'end_date': _tab == 'study' ? _endDate : _startDate,
          'start_time': _tab == 'seat' ? _startTime : '',
          'end_time': _tab == 'seat' ? _endTime : '',
        },
      );
      if (raw is! List) throw const ApiException('座位列表格式异常。');
      if (mounted && version == _requestVersion) {
        setState(() {
          _seats = raw.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() {
          _error = _errorText(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _createReservation(Map<String, dynamic> seat) async {
    if (!_capabilitiesLoaded) {
      await _loadCapabilities();
      if (!mounted) return;
      if (!_capabilitiesLoaded) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('预约规则读取失败，请稍后重试')));
        return;
      }
    }
    if (_captchaMode == 'interactive') {
      if (_officialUrl.isNotEmpty) {
        await launchUrl(
          Uri.parse(_officialUrl),
          mode: LaunchMode.externalApplication,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此预约需要图书馆官网的交互式验证，请在官网完成预约。')),
        );
      }
      return;
    }
    // 保存发起预约时的筛选条件，验证码读取期间切换区域也不会串单。
    final parameters = <String, Object?>{
      'Kind': _tab,
      'RoomID': _roomId,
      'SeatID': (seat['ID'] ?? '').toString(),
      'StartDate': _startDate,
      'EndDate': _tab == 'study' ? _endDate : _startDate,
      'StartTime': _tab == 'seat' ? _startTime : '',
      'EndTime': _tab == 'seat' ? _endTime : '',
      'Title': '座位预约',
    };
    final period = _tab == 'seat'
        ? '$_startDate · $_startTime–$_endTime'
        : '$_startDate 至 $_endDate';
    Uint8List? captchaBytes;
    if (_captchaMode == 'image') {
      try {
        final response = await widget.api!.dio.get<List<int>>(
          '/api/v1/library/captcha',
          queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null) {
          captchaBytes = Uint8List.fromList(response.data!);
        }
      } catch (_) {
        // 弹窗保留失败提示并禁止提交，关闭后可重新读取验证码。
      }
    }
    if (!mounted) return;
    final input = await showPageDialog<LibraryReservationInput>(
      context,
      builder: (_) => LibraryReservationDialog(
        seatName: '${seat['Number'] ?? seat['Name'] ?? '座位'}',
        period: period,
        memoRequired: _memoRequired,
        memoMaximumLength: _memoMaximumLength,
        needsCaptcha: _captchaMode == 'image',
        captchaBytes: captchaBytes,
      ),
    );
    if (input == null || !mounted) return;
    try {
      await widget.api!.request(
        '/api/v1/library/reservations',
        method: 'POST',
        data: {...parameters, 'Memo': input.memo, 'Captcha': input.captcha},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预约已提交')));
      await _searchSeats();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _cancelReservation(Map<String, dynamic> reservation) async {
    final confirmed = await showPageConfirmation(
      context,
      title: '取消这次预约？',
      content: const Text('取消后座位会重新释放。'),
      cancelLabel: '保留',
      confirmLabel: '确认取消',
      destructive: true,
    );
    if (confirmed != true) return;
    await _runReservationAction(reservation, 'cancel');
  }

  Future<void> _runReservationAction(
    Map<String, dynamic> reservation,
    String action,
  ) async {
    if (action != 'cancel') {
      final confirmed = await showPageConfirmation(
        context,
        title: action == 'finish' ? '提前结束预约？' : '登记暂离？',
        content: Text(
          action == 'finish' ? '结束后无法恢复，请确认已离开座位。' : '请在图书馆规定时间内返回。',
        ),
        cancelLabel: '返回',
        destructive: action == 'finish',
      );
      if (confirmed != true) return;
    }
    final uuid = Uri.encodeComponent('${reservation['UUID']}');
    try {
      if (action == 'cancel') {
        await widget.api!.request(
          '/api/v1/library/reservations/$uuid',
          method: 'DELETE',
        );
      } else if (action == 'finish') {
        await widget.api!.request(
          '/api/v1/library/reservations/$uuid/finish',
          method: 'POST',
        );
      } else {
        await widget.api!.request(
          '/api/v1/library/reservations/$uuid/temporary-leave',
          method: 'POST',
          data: {'ReservationID': reservation['ReservationID']},
        );
      }
      await _loadTab();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (action) {
              'finish' => '预约已提前结束',
              'temporary-leave' => '已登记暂离',
              _ => '预约已取消',
            }),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _changeRenewal(
    Map<String, dynamic> reservation, {
    required bool automatic,
  }) async {
    final reservationId = '${reservation['ReservationID']}';
    try {
      final raw = await widget.api!.request(
        '/api/v1/library/reservations/${Uri.encodeComponent(reservationId)}/renewal-options',
      );
      if (raw is! Map || raw['Durations'] is! List) {
        throw const ApiException('续座选项格式异常。');
      }
      final durations = (raw['Durations'] as List)
          .whereType<num>()
          .map((value) => value.toInt())
          .toList();
      if (durations.isEmpty) {
        throw const ApiException('当前预约没有可用的续座时长。');
      }
      if (!mounted) return;
      final minutes = await showPageChoice<int>(
        context,
        title: automatic ? '设置自动续座' : '选择续座时长',
        values: {
          for (final duration in durations) duration: _durationLabel(duration),
        },
      );
      if (minutes == null) return;
      await widget.api!.request(
        '/api/v1/library/reservations/${Uri.encodeComponent(reservationId)}${automatic ? '/auto-renewal' : '/renew'}',
        method: automatic ? 'PUT' : 'POST',
        data: {'DurationMinutes': minutes},
      );
      await _loadTab();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(automatic ? '已设置自动续座' : '已提交续座')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _cancelAutoRenewal(Map<String, dynamic> reservation) async {
    final confirmed = await showPageConfirmation(
      context,
      title: '关闭自动续座？',
      content: const Text('关闭后，系统不会再为这次预约自动提交续座。'),
      cancelLabel: '保留',
      confirmLabel: '确认关闭',
    );
    if (confirmed != true) return;
    final id = Uri.encodeComponent('${reservation['ReservationID']}');
    try {
      await widget.api!.request(
        '/api/v1/library/reservations/$id/auto-renewal',
        method: 'DELETE',
      );
      await _loadTab();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已关闭自动续座')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _chooseDate({required bool end}) async {
    final current =
        DateTime.tryParse(end ? _endDate : _startDate) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (value == null) return;
    setState(() {
      if (end) {
        _endDate = _dateString(value);
      } else {
        _startDate = _dateString(value);
        if (_tab == 'seat') _endDate = _startDate;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ToolPageScaffold(
    title: '图书馆预约',
    actions: [
      IconButton(onPressed: _loadTab, icon: const Icon(Icons.refresh_rounded)),
    ],
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
          child: ToolSegmentedControl<String>(
            values: const {
              'seat': '座位',
              'study': '自修室',
              'reservations': '我的预约',
            },
            selected: _tab,
            onChanged: _selectTab,
          ),
        ),
        if (_loading)
          const Expanded(child: ToolLoading(label: '正在读取图书馆信息…'))
        else if (_error != null)
          Expanded(
            child: ToolMessage(message: _error!, onRetry: _loadTab),
          )
        else if (_tab == 'reservations')
          Expanded(child: _reservationList())
        else
          Expanded(child: _seatSearch()),
      ],
    ),
  );

  Widget _seatSearch() => ListView(
    padding: const EdgeInsets.fromLTRB(22, 10, 22, 48),
    children: [
      ToolCard(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToolField(
              label: '预约区域',
              child: PageDropdownField<String>(
                key: ValueKey(_roomId),
                value: _areas.any((area) => '${area['ID']}' == _roomId)
                    ? _roomId
                    : null,
                values: {
                  for (final area in _areas)
                    '${area['ID']}':
                        '${area['DisplayName']} · 余 ${area['Available'] ?? 0}/${area['Total'] ?? 0}',
                },
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _roomId = value;
                      _searched = false;
                      _seats = [];
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            ToolField(
              label: _tab == 'study' ? '开始日期' : '预约日期',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _chooseDate(end: false),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(_startDate),
                ),
              ),
            ),
            if (_tab == 'study') ...[
              const SizedBox(height: 12),
              ToolField(
                label: '结束日期',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _chooseDate(end: true),
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_endDate),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ToolField(
                      label: '开始时间',
                      child: _timePicker(
                        _startTime,
                        (value) => setState(() => _startTime = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ToolField(
                      label: '结束时间',
                      child: _timePicker(
                        _endTime,
                        (value) => setState(() => _endTime = value),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _tab == 'seat'
                  ? '普通座位以图书馆实时规则为准，通常可预约当天或次日。'
                  : '自修室按连续日期预约，资格与最长天数由图书馆实时校验。',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _roomId.isEmpty ? null : _searchSeats,
                child: const Text('查询可预约座位'),
              ),
            ),
          ],
        ),
      ),
      if (_searched && !_loading) ...[
        const SizedBox(height: 24),
        ToolSectionHeading(
          title: '查询结果',
          trailing:
              '${_seats.where((seat) => seat['Status'] == 'available' && seat['OnlyView'] != true).length} 个可约',
        ),
        const SizedBox(height: 14),
        if (_seats.isEmpty)
          const ToolCard(
            child: ToolMessage(message: '这个时段暂无可用座位。可以调整区域或时间后再次查询。'),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final seat in _seats)
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _seatCard(seat),
                  ),
              ],
            ),
          ),
      ],
    ],
  );

  Widget _seatCard(Map<String, dynamic> seat) {
    final available = seat['Status'] == 'available' && seat['OnlyView'] != true;
    final color = available
        ? toolAccent(context)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ToolCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: InkWell(
        onTap: available ? () => _createReservation(seat) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${seat['Name'] ?? seat['Number'] ?? '座位'}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [seat['Building'], seat['Room']]
                    .where((value) => value != null && '$value'.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 12),
              Text(
                available
                    ? '可预约'
                    : seat['OnlyView'] == true
                    ? '仅供查看'
                    : '不可预约',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reservationList() => _reservations.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(22),
          child: ToolCard(
            child: ToolMessage(message: '暂无预约记录。预约成功后，会在这里显示签到状态与可用操作。'),
          ),
        )
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 48),
          itemCount: _reservations.length,
          separatorBuilder: (_, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final reservation = _reservations[index];
            final hasAutoRenewal = _autoRenewals.any(
              (item) =>
                  '${item['ReservationID']}' ==
                      '${reservation['ReservationID']}' &&
                  item['Status'] == 'scheduled',
            );
            return ToolCard(
              radius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reservation['Kind'] == 'study' ? '自修室' : '普通座位',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${reservation['StatusLabel'] ?? ''}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: toolAccent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${reservation['Name'] ?? reservation['Seat'] ?? '图书馆预约'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${reservation['Room'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '开始  ${reservation['Start'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '结束  ${reservation['End'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (hasAutoRenewal)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('自动续座已开启', style: TextStyle(fontSize: 12)),
                    ),
                  if ('${reservation['TemporaryLeaveUntil'] ?? ''}'.isNotEmpty)
                    Text(
                      '暂离截止：${reservation['TemporaryLeaveUntil']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if ('${reservation['ViolationReason'] ?? ''}'.isNotEmpty)
                    Text(
                      '${reservation['ViolationReason']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (reservation['CanRenew'] == true &&
                          !hasAutoRenewal) ...[
                        TextButton(
                          onPressed: () =>
                              _changeRenewal(reservation, automatic: false),
                          child: const Text('立即续座'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _changeRenewal(reservation, automatic: true),
                          child: const Text('自动续座'),
                        ),
                      ],
                      if (hasAutoRenewal)
                        TextButton(
                          onPressed: () => _cancelAutoRenewal(reservation),
                          child: const Text('关闭自动续座'),
                        ),
                      if (reservation['CanTemporaryLeave'] == true)
                        TextButton(
                          onPressed: () => _runReservationAction(
                            reservation,
                            'temporary-leave',
                          ),
                          child: const Text('暂离'),
                        ),
                      if (reservation['CanFinish'] == true)
                        TextButton(
                          onPressed: () =>
                              _runReservationAction(reservation, 'finish'),
                          child: const Text('提前结束'),
                        ),
                      if (reservation['CanCancel'] == true)
                        TextButton(
                          onPressed: () => _cancelReservation(reservation),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          child: const Text('取消预约'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );

  Widget _timePicker(
    String value,
    ValueChanged<String> onChanged,
  ) => OutlinedButton(
    onPressed: () async {
      final parts = value.split(':').map(int.parse).toList();
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
      );
      if (time != null) {
        onChanged(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        );
      }
    },
    child: Text(value, style: const TextStyle(fontSize: 15)),
  );
}

String _errorText(Object error) =>
    error is ApiException ? error.message : '请求失败，请检查网络后重试。';

String _durationLabel(int minutes) => minutes < 60
    ? '$minutes 分钟'
    : minutes % 60 == 0
    ? '${minutes ~/ 60} 小时'
    : '${minutes ~/ 60} 小时 ${minutes % 60} 分钟';
