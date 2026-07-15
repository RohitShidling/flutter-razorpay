class OtpSendResult {
  final bool success;
  final String? phoneNumber;
  final int expiresInSeconds;
  final int resendAvailableInSeconds;
  final int maxVerifyAttempts;

  const OtpSendResult({
    required this.success,
    this.phoneNumber,
    this.expiresInSeconds = 300,
    this.resendAvailableInSeconds = 60,
    this.maxVerifyAttempts = 5,
  });

  factory OtpSendResult.fromJson(Map<String, dynamic>? data) {
    if (data == null) {
      return const OtpSendResult(success: true);
    }
    return OtpSendResult(
      success: true,
      phoneNumber: data['phoneNumber']?.toString(),
      expiresInSeconds: _int(data['expiresInSeconds'], 300),
      resendAvailableInSeconds: _int(data['resendAvailableInSeconds'], 60),
      maxVerifyAttempts: _int(data['maxVerifyAttempts'], 5),
    );
  }

  static int _int(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }
}
