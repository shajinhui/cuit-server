import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openCommunityGroup(BuildContext context) async {
  // 使用项目原有交流群分享链接，不自动发送任何消息。
  final uri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=6mEX8oKBSC9YGOQKHzHb%2BvnOSCYI8NpxFuw4RO6PMZm6wrA0kpNnniOr%2FchH0ShC&busi_data=eyJncm91cENvZGUiOiIxNTEyNDcyMjciLCJ0b2tlbiI6Ik1YWkVmOFhJb1RndC9BU0k0cVRzZnVTdGMxSk1ldldTYWxtNGFsWEdVbThUckVvMGJrU3h2NWM2QVUxNWtmcUciLCJ1aW4iOiIyNjA2MDIzNzU4In0%3D&data=UoVHpFfpjgyvkN0nlex1ZgHosvWTxrE8Fm0RoP6JDzjkqbx1-5KRYX3Nw_NYikzGKfUkOBb_X30OG97BEekBnw&svctype=4&tempid=h5_group_info',
  );
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* 显示可手动搜索的群号。 */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请在 QQ 搜索群号 151247227')));
  }
}
