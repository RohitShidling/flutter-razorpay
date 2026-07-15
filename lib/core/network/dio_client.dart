import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/providers/session_provider.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/storage/secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DioClient {
  late Dio _dio;
  final SecureStorage _secureStorage;
  final SessionProvider? _sessionProvider;
  static bool _sessionRecoveryFailed = false;
  static String? _appVersionCode;

  static Future<String> _getAppVersionCode() async {
    if (_appVersionCode != null) return _appVersionCode!;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersionCode = packageInfo.buildNumber;
    } catch (_) {
      _appVersionCode = '1';
    }
    return _appVersionCode!;
  }

  /// SHA-256 fingerprints of the production API server certificate(s) loaded dynamically from environment.
  static List<String> get _pinnedCertFingerprints {
    final raw = dotenv.env['SSL_PINNED_FINGERPRINTS'];
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static void resetSessionGate() {
    _sessionRecoveryFailed = false;
  }

  DioClient(this._secureStorage, {SessionProvider? sessionProvider})
      : _sessionProvider = sessionProvider {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // SSL Certificate Pinning — enforce only in release builds.
    // In debug/profile mode, proxies (e.g. Charles, Burp) must work unimpeded.
    if (kReleaseMode && _pinnedCertFingerprints.isNotEmpty) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          // Empty trusted roots context forces cert verification failures,
          // ensuring badCertificateCallback runs for all SSL connections.
          final context = SecurityContext(withTrustedRoots: false);
          final client = HttpClient(context: context);
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            // Compute the SHA-256 fingerprint of the presented certificate.
            final serverFingerprint = sha256.convert(cert.der).bytes
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':')
                .toUpperCase();
            return _pinnedCertFingerprints.contains(serverFingerprint);
          };
          return client;
        },
      );
    }

    // Never emit full HTTP logs in release builds to avoid leaking tokens/PII.
    if (!kReleaseMode) {
      _dio.interceptors.add(_RedactingLogInterceptor());
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final versionCode = await _getAppVersionCode();
        options.headers['X-App-Version'] = versionCode;
        final accessToken = await _secureStorage.getAccessToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 426) {
          _sessionProvider?.triggerForceUpdate();
          return handler.next(e);
        }

        if (_isTransientNetworkError(e)) {
          unawaited(NetworkStatusService.instance.refreshNow());
          final retried = await _retryRequest(e.requestOptions);
          if (retried != null) {
            return handler.resolve(retried);
          }
        }

        if (e.response?.statusCode == 401) {
          // Don't try to refresh on the refresh endpoint itself — would loop forever.
          final isRefreshCall = e.requestOptions.path.contains(ApiEndpoints.refresh);
          final isAuthCall = e.requestOptions.path.contains('/auth/');
          if (isRefreshCall || _sessionRecoveryFailed) {
            if (!_sessionRecoveryFailed && !isAuthCall) {
              _sessionRecoveryFailed = true;
              await _expireSession('Refresh token rejected by server.');
            }
            return handler.next(e);
          }

          try {
            // Token might be expired, try to refresh
            final newAccessToken = await _refreshToken();
            if (newAccessToken != null) {
              // Update the original request with the new token
              e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              try {
                // Retry the request
                final response = await _dio.fetch(e.requestOptions);
                return handler.resolve(response);
              } catch (retryError) {
                return handler.next(e);
              }
            } else {
              _sessionRecoveryFailed = true;
              await _secureStorage.clearTokens();
              await _expireSession('Your session has expired. Please log in again.');
            }
          } catch (refreshError) {
            // If the refresh failed due to a network error, do NOT expire the session.
            // Just fail the original request with the refresh/network error.
            if (refreshError is DioException) {
              return handler.next(refreshError);
            }
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<String?>? _refreshFuture;

  bool _isTransientNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.error is SocketException ||
        e.message?.contains('SocketException') == true;
  }

  Future<Response<dynamic>?> _retryRequest(RequestOptions requestOptions) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isNotEmpty && results.every((r) => r == ConnectivityResult.none)) {
        return null;
      }
    } catch (_) {/* fall through */}

    // Do not retry unreachable hosts — avoids doubling wait time on wrong IP / dead servers.
    const maxRetries = 0;
    var attempt = 0;
    while (attempt < maxRetries) {
      attempt += 1;
      await Future.delayed(Duration(milliseconds: 400 * attempt));
      try {
        return await _dio.fetch(requestOptions);
      } catch (e) {
        if (e is DioException && !_isTransientNetworkError(e)) {
          return null;
        }
      }
    }
    return null;
  }

  Future<String?> _refreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }

    _refreshFuture = _performRefresh();
    try {
      final token = await _refreshFuture;
      return token;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return null;

      final versionCode = await _getAppVersionCode();

      // Note: We use a separate Dio instance to avoid infinite loops in interceptors
      final tokenDio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Version': versionCode,
        },
      ));
      final response = await tokenDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final accessToken = response.data['data']['accessToken'];
        final newRefreshToken = response.data['data']['refreshToken'];
        await _secureStorage.saveTokens(accessToken, newRefreshToken);
        _sessionRecoveryFailed = false;
        return accessToken;
      }
    } on DioException catch (dioErr) {
      if (_isTransientNetworkError(dioErr)) {
        rethrow;
      }
      return null;
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Best-effort: clear tokens and notify the session provider once.
  /// All errors are swallowed so the original API error reaches the caller.
  Future<void> _expireSession(String reason) async {
    try {
      await _secureStorage.clearTokens();
    } catch (_) {/* ignore */}
    try {
      _sessionProvider?.expire(reason: reason);
    } catch (_) {/* ignore */}
  }

  Dio get dio => _dio;
}

bool _sensitiveLogKey(String key) {
  final l = key.toLowerCase();
  const fragments = [
    'password',
    'token',
    'authorization',
    'secret',
    'code',
    'otp',
    'phone',
    'credit',
    'card',
    'cvv',
    'pin',
  ];
  for (final f in fragments) {
    if (l.contains(f)) return true;
  }
  return false;
}

dynamic _redactForLogs(dynamic value) {
  if (value is Map) {
    return value.map((k, v) {
      final key = k.toString();
      if (_sensitiveLogKey(key)) {
        return MapEntry(key, '[redacted]');
      }
      return MapEntry(key, _redactForLogs(v));
    });
  }
  if (value is List) {
    return value.map(_redactForLogs).toList();
  }
  return value;
}

String _safeLogEncode(dynamic data) {
  try {
    return jsonEncode(_redactForLogs(data));
  } catch (_) {
    return '[unloggable]';
  }
}

/// Debug-only: logs method/URL and redacted bodies (headers omitted — bearer lives in headers).
class _RedactingLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('--> ${options.method} ${options.uri}');
    final data = options.data;
    if (data != null) {
      debugPrint('body: ${_safeLogEncode(data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('<-- ${response.statusCode} ${response.requestOptions.uri}');
    final data = response.data;
    if (data != null) {
      debugPrint('body: ${_safeLogEncode(data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('*** DioException ${err.requestOptions.uri} ${err.message}');
    final data = err.response?.data;
    if (data != null) {
      debugPrint('body: ${_safeLogEncode(data)}');
    }
    handler.next(err);
  }
}
