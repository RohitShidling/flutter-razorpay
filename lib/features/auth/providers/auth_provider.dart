import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/auth/data/models/auth_api_exception.dart';
import 'package:meal_app/features/auth/data/models/otp_send_result.dart';
import 'package:meal_app/features/auth/data/repositories/auth_repository.dart';
import 'package:meal_app/core/services/offline_cache_bootstrap.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }
enum AuthMode { login, register }

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;

  /// Hard cap so a bad base URL / hung socket cannot leave OTP buttons spinning forever.
  static const Duration _authApiTimeout = Duration(seconds: 18);

  AuthState _state = AuthState.initial;
  AuthMode _authMode = AuthMode.login;
  String _errorMessage = '';
  String _phoneNumber = '';
  String _username = '';
  bool _isProfileLoading = false;
  bool _pendingDashboardRefresh = false;
  bool _consentAccepted = false;
  int _maxVerifyAttempts = 5;
  int? _remainingAttempts;
  int _resendCooldownSeconds = 0;
  int _otpExpiresInSeconds = 300;
  
  String _referralCode = '';
  String? _referredById;
  bool _isReferEarnActive = false;
  int _mealsReward = 2;
  int _pendingRewardsCount = 0;
  List<dynamic> _pendingRewardsList = [];
  String _signupReferralCode = '';
  DateTime? _lastProfileFetchedAt;

  bool _isProfileFresh() =>
      _lastProfileFetchedAt != null &&
      DateTime.now().difference(_lastProfileFetchedAt!).inMinutes < 5;

  AuthProvider(this._authRepository) {
    _checkAuthStatus();
  }

  AuthState get state => _state;
  AuthMode get authMode => _authMode;
  String get errorMessage => _errorMessage;
  String get phoneNumber => _phoneNumber;
  String get username => _username;
  bool get isProfileLoading => _isProfileLoading;
  bool get consentAccepted => _consentAccepted;
  int get maxVerifyAttempts => _maxVerifyAttempts;
  int? get remainingAttempts => _remainingAttempts;
  int get resendCooldownSeconds => _resendCooldownSeconds;
  int get otpExpiresInSeconds => _otpExpiresInSeconds;
  
  String get referralCode => _referralCode;
  String? get referredById => _referredById;
  bool get isReferEarnActive => _isReferEarnActive;
  int get mealsReward => _mealsReward;
  int get pendingRewardsCount => _pendingRewardsCount;
  List<dynamic> get pendingRewardsList => _pendingRewardsList;

  void clearTransientState() {
    _errorMessage = '';
    if (_state != AuthState.authenticated) {
      _state = AuthState.unauthenticated;
    }
    _signupReferralCode = '';
    notifyListeners();
  }

  void setConsentAccepted(bool val) {
    _consentAccepted = val;
    notifyListeners();
  }

  void setAuthMode(AuthMode mode) {
    _authMode = mode;
    _errorMessage = '';
    _consentAccepted = false;
    _signupReferralCode = '';
    if (_state != AuthState.authenticated) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _checkAuthStatus() async {
    // Stay on [initial] until we know the session — so the splash can paint.
    // [loading] is reserved for user-triggered actions (OTP, etc.).
    // Timeout after 3 seconds to avoid a permanently stuck splash on iOS if
    // the Keychain is slow to respond (e.g. right after device reboot).
    bool isAuthenticated = false;
    try {
      isAuthenticated = await _authRepository
          .isAuthenticated()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Timeout or Keychain error — treat as unauthenticated and show login.
      isAuthenticated = false;
    }
    if (isAuthenticated) {
      _phoneNumber = await _authRepository.getPhoneNumber() ?? '';
      _username = await _authRepository.getUsername() ?? '';
      _state = AuthState.authenticated;
      notifyListeners();
      // Offline-first: never block cold start on /auth/me — paint home from
      // cache immediately, then revalidate quietly when reachable.
      unawaited(refreshMeProfile(silent: true));
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// After OTP login/register, home should force-refresh dashboard APIs once.
  void markPendingDashboardRefresh() {
    _pendingDashboardRefresh = true;
  }

  bool consumePendingDashboardRefresh() {
    if (!_pendingDashboardRefresh) return false;
    _pendingDashboardRefresh = false;
    return true;
  }

  Future<T> _withAuthTimeout<T>(Future<T> future) {
    return future.timeout(
      _authApiTimeout,
      onTimeout: () => throw TimeoutException('Request timed out', _authApiTimeout),
    );
  }

  // ─── LOGIN FLOW ────────────────────────────────────────────────────────────

  void _applyOtpSendMeta({required int maxVerifyAttempts, required int expiresInSeconds, required int resendCooldown}) {
    _maxVerifyAttempts = maxVerifyAttempts;
    _remainingAttempts = maxVerifyAttempts;
    _otpExpiresInSeconds = expiresInSeconds;
    _resendCooldownSeconds = resendCooldown;
  }

  void _applyOtpErrorMeta(dynamic e) {
    if (e is! AuthApiException) return;
    if (e.remainingAttempts != null) _remainingAttempts = e.remainingAttempts;
    if (e.maxVerifyAttempts != null) _maxVerifyAttempts = e.maxVerifyAttempts!;
    if (e.resendAvailableInSeconds != null) {
      _resendCooldownSeconds = e.resendAvailableInSeconds!;
    }
  }

  Future<bool> loginSendOtp(String phone) async {
    _state = AuthState.loading;
    _errorMessage = '';
    _phoneNumber = phone;
    notifyListeners();

    try {
      final result = await _withAuthTimeout(_authRepository.loginSendOtp(phone));
      _applyOtpSendMeta(
        maxVerifyAttempts: result.maxVerifyAttempts,
        expiresInSeconds: result.expiresInSeconds,
        resendCooldown: result.resendAvailableInSeconds,
      );
      if (result.phoneNumber != null && result.phoneNumber!.trim().isNotEmpty) {
        _phoneNumber = result.phoneNumber!.trim();
      }
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _applyOtpErrorMeta(e);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendOtp() async {
    if (_phoneNumber.isEmpty) return false;
    if (_resendCooldownSeconds > 0) return false;

    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final OtpSendResult result;
      if (_authMode == AuthMode.register) {
        result = await _withAuthTimeout(
          _authRepository.registerSendOtp(_phoneNumber, _username, _consentAccepted, referralCode: _signupReferralCode),
        );
      } else {
        result = await _withAuthTimeout(_authRepository.loginSendOtp(_phoneNumber));
      }
      _applyOtpSendMeta(
        maxVerifyAttempts: result.maxVerifyAttempts,
        expiresInSeconds: result.expiresInSeconds,
        resendCooldown: result.resendAvailableInSeconds,
      );
      if (result.phoneNumber != null && result.phoneNumber!.trim().isNotEmpty) {
        _phoneNumber = result.phoneNumber!.trim();
      }
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _applyOtpErrorMeta(e);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  void tickResendCooldown() {
    if (_resendCooldownSeconds <= 0) return;
    _resendCooldownSeconds -= 1;
    notifyListeners();
  }

  Future<bool> loginVerifyOtp(String code) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _withAuthTimeout(_authRepository.loginVerifyOtp(_phoneNumber, code));
      if (success) {
        markPendingDashboardRefresh();
        try {
          await refreshMeProfile(silent: true, forceNetwork: true)
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          // Still log in — username can come from token / storage if /me is unreachable.
        }
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid OTP';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _applyOtpErrorMeta(e);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  // ─── REGISTER FLOW ────────────────────────────────────────────────────────

  Future<bool> registerSendOtp(String phone, String username, bool consentAccepted, {String? referralCode}) async {
    _state = AuthState.loading;
    _errorMessage = '';
    _phoneNumber = phone;
    _username = username;
    _consentAccepted = consentAccepted;
    _signupReferralCode = referralCode ?? '';
    notifyListeners();

    try {
      final result = await _withAuthTimeout(
        _authRepository.registerSendOtp(phone, username, consentAccepted, referralCode: referralCode),
      );
      _applyOtpSendMeta(
        maxVerifyAttempts: result.maxVerifyAttempts,
        expiresInSeconds: result.expiresInSeconds,
        resendCooldown: result.resendAvailableInSeconds,
      );
      if (result.phoneNumber != null && result.phoneNumber!.trim().isNotEmpty) {
        _phoneNumber = result.phoneNumber!.trim();
      }
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _applyOtpErrorMeta(e);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerVerifyOtp(String code) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final success =
          await _withAuthTimeout(_authRepository.registerVerifyOtp(_phoneNumber, _username, code, _consentAccepted, referralCode: _signupReferralCode));
      if (success) {
        _consentAccepted = false;
        markPendingDashboardRefresh();
        try {
          await refreshMeProfile(silent: true, forceNetwork: true)
              .timeout(const Duration(seconds: 15));
        } catch (_) {}
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid OTP or registration failed';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _applyOtpErrorMeta(e);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  // ─── LOGOUT ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _authRepository.logout().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Still clear local session even if server is unreachable.
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('read_announcement_ids');
    } catch (_) {}
    
    OfflineCacheBootstrap.resetSession();
    await CacheStore.clearAll();
    _state = AuthState.unauthenticated;
    _phoneNumber = '';
    _username = '';
    _referralCode = '';
    _referredById = null;
    _isReferEarnActive = false;
    _mealsReward = 2;
    _pendingRewardsCount = 0;
    _pendingRewardsList = [];
    _authMode = AuthMode.login;
    _lastProfileFetchedAt = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _authRepository.deleteAccount().timeout(const Duration(seconds: 10));
    } catch (e) {
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _state = AuthState.error;
      notifyListeners();
      rethrow;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('read_announcement_ids');
    } catch (_) {}

    OfflineCacheBootstrap.resetSession();
    await CacheStore.clearAll();
    _state = AuthState.unauthenticated;
    _phoneNumber = '';
    _username = '';
    _referralCode = '';
    _referredById = null;
    _isReferEarnActive = false;
    _mealsReward = 2;
    _pendingRewardsCount = 0;
    _pendingRewardsList = [];
    _authMode = AuthMode.login;
    _lastProfileFetchedAt = null;
    notifyListeners();
  }

  Future<void> refreshMeProfile({bool silent = false, bool forceNetwork = false}) async {
    if (!forceNetwork && _isProfileFresh()) return;

    if (!silent) {
      _isProfileLoading = true;
      notifyListeners();
    }
    try {
      if (!forceNetwork && !NetworkStatusService.instance.isOnline) {
        final cached = await _authRepository.getUsername();
        if (cached != null && cached.trim().isNotEmpty) {
          _username = cached.trim();
        }
        return;
      }
      final data = await _authRepository.fetchMeProfile();
      if (data != null && data['user'] != null) {
        final user = data['user'] as Map<String, dynamic>;
        _username = user['username']?.toString().trim() ?? '';
        _referralCode = user['referralCode']?.toString() ?? '';
        _referredById = user['referredById']?.toString();
        _isReferEarnActive = user['isReferEarnActive'] == true;
        _mealsReward = user['mealsReward'] as int? ?? 2;
        _pendingRewardsCount = user['pendingRewardsCount'] as int? ?? 0;
        _pendingRewardsList = user['pendingRewardsList'] as List<dynamic>? ?? [];
      } else {
        final liveUsername = await _authRepository
            .fetchCurrentUsername()
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
        if (liveUsername != null && liveUsername.trim().isNotEmpty) {
          _username = liveUsername.trim();
        }
      }
      _lastProfileFetchedAt = DateTime.now();
    } catch (_) {
      final cached = await _authRepository.getUsername();
      if (cached != null && cached.trim().isNotEmpty) {
        _username = cached.trim();
      }
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }
}
