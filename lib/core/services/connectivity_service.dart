import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _isOnline = _hasOnline(initial);
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final next = _hasOnline(results);
      if (next == _isOnline) return;
      _isOnline = next;
      notifyListeners();
    });
  }

  bool _hasOnline(List<ConnectivityResult> results) {
    for (final result in results) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
