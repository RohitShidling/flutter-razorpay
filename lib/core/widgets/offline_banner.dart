import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';

/// Bottom banner that shows when offline and a "Back online!" toast when reconnecting.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

enum _BannerMode { hidden, offline, backOnline }

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  _BannerMode _mode = _BannerMode.hidden;
  Timer? _autoDismissTimer;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1.12), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    NetworkStatusService.instance.addListener(_onNetworkChange);

    // Show immediately if already offline at build time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!NetworkStatusService.instance.isOnline) {
        _show(_BannerMode.offline);
        setState(() {
          _wasOffline = true;
        });
      }
    });
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeListener(_onNetworkChange);
    _autoDismissTimer?.cancel();
    _reconnectPoll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(_BannerMode mode) {
    if (!context.mounted) return;
    setState(() => _mode = mode);
    _controller.forward();
  }

  void _hide() {
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) setState(() => _mode = _BannerMode.hidden);
    });
  }

  void _onNetworkChange() {
    if (!context.mounted) return;
    final isOffline = !NetworkStatusService.instance.isOnline;

    if (isOffline) {
      _autoDismissTimer?.cancel();
      _wasOffline = true;
      if (_mode != _BannerMode.offline) {
        setState(() {
          _mode = _BannerMode.offline;
        });
      }
      _controller.forward();
      _startReconnectPoll();
    } else {
      _stopReconnectPoll();
      if (_wasOffline) {
        _wasOffline = false;
        _autoDismissTimer?.cancel();
        setState(() {
          _mode = _BannerMode.backOnline;
        });
        _controller.forward();
        _autoDismissTimer = Timer(const Duration(milliseconds: 2500), () {
          _hide();
        });
      } else if (_mode == _BannerMode.offline) {
        _hide();
      }
    }
  }

  Timer? _reconnectPoll;

  void _startReconnectPoll() {
    _reconnectPoll?.cancel();
    _reconnectPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!context.mounted) {
        _reconnectPoll?.cancel();
        return;
      }
      // Re-check: if network came back but listener didn't fire, dismiss manually
      if (NetworkStatusService.instance.isOnline) {
        _onNetworkChange();
      }
    });
  }

  void _stopReconnectPoll() {
    _reconnectPoll?.cancel();
    _reconnectPoll = null;
  }

  void _userDismiss() => _hide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final net = NetworkStatusService.instance;

    if (_mode == _BannerMode.hidden && !_controller.isAnimating) {
      return widget.child;
    }

    final isBackOnline = _mode == _BannerMode.backOnline;

    final bannerColor = isBackOnline
        ? Color.alphaBlend(
            Colors.green.withValues(alpha: isDark ? 0.22 : 0.14),
            theme.colorScheme.surface,
          )
        : Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.1),
            theme.colorScheme.surface,
          );

    final iconColor = isBackOnline ? Colors.green : theme.colorScheme.error;
    final iconBg = isBackOnline
        ? Colors.green.withValues(alpha: isDark ? 0.22 : 0.14)
        : theme.colorScheme.errorContainer.withValues(alpha: isDark ? 0.5 : 0.65);
    final textColor = theme.colorScheme.onSurface;

    final icon = isBackOnline ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.zero,
                child: GestureDetector(
                  onVerticalDragUpdate: (d) {
                    if (d.delta.dy > 10) _userDismiss();
                  },
                  onHorizontalDragUpdate: (d) {
                    if (d.delta.dx.abs() > 12) _userDismiss();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(16),
                      color: bannerColor.withValues(alpha: 0.97),
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isBackOnline
                                    ? 'You are online. Internet connection restored.'
                                    : (net.hasDeviceConnectivity
                                        ? 'Cannot reach the server. We will reconnect automatically.'
                                        : 'No internet connection. Check your Wi‑Fi or mobile data.'),
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.94),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                                maxLines: 3,
                                softWrap: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: _userDismiss,
                              icon: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 20,
                                color: textColor.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
