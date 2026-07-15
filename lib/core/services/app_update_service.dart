import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Client-side native Play Store update check (no backend settings needed).
class AppUpdateService {
  AppUpdateService._();

  static StreamSubscription<InstallStatus>? _installSubscription;

  /// Notifies listeners of the current Play Store install status.
  static final ValueNotifier<InstallStatus?> installStatusNotifier = ValueNotifier<InstallStatus?>(null);

  /// Call once from the home screen after the widget tree is ready.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid) {
      debugPrint('[AppUpdate] Native update checks are only supported on Android.');
      return;
    }

    try {
      debugPrint('[AppUpdate] Querying Play Store for update availability...');
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;
      debugPrint('[AppUpdate] Play Store updateAvailability: ${info.updateAvailability}, installStatus: ${info.installStatus}');

      // If the update has already been downloaded, immediately prompt to restart and install.
      if (info.installStatus == InstallStatus.downloaded) {
        debugPrint('[AppUpdate] Update is already downloaded. Prompting restart.');
        installStatusNotifier.value = InstallStatus.downloaded;
        _showRestartSnackBar(context);
        return;
      }

      // If the update is already downloading or pending, listen to progress.
      if (info.installStatus == InstallStatus.downloading || info.installStatus == InstallStatus.pending) {
        debugPrint('[AppUpdate] Update is already downloading/pending. Restarting listener.');
        installStatusNotifier.value = info.installStatus;
        _startListening(context);
        return;
      }

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final stalenessDays = info.clientVersionStalenessDays;
        debugPrint('[AppUpdate] Update available. Staleness days: $stalenessDays');

        // Check if update is critical/stale (45 days threshold)
        if (stalenessDays != null && stalenessDays >= 45 && info.immediateUpdateAllowed) {
          debugPrint('[AppUpdate] Staleness days >= 45. Triggering immediate update.');
          try {
            await InAppUpdate.performImmediateUpdate();
          } catch (e) {
            debugPrint('[AppUpdate] Stale immediate update failed: $e');
            if (context.mounted) {
              _redirectToPlayStore(context);
            }
          }
        } else if (info.flexibleUpdateAllowed) {
          debugPrint('[AppUpdate] Triggering flexible update.');
          if (!context.mounted) return;
          _startListening(context);
          installStatusNotifier.value = InstallStatus.downloading;
          try {
            final result = await InAppUpdate.startFlexibleUpdate();
            debugPrint('[AppUpdate] Flexible update start result: $result');
            if (result != AppUpdateResult.success) {
              _installSubscription?.cancel();
              _installSubscription = null;
              installStatusNotifier.value = null;
              if (result != AppUpdateResult.userDeniedUpdate && context.mounted) {
                _redirectToPlayStore(context);
              }
            }
          } catch (e) {
            debugPrint('[AppUpdate] flexible update start failed with exception: $e');
            _installSubscription?.cancel();
            _installSubscription = null;
            installStatusNotifier.value = null;
            if (context.mounted) {
              _redirectToPlayStore(context);
            }
          }
        } else if (info.immediateUpdateAllowed) {
          debugPrint('[AppUpdate] Flexible update not allowed, falling back to immediate.');
          try {
            await InAppUpdate.performImmediateUpdate();
          } catch (e) {
            debugPrint('[AppUpdate] Immediate update fallback failed: $e');
            if (context.mounted) {
              _redirectToPlayStore(context);
            }
          }
        } else {
          // If update is available but Google Play API doesn't allow flexible or immediate update:
          debugPrint('[AppUpdate] Update available but in-app updates not allowed. Redirecting to Play Store.');
          if (context.mounted) {
            _redirectToPlayStore(context);
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdate] Native check failed: $e');
      installStatusNotifier.value = null; // Clear to prevent stuck downloading card
      developer.log(
        'In-app update check failed: $e',
        name: 'AppUpdateService',
      );
    }
  }

  /// Check if a downloaded update is pending installation (used on app resume).
  static Future<void> checkPendingDownloadedUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;
      debugPrint('[AppUpdate] Check pending: installStatus = ${info.installStatus}');
      installStatusNotifier.value = info.installStatus;
      if (info.installStatus == InstallStatus.downloaded) {
        _showRestartSnackBar(context);
      } else if (info.installStatus == InstallStatus.downloading || info.installStatus == InstallStatus.pending) {
        _startListening(context);
      }
    } catch (e) {
      debugPrint('[AppUpdate] Failed checking pending update: $e');
      installStatusNotifier.value = null; // Clear on check failure
    }
  }

  static void _startListening(BuildContext context) {
    _installSubscription?.cancel();
    _installSubscription = InAppUpdate.installUpdateListener.listen((status) {
      debugPrint('[AppUpdate] Download install status updated: $status');
      installStatusNotifier.value = status;
      if (status == InstallStatus.downloaded) {
        if (context.mounted) {
          _showRestartSnackBar(context);
        }
        _installSubscription?.cancel();
        _installSubscription = null;
      }
    });
  }

  static void _showRestartSnackBar(BuildContext context) {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.removeCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.system_update_alt, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'An update has been downloaded. Restart the app to apply.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(days: 365), // Keep open until acted upon
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'RESTART',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('[AppUpdate] Failed to complete flexible update: $e');
            }
          },
        ),
      ),
    );
  }

  static Future<void> _redirectToPlayStore(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      
      final marketUri = Uri.parse('market://details?id=$packageName');
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

      if (Platform.isAndroid && await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppUpdate] Failed to redirect to Play Store: $e');
    }
  }

  static void dispose() {
    _installSubscription?.cancel();
    _installSubscription = null;
  }
}
