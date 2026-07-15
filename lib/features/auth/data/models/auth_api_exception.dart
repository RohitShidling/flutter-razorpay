class AuthApiException implements Exception {
  final String message;
  final int? remainingAttempts;
  final int? maxVerifyAttempts;
  final int? resendAvailableInSeconds;
  final int? expiresInSeconds;
  final String? lockedUntil;
  final int? retryAfterSeconds;

  const AuthApiException(
    this.message, {
    this.remainingAttempts,
    this.maxVerifyAttempts,
    this.resendAvailableInSeconds,
    this.expiresInSeconds,
    this.lockedUntil,
    this.retryAfterSeconds,
  });

  @override
  String toString() => message;
}
