import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../profile/data/profile_avatar.dart';
import '../../profile/presentation/profile_avatar_button.dart';

import 'session_view_model.dart';
import '../../../ui/components/page_layout.dart';
import '../../../ui/components/page_selection.dart';

/// 个人中心：展示当前账号信息，并提供应用外观和登录状态设置。
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    this.avatar,
    this.updateTile,
    this.desktopWidgetTile,
  });
  final ProfileAvatar? avatar;
  final Widget? updateTile;
  final Widget? desktopWidgetTile;

  @override
  Widget build(BuildContext context) => Theme(
    data: pageTheme(context),
    child: Builder(
      builder: (context) => ColoredBox(
        color: pageBackground(context),
        child: _buildPage(context),
      ),
    ),
  );

  Widget _buildPage(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final settings = context.watch<AppSettings>();
    final student = session.student;
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 148),
            children: [
              _ProfileHeader(
                avatar: avatar,
                name: student?.name ?? '同学',
                subtitle: _academicSummary(student?.campus, student?.major),
                status: session.isDemo
                    ? '体验账号'
                    : session.isOffline
                    ? '离线信息'
                    : '已登录',
              ),
              const SizedBox(height: 26),
              _ProfileCard(
                children: [
                  _InfoRow(
                    icon: Icons.school_outlined,
                    title: '学籍信息',
                    value: _valueOrFallback(student?.campus),
                  ),
                  _InfoRow(
                    icon: Icons.menu_book_outlined,
                    title: '专业',
                    value: _valueOrFallback(student?.major),
                  ),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    title: '学号',
                    value: session.isDemo
                        ? '演示账号 · 虚构数据'
                        : _maskStudentNumber(student?.number),
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionHeading(title: '常用功能'),
              const SizedBox(height: 10),
              _ProfileCard(
                children: [
                  ListTile(
                    key: const Key('profile-plan-completion'),
                    leading: const _SettingIcon(icon: Icons.school_outlined),
                    title: const Text('学业完成情况'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed('plan-completion'),
                  ),
                  const _CardDivider(),
                  ListTile(
                    key: const Key('profile-feedback'),
                    leading: const _SettingIcon(icon: Icons.feedback_outlined),
                    title: const Text('问题反馈'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed('feedback'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionHeading(title: '应用设置'),
              const SizedBox(height: 10),
              _ProfileCard(
                children: [
                  SwitchListTile.adaptive(
                    key: const Key('lightweight-glass'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    secondary: const _SettingIcon(icon: Icons.blur_on_rounded),
                    title: const Text('轻量效果'),
                    subtitle: const Text('用磨砂效果替代液态折射'),
                    value: settings.lightweightGlass,
                    onChanged: settings.setLightweightGlass,
                  ),
                  const _CardDivider(),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final label = Row(
                          children: [
                            const _SettingIcon(
                              icon: Icons.brightness_6_outlined,
                            ),
                            const SizedBox(width: 16),
                            const Text('外观'),
                          ],
                        );
                        final control = PageDropdown<ThemeMode>(
                          key: const Key('theme-mode'),
                          value: settings.themeMode,
                          onChanged: (mode) {
                            if (mode != null) settings.setThemeMode(mode);
                          },
                          values: const {
                            ThemeMode.system: '跟随系统',
                            ThemeMode.light: '浅色',
                            ThemeMode.dark: '深色',
                          },
                        );
                        if (constraints.maxWidth < 300 &&
                            MediaQuery.textScalerOf(context).scale(14) > 18) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              label,
                              const SizedBox(height: 8),
                              control,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: label),
                            control,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (desktopWidgetTile != null) ...[
                _ProfileCard(children: [desktopWidgetTile!]),
                const SizedBox(height: 24),
              ],
              const _SectionHeading(title: '关于'),
              const SizedBox(height: 10),
              _ProfileCard(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    leading: const _SettingIcon(icon: Icons.info_outline),
                    title: const Text('关于成信友友'),
                    subtitle: const Text('Flutter 版 · 0.1.0'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed('about'),
                  ),
                  if (updateTile != null) ...[
                    const _CardDivider(),
                    updateTile!,
                  ],
                ],
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: OutlinedButton.icon(
                  key: const Key('logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: session.isSubmitting ? null : session.logout,
                  icon: session.isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded, size: 19),
                  label: Text(
                    session.isSubmitting
                        ? '正在退出…'
                        : session.isDemo
                        ? '退出体验账号'
                        : '退出登录',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '非官方学生项目',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _academicSummary(String? campus, String? major) {
    final parts = [campus, major]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toList();
    return parts.isEmpty ? '成信友友用户' : parts.join(' · ');
  }

  static String _valueOrFallback(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '暂未提供' : trimmed;
  }

  /// 页面只显示学号前四位，避免在个人中心完整展示账号标识。
  static String _maskStudentNumber(String? number) {
    final value = number?.trim() ?? '';
    if (value.isEmpty) return '暂未提供';
    if (value.length <= 4) return value;
    return '${value.substring(0, 4)}${List.filled(value.length - 4, '*').join()}';
  }
}

/// 页面顶部显示账号身份，状态文字会区分体验账号和离线缓存。
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    this.avatar,
    required this.name,
    required this.subtitle,
    required this.status,
  });
  final ProfileAvatar? avatar;

  final String name;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Column(
      children: [
        if (avatar != null)
          ProfileAvatarButton(avatar: avatar!, size: 96)
        else
          CircleAvatar(
            radius: 48,
            backgroundColor: pageBackground(context),
            child: Icon(Icons.person_rounded, size: 48, color: color),
          ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (status != '已登录') ...[
          const SizedBox(height: 8),
          Text(status, style: TextStyle(fontSize: 12, color: color)),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PageCard(
    padding: EdgeInsets.zero,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          minVerticalPadding: 10,
          contentPadding: const EdgeInsets.symmetric(horizontal: 17),
          leading: _SettingIcon(icon: icon),
          title: Text(title),
          subtitle: Text(value, style: const TextStyle(fontSize: 14)),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
          ),
      ],
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: pageBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 70,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45),
  );
}
