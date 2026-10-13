import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/components/glass_surface.dart';
import '../../autorun/data/autorun_repository.dart';
import '../../autorun/models/autorun_models.dart';
import '../../autorun/presentation/autorun_view_model.dart';
import 'tool_page_scaffold.dart';
import 'autorun_truck.dart';

/// 校园跑使用独立账号，全部操作在应用内完成。
class AutoRunPage extends StatefulWidget {
  const AutoRunPage({super.key, required this.repository});
  final AutoRunRepository? repository;
  @override
  State<AutoRunPage> createState() => _AutoRunPageState();
}

class _AutoRunPageState extends State<AutoRunPage> with WidgetsBindingObserver {
  AutoRunViewModel? _model;
  final _phone = TextEditingController(), _password = TextEditingController();
  int _tab = 0;
  Timer? _clock;
  DateTime _now = DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.repository != null) {
      _model = AutoRunViewModel(widget.repository!);
      unawaited(_model!.initialize());
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tab == 1 && _model?.signTask != null) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_model?.revalidateOnResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _model?.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(AutoRunViewModel model) async {
    if (_phone.text.trim().isEmpty || _password.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手机号和密码不能为空')));
      return;
    }
    FocusScope.of(context).unfocus();
    await model.login(_phone.text, _password.text);
    if (!mounted) return;
    if (model.authenticated) {
      _password.clear();
      if (_tab == 1) await model.loadClub();
    }
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (tab == 1 && _model?.authenticated == true) {
      unawaited(_model!.loadClub());
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    if (model == null) {
      return const ToolPageScaffold(
        title: '校园跑与俱乐部',
        child: ToolMessage(message: '校园跑服务暂不可用。'),
      );
    }
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) => ToolPageScaffold(
        title: '校园跑与俱乐部',
        header: const SizedBox.shrink(),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? null
            : _tab == 0
            ? const Color(0xFFF7F9FC)
            : const Color(0xFFF2F2F7),
        bottomNavigationBar: _bottomBar(model),
        child: model.checking
            ? const ToolLoading(label: '正在恢复校园跑账号…')
            : !model.authenticated
            ? _loginForm(model)
            : _tab == 2
            ? _account(model)
            : RefreshIndicator(
                onRefresh: _tab == 1 ? () => model.loadClub() : model.loadRun,
                child: ListView(
                  key: ValueKey('autorun-page-$_tab'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tab == 0 ? '校园跑' : '俱乐部',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_tab == 0)
                                const Text(
                                  '查看本学期运动进度',
                                  style: TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新',
                          onPressed: model.busy
                              ? null
                              : _tab == 1
                              ? () => model.loadClub()
                              : model.loadRun,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ..._messages(model),
                    if (_tab == 0) ..._run(model) else ..._club(model),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _bottomBar(AutoRunViewModel model) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 456),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回工具页',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
            ),
            if (model.authenticated) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GlassSurface(
                  lightweight: true,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (var index = 0; index < 3; index++)
                          Expanded(
                            child: Semantics(
                              selected: _tab == index,
                              child: TextButton(
                                key: Key('autorun-tab-$index'),
                                onPressed: () => _selectTab(index),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  backgroundColor: _tab == index
                                      ? toolAccent(
                                          context,
                                        ).withValues(alpha: .12)
                                      : Colors.transparent,
                                  foregroundColor: _tab == index
                                      ? toolAccent(context)
                                      : Theme.of(context).colorScheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/icons/navigation/${['nav-campus-run', 'nav-club', 'nav-profile-tab'][index]}.png',
                                      width: 24,
                                      height: 24,
                                      color: _tab == index
                                          ? toolAccent(context)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      excludeFromSemantics: true,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      ['校园跑', '俱乐部', '我的'][index],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  List<Widget> _messages(AutoRunViewModel model) => [
    if (model.error != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          model.error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    if (model.message != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(model.message!),
      ),
    if (model.busy)
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(),
      ),
  ];
  Widget _loginForm(AutoRunViewModel model) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ToolCard(
        padding: const EdgeInsets.all(24),
        radius: 26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '登录校园跑',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '请输入 unirun 手机号和密码，登录后密码不会保存。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            ToolField(
              label: '手机号',
              child: TextField(
                key: const Key('autorun-phone'),
                controller: _phone,
                enabled: !model.busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(hintText: '请输入手机号'),
              ),
            ),
            const SizedBox(height: 14),
            ToolField(
              label: '密码',
              child: TextField(
                key: const Key('autorun-password'),
                controller: _password,
                enabled: !model.busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _login(model),
                decoration: const InputDecoration(hintText: '请输入密码'),
              ),
            ),
            const SizedBox(height: 16),
            ..._messages(model),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('autorun-login'),
                onPressed: model.busy ? null : () => _login(model),
                child: Text(model.busy ? '验证中…' : '登录'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _progressMetric(AutoRunProgress progress) {
    final color = progress.unit == 'km'
        ? const Color(0xFF4A9D93)
        : toolAccent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${progress.percent}%',
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: autoRunFormatNumber(progress.current),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text:
                    ' / ${autoRunFormatNumber(progress.target)} ${progress.unit}',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress.percent / 100,
          minHeight: 6,
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  List<Widget> _run(AutoRunViewModel model) => [
    ToolCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToolSectionHeading(
            title: '运动进度',
            subtitle: '本学期概览',
            subtitleAbove: true,
            trailing: model.loadingRun ? '同步中…' : '已同步',
          ),
          const SizedBox(height: 18),
          if (model.loadingRun) const LinearProgressIndicator(),
          if (model.progress.isEmpty && !model.loadingRun)
            const Text('暂时没有进度数据，请刷新重试。'),
          LayoutBuilder(
            builder: (context, constraints) {
              // 小屏或大字体时改为纵排，正常字号保持原版的两列进度。
              final twoColumns =
                  constraints.maxWidth >= 280 &&
                  MediaQuery.textScalerOf(context).scale(12) <= 16;
              return Container(
                decoration: BoxDecoration(
                  color: toolBackground(context),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: twoColumns
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final progress in model.progress)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: _progressMetric(progress),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        children: [
                          for (final progress in model.progress)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: _progressMetric(progress),
                            ),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text(
      '跑步记录',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10),
    ),
    const Text(
      '生成并提交',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 6),
    const Text(
      '自动生成轨迹并提交至校园跑',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12),
    ),
    const SizedBox(height: 18),
    Center(
      child: SizedBox(
        width: 226,
        child: FilledButton(
          key: const Key('autorun-submit-run'),
          onPressed: model.busy ? null : model.runOnce,
          style: FilledButton.styleFrom(
            minimumSize: const Size(226, 226),
            padding: const EdgeInsets.all(26),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface,
              width: 2,
            ),
            shape: const CircleBorder(),
            elevation: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('校园跑执行按钮', style: TextStyle(fontSize: 9)),
              const SizedBox(height: 8),
              Icon(
                Icons.outlined_flag_rounded,
                size: 52,
                color: toolAccent(context),
              ),
              Text(
                model.busy ? '严肃处理中' : '郑重开跑',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '事关本学期运动大局，请认真轻点',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  ];
  List<Widget> _club(AutoRunViewModel model) => [
    const ToolCard(
      radius: 16,
      child: Column(
        children: [
          Text('运动让生活更美好', style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          AutoRunTruck(),
        ],
      ),
    ),
    const SizedBox(height: 12),
    ToolCard(
      radius: 12,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (model.joined / (model.target > 0 ? model.target : 1)).clamp(
              0.0,
              1.0,
            ),
            minHeight: 11,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已参加：${model.joined}次',
                style: const TextStyle(fontSize: 12),
              ),
              Text('目标：${model.target}次', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    _signCard(model),
    const SizedBox(height: 12),
    ToolCard(
      radius: 16,
      padding: EdgeInsets.zero,
      child: SwitchListTile.adaptive(
        key: const Key('autorun-club-schedule'),
        title: const Text(
          '定时签到/签退',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          model.scheduleMessage,
          style: const TextStyle(fontSize: 12),
        ),
        value: model.scheduleEnabled,
        onChanged: model.busy ? null : model.setSchedule,
      ),
    ),
    const SizedBox(height: 12),
    ToolCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToolSectionHeading(title: '俱乐部活动', trailing: '点日期查询'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var offset = 0; offset < 7; offset++)
                  _dayChip(model, DateTime.now().add(Duration(days: offset))),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: model.busy
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(model.queryDate) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) {
                      await model.loadClub(date: autoRunDate(date));
                    }
                  },
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: Text(model.queryDate, style: const TextStyle(fontSize: 12)),
          ),
          if (model.loadingClub) const LinearProgressIndicator(),
          if (model.activities.isEmpty && !model.loadingClub)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('这一天暂无俱乐部活动。'),
            ),
          for (final activity in model.activities) ...[
            const Divider(),
            Text(
              activity.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '活动时间：${activity.startTime}–${activity.endTime}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '活动地点：${activity.address}',
              style: const TextStyle(fontSize: 12),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '体能教研室 · ${activity.joined}/${activity.capacity} 人',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: model.busy || !activity.canJoin
                      ? null
                      : () => model.changeMembership(activity),
                  child: Text(
                    activity.isJoined
                        ? '取消报名'
                        : activity.isFull
                        ? '已满员'
                        : activity.isUnavailable
                        ? '不可报名'
                        : '报名',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed: model.busy ? null : () => model.loadClub(),
      child: const Text('刷新活动'),
    ),
  ];

  Widget _dayChip(AutoRunViewModel model, DateTime date) {
    final full = autoRunDate(date);
    final selected = model.queryDate == full;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: model.busy ? null : () => model.loadClub(date: full),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          backgroundColor: selected
              ? toolAccent(context)
              : toolBackground(context),
          foregroundColor: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            Text(
              '周${'一二三四五六日'[date.weekday - 1]}',
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              '${date.day}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signCard(AutoRunViewModel model) {
    final task = model.signTask;
    return ToolCard(
      radius: 16,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前签到任务', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (task == null)
              const Text('当前没有可执行签到 / 签退任务')
            else ...[
              Text(task.name),
              Text('${task.startTime}–${task.endTime}'),
              Text(task.address),
              Text(task.description),
              if (task.signedIn && !task.signedBack)
                Text(_countdown(model.queryDate, task.endTime)),
              if (task.signType != null)
                FilledButton(
                  key: const Key('autorun-club-sign'),
                  onPressed: model.busy || !task.canSign ? null : model.sign,
                  child: Text(task.signType == '2' ? '签退' : '签到'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _countdown(String date, String endTime) {
    final time = autoRunEventTime(date, endTime);
    if (time == null) return '签退时间待更新';
    final remaining = time
        .subtract(const Duration(minutes: 10))
        .difference(_now);
    if (remaining <= Duration.zero) return '已进入签退试探窗口';
    final hours = remaining.inHours,
        minutes = remaining.inMinutes % 60,
        seconds = remaining.inSeconds % 60;
    return '距签退窗口 ${[if (hours > 0) hours, minutes, seconds].map((v) => v.toString().padLeft(2, '0')).join(':')}';
  }

  Widget _account(AutoRunViewModel model) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
    children: [
      const Text(
        '我的',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 22),
      ..._messages(model),
      const ToolSectionHeading(
        title: '校园跑账号',
        subtitle: '登录凭证仅保存在此设备，不保存密码；退出账号时会自动清除。',
      ),
      const SizedBox(height: 16),
      ToolCard(
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: toolAccent(context),
              size: 36,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '账号已连接',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  Text('可以使用校园跑与俱乐部功能', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        key: const Key('autorun-logout'),
        onPressed: model.busy
            ? null
            : () async {
                await model.logout();
                if (mounted) {
                  _password.clear();
                  setState(() => _tab = 0);
                }
              },
        child: const Text('退出校园跑账号'),
      ),
    ],
  );
}
