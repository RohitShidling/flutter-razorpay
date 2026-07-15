import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/secure_storage.dart';
import 'package:meal_app/features/auth/data/models/auth_api_exception.dart';
import 'package:meal_app/features/auth/data/models/otp_send_result.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorage _secureStorage;

  static const int _maxUsernameFromJwtChars = 128;

  AuthRepository(this._dioClient, this._secureStorage);

  // ─── LOGIN FLOW (existing user) ────────────────────────────────────────────

  Future<OtpSendResult> loginSendOtp(String phoneNumber) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.loginSendOtp,
        data: {'phoneNumber': phoneNumber},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return OtpSendResult.fromJson(data is Map<String, dynamic> ? data : null);
      }
      throw const AuthApiException('Failed to send OTP');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> loginVerifyOtp(String phoneNumber, String code) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.loginVerifyOtp,
        data: {
          'phoneNumber': phoneNumber,
          'code': code,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        final data = response.data['data'];
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userName = data['user']?['username']?.toString();
        
        await _secureStorage.saveTokens(accessToken, refreshToken);
        await _secureStorage.savePhoneNumber(phoneNumber);
        DioClient.resetSessionGate();
        if (userName != null && userName.trim().isNotEmpty) {
          await _secureStorage.saveUsername(userName.trim());
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── REGISTER FLOW (new user) ──────────────────────────────────────────────

  Future<OtpSendResult> registerSendOtp(String phoneNumber, String username, bool consentAccepted, {String? referralCode}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.registerSendOtp,
        data: {
          'phoneNumber': phoneNumber,
          'username': username,
          'consentAccepted': consentAccepted,
          if (referralCode != null && referralCode.trim().isNotEmpty)
            'referralCode': referralCode.trim(),
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return OtpSendResult.fromJson(data is Map<String, dynamic> ? data : null);
      }
      throw const AuthApiException('Failed to send OTP');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> registerVerifyOtp(String phoneNumber, String username, String code, bool consentAccepted, {String? referralCode}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.registerVerifyOtp,
        data: {
          'phoneNumber': phoneNumber,
          'username': username,
          'code': code,
          'consentAccepted': consentAccepted,
          if (referralCode != null && referralCode.trim().isNotEmpty)
            'referralCode': referralCode.trim(),
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        final data = response.data['data'];
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userName = data['user']?['username']?.toString() ?? username;
        
        await _secureStorage.saveTokens(accessToken, refreshToken);
        await _secureStorage.savePhoneNumber(phoneNumber);
        DioClient.resetSessionGate();
        if (userName.trim().isNotEmpty) {
          await _secureStorage.saveUsername(userName.trim());
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── COMMON ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiEndpoints.logout);
    } catch (e) {
      // Even if API fails, clear local tokens
    } finally {
      await _secureStorage.clearTokens();
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _dioClient.dio.delete(ApiEndpoints.deleteAccount);
    } on DioException catch (e) {
      throw _handleError(e);
    } finally {
      await _secureStorage.clearTokens();
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.getAccessToken();
    return token != null;
  }

  Future<String?> getPhoneNumber() async {
    return await _secureStorage.getPhoneNumber();
  }

  Future<String?> getUsername() async {
    final cached = await _secureStorage.getUsername();
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }
    final token = await _secureStorage.getAccessToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final raw = decoded['username'];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.length > _maxUsernameFromJwtChars) {
        return trimmed.substring(0, _maxUsernameFromJwtChars);
      }
      return trimmed;
    } catch (e) {
      return null;
    }
  }

  Future<String?> fetchCurrentUsername() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.me);
      final userName = response.data['data']?['user']?['username']?.toString();
      if (userName != null && userName.trim().isNotEmpty) {
        await _secureStorage.saveUsername(userName.trim());
        return userName.trim();
      }
      return await getUsername();
    } on DioException {
      // Offline/network fallback to cached username.
      return await getUsername();
    }
  }

  Future<Map<String, dynamic>?> fetchMeProfile() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.me);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  AuthApiException _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;
      if (data != null && data is Map) {
        final meta = data['data'];
        Map<String, dynamic>? metaMap;
        if (meta is Map) {
          metaMap = Map<String, dynamic>.from(meta);
        }

        String message = 'Request failed';
        if (data['message'] != null) {
          message = data['message'].toString();
        } else if (data['errors'] != null && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          message = (data['errors'] as List).join(', ');
        }

        return AuthApiException(
          message,
          remainingAttempts: _optionalInt(metaMap?['remainingAttempts']),
          maxVerifyAttempts: _optionalInt(metaMap?['maxVerifyAttempts']),
          resendAvailableInSeconds: _optionalInt(metaMap?['resendAvailableInSeconds']),
          expiresInSeconds: _optionalInt(metaMap?['expiresInSeconds']),
          lockedUntil: metaMap?['lockedUntil']?.toString(),
          retryAfterSeconds: _optionalInt(metaMap?['retryAfterSeconds']),
        );
      }
      return AuthApiException('Server error: ${error.response?.statusCode}');
    }
    return const AuthApiException('Network error: Please check your connection.');
  }

  int? _optionalInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
