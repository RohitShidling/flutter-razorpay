import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/widgets/app_logo.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _otpFocusNode = FocusNode();
  Timer? _resendTimer;
  late AuthProvider _authProvider;
  bool _autoSubmitting = false;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _startResendTimer();
    _otpController.addListener(_onOtpChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_otpFocusNode);
    });
  }

  void _onOtpChanged() {
    if (!mounted) return;
    setState(() {});
    final code = _otpController.text.trim();
    if (code.length == 6 && !_autoSubmitting && _authProvider.state != AuthState.loading) {
      _autoSubmitting = true;
      Future.microtask(() async {
        await _submit();
        _autoSubmitting = false;
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_authProvider.resendCooldownSeconds > 0) {
        _authProvider.tickResendCooldown();
      }
    });
  }

  @override
  void dispose() {
    _otpController.removeListener(_onOtpChanged);
    if (mounted) FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _editNumber() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    context.read<AuthProvider>().clearTransientState();
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    if (provider.state == AuthState.loading) return;

    if (_otpController.text.trim().length < 6) {
      ErrorHandler.showError(context, 'Please enter the complete 6-digit code');
      return;
    }

    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final code = _otpController.text.trim();

    bool success;
    if (provider.authMode == AuthMode.register) {
      success = await provider.registerVerifyOtp(code);
    } else {
      success = await provider.loginVerifyOtp(code);
    }

    if (!mounted) return;

    if (success) {
      // AuthWrapper will reactively rebuild to HomeScreen when it sees
      // AuthState.authenticated. We just need to clear the navigation stack.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ErrorHandler.showError(context, provider.errorMessage);
    }
  }

  Future<void> _resendOtp() async {
    final provider = context.read<AuthProvider>();
    if (provider.resendCooldownSeconds > 0) return;

    final success = await provider.resendOtp();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code has been sent to your WhatsApp.')),
      );
    } else {
      ErrorHandler.showError(context, provider.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final isLoading = provider.state == AuthState.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRegister = provider.authMode == AuthMode.register;
    final remaining = provider.remainingAttempts;
    final canResend = provider.resendCooldownSeconds <= 0 && !isLoading;
    final isComplete = _otpController.text.trim().length == 6;
    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: pageBg, isDark: isDark),
      child: Scaffold(
        backgroundColor: pageBg,
        body: GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _editNumber,
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                        const Expanded(
                          child: Center(child: AppLogo(height: 40)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verify your number',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF102348),
                                ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                          const SizedBox(height: 10),
                          Text(
                            'We sent a 6-digit code to ${provider.phoneNumber} on WhatsApp.',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ).animate().fadeIn(delay: 120.ms),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: isLoading ? null : _editNumber,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppTheme.primaryColor,
                            ),
                            child: const Text(
                              'Edit number',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          if (remaining != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              remaining <= 1
                                  ? 'Last attempt — enter the code carefully.'
                                  : '$remaining attempts remaining before verification is locked.',
                              style: TextStyle(
                                fontSize: 13,
                                color: remaining <= 2
                                    ? Colors.red.shade400
                                    : (isDark ? Colors.white60 : Colors.grey.shade700),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 0,
                            width: 0,
                            child: Opacity(
                              opacity: 0,
                              child: TextFormField(
                                controller: _otpController,
                                focusNode: _otpFocusNode,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: true,
                                onFieldSubmitted: (_) => _submit(),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 6,
                                enableInteractiveSelection: true,
                                showCursor: true,
                                style: const TextStyle(color: Colors.transparent),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  counterText: '',
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context).requestFocus(_otpFocusNode);
                              Future.delayed(const Duration(milliseconds: 120), () {
                                if (!mounted) return;
                                SystemChannels.textInput.invokeMethod('TextInput.show');
                              });
                            },
                            onLongPress: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (!context.mounted || data?.text == null) return;
                              final digits = data!.text!.replaceAll(RegExp(r'\D'), '');
                              final pasted = digits.substring(0, digits.length < 6 ? digits.length : 6);
                              if (pasted.isNotEmpty) {
                                _otpController.text = pasted;
                                FocusScope.of(context).requestFocus(_otpFocusNode);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (index) {
                                final text = _otpController.text;
                                final char = index < text.length ? text[index] : '';
                                final active = text.length == index && text.length < 6;
                                return Container(
                                  width: 48,
                                  height: 68,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.primaryColor,
                                      width: active ? 2.6 : 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    char,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 28),
                          Center(
                            child: TextButton(
                              onPressed: canResend ? _resendOtp : null,
                              child: Text(
                                canResend
                                    ? "Didn't receive the code? Resend"
                                    : 'Resend code in 00:${provider.resendCooldownSeconds.toString().padLeft(2, '0')}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: canResend
                                      ? (isDark ? Colors.white : const Color(0xFF102348))
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (isLoading || !isComplete) ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      isRegister ? 'Verify & Register' : 'Verify',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 320.ms),
                        ],
                      ),
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
    );
  }
}
