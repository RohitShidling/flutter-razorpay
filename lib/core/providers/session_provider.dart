import 'package:flutter/foundation.dart';

/// Global signal carrier for session expiry events.
///
/// The Dio interceptor calls [expire] when:
///   • An access-token refresh attempt fails, OR
///   • A 401 response cannot be retried (no refresh token, network down).
///
/// The [AuthWrapper] in `main.dart` listens to this provider and force-logs the
/// user out when [isExpired] flips to true, which kicks the UI back to the
/// login screen — exactly how an industrial-grade app handles invalidated
/// sessions.
class SessionProvider with ChangeNotifier {
  bool _isExpired = false;
  String? _reason;
  bool _isUpdateRequired = false;

  bool get isExpired => _isExpired;
  String? get reason => _reason;
  bool get isUpdateRequired => _isUpdateRequired;

  /// Marks the session as expired. Safe to call multiple times — it only
  /// notifies once until [acknowledge] resets the flag.
  void expire({String? reason}) {
    if (_isExpired) return;
    _isExpired = true;
    _reason = reason ?? 'Session expired. Please log in again.';
    notifyListeners();
  }

  /// Marks that a force update is required for this app version.
  void triggerForceUpdate() {
    if (_isUpdateRequired) return;
    _isUpdateRequired = true;
    notifyListeners();
  }

  /// Called by the UI after it has handled the expiry (logout + nav to login).
  void acknowledge() {
    if (!_isExpired) return;
    _isExpired = false;
    _reason = null;
    notifyListeners();
  }
}
