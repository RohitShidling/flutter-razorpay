import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Browser-like user agent — required because payment gateway detects and blocks
/// the default Android WebView user agent and shows a blank page.
const String _kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final String txnId;
  final String orderId;

  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.txnId,
    required this.orderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;
  bool _pageLoaded = false;

  // UPI / native app schemes that must open outside the WebView
  static const List<String> _externalSchemes = [
    'phonepe://', 'paytmmp://', 'tez://', 'gpay://', 'upi://',
    'intent://', 'market://', 'bhim://', 'credpay://', 'whatsapp://',
  ];

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final controller = WebViewController();

    // ── Android-specific configuration ──────────────────────────────────────
    if (Platform.isAndroid) {
      final androidController =
          controller.platform as AndroidWebViewController;
      // Allow mixed HTTP/HTTPS content (our backend is HTTP)
      AndroidWebViewController.enableDebugging(false);
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Override the user-agent so payment gateway serves its web payment page
      ..setUserAgent(_kBrowserUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _pageLoaded = true;
              });
            }
            // Detect redirect back to our status-page
            if (_isReturnUrl(url)) {
              if (mounted) Navigator.of(context).pop(true);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame != true) return;
            final failUrl = error.url ?? '';
            // If redirected to our status-page and that page
            // errors (local IP / CORS), still treat payment as complete
            if (_isReturnUrl(failUrl)) {
              if (mounted) Navigator.of(context).pop(true);
              return;
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'Payment page failed to load.\nPlease check your connection and try again.';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            // Allow our backend status-page
            if (_isReturnUrl(url)) return NavigationDecision.navigate;

            // Open UPI / app deep-links in their native apps
            final isExternal =
                _externalSchemes.any((s) => url.startsWith(s));
            if (isExternal) {
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (mounted) setState(() => _controller = controller);
  }

  /// Returns true if payment gateway has redirected back to our backend status page.
  bool _isReturnUrl(String url) {
    return url.contains('/payment/status-page') ||
        url.contains('payment-result');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // MEDIUM-07: WillPopScope is deprecated in Flutter 3.12+ and does not support
    // Android 14+ predictive back gesture. Use PopScope instead.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showCancelDialog();
        if (shouldPop && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Icon(CupertinoIcons.lock_shield_fill,
                  color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Secure Checkout',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('Razorpay Payment Gateway',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight)),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle_fill,
                color: Colors.grey, size: 22),
            onPressed: () async {
              if (await _showCancelDialog()) {
                if (context.mounted) Navigator.of(context).pop(false);
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _isLoading
                ? LinearProgressIndicator(
                    value: _loadingProgress > 0
                        ? _loadingProgress / 100
                        : null,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    color: AppTheme.primaryColor,
                    minHeight: 3,
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_errorMessage != null) return _buildErrorView();
    if (_controller == null) return _buildSplash(isDark);

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        // Show splash overlay only before the first page starts rendering
        if (!_pageLoaded)
          Container(
            color: isDark ? AppTheme.backgroundDark : Colors.white,
            child: _buildSplash(isDark),
          ),
      ],
    );
  }

  Widget _buildSplash(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.creditcard_fill,
              color: AppTheme.primaryColor,
              size: 42,
            ),
          ),
          const SizedBox(height: 28),
          const CupertinoActivityIndicator(radius: 14),
          const SizedBox(height: 20),
          const Text(
            'Connecting to Payment Gateway',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please do not close or press back',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_slash,
                size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                  _loadingProgress = 0;
                  _pageLoaded = false;
                });
                _controller?.loadRequest(Uri.parse(widget.url));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCancelDialog() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
            'Your payment will not be completed if you leave now.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue Paying'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
