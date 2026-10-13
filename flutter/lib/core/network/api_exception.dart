enum FailureKind {
  network,
  storage,
  authentication,
  business,
  invalidResponse,
  cancelled,
}

/// 上层只认识业务错误，不依赖 Dio 的异常类型。
class ApiException implements Exception {
  const ApiException(this.message, {this.kind = FailureKind.business});

  final String message;
  final FailureKind kind;

  @override
  String toString() => message;
}
