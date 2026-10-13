import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/components/page_layout.dart';
import '../../session/presentation/privacy_notice.dart';
import 'community_link.dart';

/// 关于页沿用原项目图标、介绍和分组链接。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _openRepository(BuildContext context) async {
    try {
      if (await launchUrl(
        Uri.parse('https://github.com/shajinhui/cuit-server'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // 外部浏览器不可用时保留可手动访问的项目地址。
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('项目地址：github.com/shajinhui/cuit-server')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '关于我们',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 26, 0, 30),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Image.asset(
                  'assets/brand/app-icon.png',
                  width: 92,
                  height: 92,
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                '成信友友',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                '校园教务与生活助手',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PageCard(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '应用介绍',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              Text(
                '成信友友是一款面向成都信息工程大学学生的校园助手，提供课表、成绩、考试、空教室和校园生活等常用服务。',
                style: TextStyle(fontSize: 15, height: 1.65),
              ),
              SizedBox(height: 12),
              Text(
                '本应用为非官方学生项目，与学校及教务系统运营方无隶属或授权关系。',
                style: TextStyle(fontSize: 13, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PageGroupedList(
          children: [
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('加入交流互助群'),
              subtitle: const Text('QQ群 151247227'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => openCommunityGroup(context),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('数据与隐私'),
              subtitle: const Text('了解信息处理与本机存储'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showPrivacyNotice(context),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('GitHub'),
              subtitle: const Text('查看源代码与项目说明'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openRepository(context),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('开源许可'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: '成信友友',
                applicationVersion: '0.1.0+2',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Flutter 版 · 0.1.0+2',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
