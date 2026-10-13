import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/plan_completion.dart';

/// 个人功能复用教务登录会话，页面只接收业务数据，不拼接 HTTP 请求。
class ProfileRepository {
  const ProfileRepository(this.api);
  final ApiClient api;

  Future<PlanCompletion> loadPlanCompletion() async {
    final raw = await api.request('/api/v1/jwxt/plan-completion');
    if (raw is! Map<String, dynamic>) {
      throw const ApiException('培养方案数据格式异常。');
    }
    try {
      return PlanCompletion.fromJson(raw);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  Future<void> submitFeedback({
    required String type,
    required String platform,
    required String content,
  }) async {
    await api.request(
      '/api/v1/feedback',
      method: 'POST',
      data: {'type': type, 'platform': platform, 'content': content},
    );
  }
}
