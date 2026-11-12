import 'dart:async';

import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../profile/data/profile_avatar.dart';
import '../../profile/presentation/profile_avatar_button.dart';

import 'session_view_model.dart';
import '../../../ui/components/page_layout.dart';
import '../../../ui/components/page_selection.dart';
import '../../community/presentation/community_scope.dart';
import '../../campus/presentation/campus_widgets.dart';

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
    final community = CommunityScope.maybeOf(context);
    if (community != null) {
      scheduleMicrotask(() => unawaited(community.loadProfile()));
    }

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 148),
            children: [
              _ProfileHeader(
                avatar: avatar,
                name: community == null
                    ? student?.name ?? '同学'
                    : community.profile?.displayName ?? '校园同学',
                publicAvatar: community == null
                    ? null
                    : InkWell(
                        key: const Key('profile-public-avatar'),
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            context.pushNamed('community-profile-edit'),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            if (community.profile != null)
                              CampusAuthorAvatar(
                                author: community.profile!,
                                radius: 38,
                                linkToProfile: false,
                              )
                            else
                              const CircleAvatar(
                                radius: 38,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 36,
                                ),
                              ),
                            const CircleAvatar(
                              radius: 11,
                              child: Icon(Icons.edit_outlined, size: 13),
                            ),
                          ],
                        ),
                      ),
                subtitle: _academicSummary(student?.campus, student?.major),
                status: session.isDemo
                    ? '体验账号'
                    : session.isOffline
                    ? '离线信息'
                    : '已登录',
              ),
              const SizedBox(height: 12),
              _ProfileCard(
                children: [
                  if (community != null)
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      title: '学校姓名（仅自己可见）',
                      value: _valueOrFallback(student?.name),
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
              const SizedBox(height: 16),
              if (community != null) ...[
                const _SectionHeading(title: '校园社区'),
                const SizedBox(height: 8),
                _ProfileCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ProfileQuickAction(
                              actionKey: const Key('profile-public-info'),
                              icon: Icons.person_outline_rounded,
                              label: '公开资料',
                              onTap: () =>
                                  context.pushNamed('community-profile-edit'),
                            ),
                          ),
                          Expanded(
                            child: _ProfileQuickAction(
                              actionKey: const Key(
                                'profile-community-messages',
                              ),
                              icon: Icons.campaign_outlined,
                              label: '互动消息',
                              badge: community.unreadCount > 0
                                  ? (community.unreadCount > 99
                                        ? '99+'
                                        : '${community.unreadCount}')
                                  : null,
                              onTap: () =>
                                  context.pushNamed('community-notifications'),
                            ),
                          ),
                          Expanded(
                            child: _ProfileQuickAction(
                              actionKey: const Key(
                                'profile-community-favorites',
                              ),
                              icon: Icons.star_outline_rounded,
                              label: '我的收藏',
                              onTap: () =>
                                  context.pushNamed('community-favorites'),
                            ),
                          ),
                          if (community.profile != null)
                            Expanded(
                              child: _ProfileQuickAction(
                                actionKey: const Key('profile-community-home'),
                                icon: Icons.school_outlined,
                                label: '公开主页',
                                onTap: () => context.pushNamed(
                                  'community-profile',
                                  pathParameters: {
                                    'profileId': community.profile!.id,
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const _SectionHeading(title: '常用功能'),
              const SizedBox(height: 8),
              _ProfileCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileQuickAction(
                            actionKey: const Key('profile-plan-completion'),
                            icon: Icons.school_outlined,
                            label: '学业完成情况',
                            onTap: () => context.pushNamed('plan-completion'),
                          ),
                        ),
                        Expanded(
                          child: _ProfileQuickAction(
                            actionKey: const Key('profile-feedback'),
                            icon: Icons.feedback_outlined,
                            label: '问题反馈',
                            onTap: () => context.pushNamed('feedback'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionHeading(title: '应用设置'),
              const SizedBox(height: 8),
              _ProfileCard(
                children: [
                  SwitchListTile.adaptive(
                    key: const Key('lightweight-glass'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    secondary: const _SettingIcon(icon: Icons.blur_on_rounded),
                    title: const Text('轻量效果'),
                    subtitle: const Text('用磨砂效果替代液态折射'),
                    value: settings.lightweightGlass,
                    onChanged: settings.setLightweightGlass,
                  ),
                  const _CardDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final label = Row(
                          children: [
                            const _SettingIcon(
                              icon: Icons.brightness_6_outlined,
                            ),
                            const SizedBox(width: 12),
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
              const SizedBox(height: 16),
              if (desktopWidgetTile != null) ...[
                _ProfileCard(children: [desktopWidgetTile!]),
                const SizedBox(height: 16),
              ],
              const _SectionHeading(title: '关于'),
              const SizedBox(height: 8),
              _ProfileCard(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    leading: const _SettingIcon(icon: Icons.info_outline),
                    title: const Text('关于成信友友'),
                    subtitle: const Text('Flutter 版 · 0.1.5'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed('about'),
                  ),
                  if (updateTile != null) ...[
                    const _CardDivider(),
                    updateTile!,
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  key: const Key('logout'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: session.isSubmitting ? null : session.logout,
                  icon: session.isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded, size: 17),
                  label: Text(
                    session.isSubmitting
                        ? '正在退出…'
                        : session.isDemo
                        ? '退出体验账号'
                        : '退出登录',
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
    this.publicAvatar,
  });
  final ProfileAvatar? avatar;
  final Widget? publicAvatar;

  final String name;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Column(
      children: [
        if (publicAvatar != null)
          publicAvatar!
        else if (avatar != null)
          ProfileAvatarButton(avatar: avatar!, size: 76)
        else
          CircleAvatar(
            radius: 48,
            backgroundColor: pageBackground(context),
            child: Icon(Icons.person_rounded, size: 48, color: color),
          ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (status != '已登录') ...[
          const SizedBox(height: 6),
          Text(status, style: TextStyle(fontSize: 12, color: color)),
        ],
      ],
    );
  }
}

class _ProfileQuickAction extends StatelessWidget {
  const _ProfileQuickAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: actionKey,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _SettingIcon(icon: icon),
                if (badge != null)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 15),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5484D),
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                      child: Text(
                        badge!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
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
    radius: 18,
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
          dense: true,
          visualDensity: VisualDensity.compact,
          minVerticalPadding: 5,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: _SettingIcon(icon: icon),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 58,
            endIndent: 14,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: pageBackground(context),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 18),
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
