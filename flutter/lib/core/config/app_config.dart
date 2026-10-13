/// 构建配置只包含公开地址和功能开关，不能放账号、密码或服务端密钥。
class AppConfig {
  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.fanxiaogao05.dpdns.org',
    ),
    this.startInDemo = const bool.fromEnvironment('DEMO_MODE'),
  });

  final String apiBaseUrl;
  final bool startInDemo;
}
