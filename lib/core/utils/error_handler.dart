import 'dart:async' show TimeoutException, Timer;
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Central place for user-visible error text — avoids exposing raw exceptions,
/// Dio dumps, or stack traces in snackbars and forms.
class ErrorHandler {
  static const String _noInternet =
      'No internet connection. Check your network and try again.';
  static const String _serverSlow =
      'The server is taking too long to respond. Please try again.';
  static const String _genericRetry =
      'Something went wrong. Please try again.';
  static const String _serviceUnavailable =
      'Service is temporarily unavailable. Please try again later.';
  static const String _serverUnreachable =
      'Cannot reach the server right now. Please try again in a moment.';

  /// Converts API failures, network errors, and exceptions into short copy for users.
  static String getErrorMessage(dynamic error) {
    if (error == null) return _genericRetry;

    if (error is SocketException) {
      return _noInternet;
    }

    if (error is TimeoutException) {
      return 'Connection timed out. Please check your internet and try again.';
    }

    if (error is DioException) {
      return _messageFromDio(error);
    }

    final raw = error.toString();
    if (_looksLikeNetworkFailure(raw)) {
      return _noInternet;
    }
    if (_looksLikeTechnicalNoise(raw)) {
      return _genericRetry;
    }

    final trimmed = raw.replaceAll('Exception:', '').trim();
    if (trimmed.isEmpty) return _genericRetry;
    // Short user-ish strings (e.g. from repositories) can pass through.
    if (trimmed.length <= 120 && !_looksLikeTechnicalNoise(trimmed)) {
      return trimmed;
    }
    return _genericRetry;
  }

  static String _messageFromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      case DioExceptionType.receiveTimeout:
        return _serverSlow;
      case DioExceptionType.connectionError:
        return _noInternetOrFromUnderlying(error);
      case DioExceptionType.badCertificate:
        return 'Secure connection could not be established. Please try again later.';
      case DioExceptionType.badResponse:
        return _messageFromBadResponse(error);
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        return _unknownDio(error);
    }
  }

  static String _noInternetOrFromUnderlying(DioException error) {
    final u = error.error;
    if (u is SocketException) return _noInternet;
    final s = '${error.message} $u';
    if (_looksLikeNetworkFailure(s)) return _noInternet;
    if (_shouldTreatAsServerUnavailable(error)) return _serverUnreachable;
    return _noInternet;
  }

  static String _unknownDio(DioException error) {
    final u = error.error;
    if (u is SocketException) return _noInternet;
    if (u is DioException) return _messageFromDio(u);
    if (u != null) {
      final inner = getErrorMessage(u);
      if (inner != _genericRetry || u is FormatException) {
        return inner;
      }
    }
    final combined = '${error.message} ${error.error}';
    if (_looksLikeNetworkFailure(combined)) return _noInternet;
    if (_shouldTreatAsServerUnavailable(error)) return _serverUnreachable;
    return _genericRetry;
  }

  static String _messageFromBadResponse(DioException error) {
    final code = error.response?.statusCode ?? 0;
    final data = error.response?.data;

    if (data is Map) {
      if (data.containsKey('errors') &&
          data['errors'] is List &&
          (data['errors'] as List).isNotEmpty) {
        final joined = (data['errors'] as List).map((e) => e.toString()).join(', ');
        if (joined.length <= 200) return joined;
      }
      for (final key in ['message', 'error', 'msg']) {
        if (!data.containsKey(key)) continue;
        final m = data[key];
        if (m != null) {
          final text = m.toString().trim();
          if (text.isNotEmpty && text.length <= 300 && !_looksLikeTechnicalNoise(text)) {
            return text;
          }
        }
      }
    }

    if (code == 401 || code == 403) {
      return 'Session expired or access denied. Please sign in again.';
    }
    if (code == 404) {
      return 'We could not find what you asked for. Please try again.';
    }
    if (code == 429) {
      return 'Too many requests. Please try again later.';
    }
    if (code == 422) {
      return 'Some information could not be accepted. Please check and try again.';
    }
    if (code >= 500) {
      return _serviceUnavailable;
    }
    if (code >= 400) {
      return 'Request could not be completed. Please try again.';
    }
    return _genericRetry;
  }

  static bool _looksLikeNetworkFailure(String raw) {
    final s = raw.toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection aborted') ||
        s.contains('network error') ||
        s.contains('errno = 7') ||
        s.contains('errno = 101') ||
        s.contains('no address associated with hostname') ||
        s.contains('handshakeexception') ||
        s.contains('certificate verify failed');
  }

  static bool _looksLikeTechnicalNoise(String raw) {
    final s = raw.toLowerCase();
    return s.contains('dioexception') ||
        s.contains('dioexception [') ||
        (s.contains('statuscode:') && s.contains('http')) ||
        raw.length > 280 ||
        (s.contains(' at ') && (s.contains('.dart:') || s.contains('package:')));
  }

  static bool _shouldTreatAsServerUnavailable(DioException error) {
    final net = NetworkStatusService.instance;
    if (net.hasDeviceConnectivity && !net.isBackendReachable) {
      return true;
    }

    final raw = '${error.message} ${error.error}'.toLowerCase();
    return raw.contains('connection refused') ||
        raw.contains('errno = 111') ||
        raw.contains('errno = 61') ||
        raw.contains('software caused connection abort') ||
        raw.contains('actively refused') ||
        raw.contains('connection closed before full header was received');
  }

  static OverlayEntry? _activeEntry;

  /// Use when storing a string error on a provider (e.g. cart) for UI display.
  static String userFacing(Object? error) => getErrorMessage(error);

  /// Red snackbar/toast for validation / blocked actions (meal size, etc.).
  static void showValidationError(BuildContext context, String message) {
    _showOverlayToast(
      context,
      message,
      backgroundColor: Colors.red.shade700,
      icon: Icons.error_outline,
    );
  }

  /// Shows an error toast.
  static void showError(BuildContext context, dynamic error) {
    final message = getErrorMessage(error);
    _showOverlayToast(
      context,
      message,
      backgroundColor: AppTheme.accentColor,
      icon: Icons.error_outline,
    );
  }

  /// Shows a success toast.
  static void showSuccess(BuildContext context, String message) {
    _showOverlayToast(
      context,
      message,
      backgroundColor: Colors.green.shade700,
      icon: Icons.check_circle_outline,
    );
  }

  static void _showOverlayToast(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
  }) {
    if (!context.mounted) return;
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      
      if (_activeEntry != null) {
        try {
          _activeEntry!.remove();
        } catch (_) {}
        _activeEntry = null;
      }

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) => _OverlayToast(
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
          onDismiss: () {
            try {
              if (_activeEntry == entry) {
                entry.remove();
                _activeEntry = null;
              }
            } catch (_) {}
          },
        ),
      );

      _activeEntry = entry;
      overlay.insert(entry);
    } catch (_) {
      // Fallback to standard ScaffoldMessenger if Overlay lookup fails
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}


class _OverlayToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onDismiss;

  const _OverlayToast({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _yAnimation = Tween<double>(begin: -80, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _timer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom + 16;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: bottomPadding + _yAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _dismiss,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.close, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
///
