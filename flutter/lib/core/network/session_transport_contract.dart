class SessionTransport {
  const SessionTransport({
    required this.clearCookies,
    required this.hasStoredCookies,
  });

  final Future<void> Function() clearCookies;
  final Future<bool> Function() hasStoredCookies;
}
