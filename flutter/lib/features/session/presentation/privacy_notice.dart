import 'package:flutter/material.dart';

import '../../../ui/components/page_sheet.dart';

/// 登录与关于页展示同一份信息处理说明。
void showPrivacyNotice(BuildContext context) {
  showPageSheet<void>(
    context,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('数据与隐私', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text(
                '成信友友是非官方学生项目，与学校及教务系统运营方无隶属或授权关系。\n\n学号和密码通过服务端完成教务登录，正式服务使用 HTTPS，密码不会保存在本机。移动端会话保存在系统安全存储中，课表在本机缓存，退出时清理。浏览器预览由浏览器管理 Cookie。\n\n演示模式只使用虚构数据，不会请求真实教务接口。',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
