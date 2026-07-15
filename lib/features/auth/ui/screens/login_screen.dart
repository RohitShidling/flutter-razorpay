import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/app_logo.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/auth/ui/screens/otp_screen.dart';
import 'package:meal_app/features/profile/ui/screens/legal_screen.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _referralController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _phoneFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _referralFocusNode = FocusNode();
  bool _consentAccepted = false;
  bool _showReferralField = false;

  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().clearTransientState();
      context.read<LookupProvider>().fetchLoginCarousel();
      context.read<LookupProvider>().fetchReferralSettings();
    });
    _phoneFocusNode.addListener(_onFocusChanged);
    _usernameFocusNode.addListener(_onFocusChanged);
    _referralFocusNode.addListener(_onFocusChanged);
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final lookupProvider = context.read<LookupProvider>();
      final images = lookupProvider.loginCarouselImages;
      final pageCount = images.isNotEmpty ? images.length : 3;

      if (_currentPage < pageCount - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  bool get _isPhoneComplete => _phoneController.text.trim().length == 10;

  bool get _canSubmit {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.state == AuthState.loading) return false;
    if (!_isPhoneComplete) return false;
    if (authProvider.authMode == AuthMode.register) {
      return _usernameController.text.trim().isNotEmpty && _consentAccepted;
    }
    return true;
  }

  void _onFocusChanged() {
    final hasFocus = _phoneFocusNode.hasFocus ||
        _usernameFocusNode.hasFocus ||
        _referralFocusNode.hasFocus;

    // Trigger state change so build() inserts the bottom spacer
    if (mounted) {
      setState(() {});
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final bannerHeight = screenHeight * 0.42;

    // Align card top perfectly 16px below the "Welcome to Buuttii" branding row
    // Logo bottom is at statusBarHeight + 16 (top padding) + 38 (logo height) = statusBarHeight + 54.
    // Target position for card top is statusBarHeight + 54 + 16 (margin) = statusBarHeight + 70.
    // The card starts at bannerHeight - 24.
    // Therefore target offset = (bannerHeight - 24) - (statusBarHeight + 70) = bannerHeight - statusBarHeight - 94.
    final targetScrollOffset = (bannerHeight - statusBarHeight - 94.0).clamp(0.0, double.infinity);

    if (hasFocus) {
      // Scroll immediately after layout pass has rebuilt with the bottom spacer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          targetScrollOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      });
    } else {
      // Use microtask to verify focus didn't move directly to another field
      Future.microtask(() {
        if (!mounted) return;
        final stillHasFocus = _phoneFocusNode.hasFocus ||
            _usernameFocusNode.hasFocus ||
            _referralFocusNode.hasFocus;
        if (!stillHasFocus) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    _referralController.dispose();
    _scrollController.dispose();
    _phoneFocusNode.dispose();
    _usernameFocusNode.dispose();
    _referralFocusNode.dispose();
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _goToOtp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OtpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _submitLogin() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      final provider = Provider.of<AuthProvider>(context, listen: false);
      final completePhoneNumber = '+91${_phoneController.text.trim()}';
      final success = await provider.loginSendOtp(completePhoneNumber);

      if (success && mounted) {
        _goToOtp();
      } else if (mounted) {
        ErrorHandler.showError(context, provider.errorMessage);
      }
    }
  }

  void _submitRegister() async {
    if (!_consentAccepted) {
      ErrorHandler.showError(
        context,
        'You must accept the Terms & Conditions and Privacy Policy to register.',
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      final provider = Provider.of<AuthProvider>(context, listen: false);
      final completePhoneNumber = '+91${_phoneController.text.trim()}';
      final username = _usernameController.text.trim();
      final referralCode = _showReferralField ? _referralController.text.trim() : null;
      final success = await provider.registerSendOtp(
        completePhoneNumber,
        username,
        _consentAccepted,
        referralCode: referralCode,
      );

      if (success && mounted) {
        _goToOtp();
      } else if (mounted) {
        ErrorHandler.showError(context, provider.errorMessage);
      }
    }
  }

  void _setMode(AuthMode mode) {
    context.read<AuthProvider>().setAuthMode(mode);
    setState(() {
      _consentAccepted = false;
      _showReferralField = false;
    });
    _referralController.clear();
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final lookupProvider = context.watch<LookupProvider>();
    final isLoading = authProvider.state == AuthState.loading;
    final isRegisterMode = authProvider.authMode == AuthMode.register;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final carouselImages = lookupProvider.loginCarouselImages;

    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;
    final statusBarBg = isDark ? pageBg : const Color(0xFFFF7A00);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    // Use a stable, beautifully proportioned banner height (e.g. 42% of screen height)
    final bannerHeight = screenHeight * 0.42;

    // Calculate remaining card minHeight to fill the rest of the screen (card overlaps banner by 24px)
    final cardMinHeight = screenHeight - bannerHeight + 24;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: statusBarBg, isDark: isDark),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: pageBg,
        body: Stack(
          children: [
            // Background Layer: Top Carousel Banner
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bannerHeight,
              child: Stack(
                children: [
                  // PageView for dynamic / fallback images
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      _startCarouselTimer();
                    },
                    itemCount: carouselImages.isNotEmpty ? carouselImages.length : 5,
                    itemBuilder: (context, index) {
                      if (carouselImages.isNotEmpty) {
                        final img = carouselImages[index];
                        return Image.network(
                          img.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFF8C00), Color(0xFFFF5E00)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF8C00), Color(0xFFFF5E00)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                            ),
                          ),
                        );
                      }
                      return _buildCarouselPlaceholder(index);
                    },
                  ),
                  if (carouselImages.isNotEmpty)
                    // Soft dark gradient overlay for branding text contrast
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.45),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  // Logo & Brand overlay
                  Positioned(
                    top: statusBarHeight + 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        const AppLogo(height: 38),
                        const SizedBox(width: 8),
                        const Text(
                          'Welcome to Buuttii',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Page dots (positioned higher to prevent card overlap)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        carouselImages.isNotEmpty ? carouselImages.length : 5,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 22 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Foreground Layer: Scrollable white card
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Transparent top spacer (banner height minus the 24px overlap)
                      SizedBox(height: bannerHeight - 24),

                      // Bottom Card – Uses stable ConstrainedBox with stable minHeight
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: cardMinHeight,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: pageBg,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.fromLTRB(
                            20,
                            24,
                            20,
                            20 + kBottomNavigationBarHeight + bottomPadding,
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                            // Heading/Subtitle section inside the card
                            if (isRegisterMode) ...[
                              Text(
                                'Create account',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              isRegisterMode
                                  ? 'Enter your WhatsApp number and username to continue with your healthy meal journey.'
                                  : 'Enter your WhatsApp number to continue with your healthy meal journey.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Form fields
                            if (isRegisterMode) ...[
                              _buildMaterialInput(
                                controller: _usernameController,
                                label: 'Username',
                                icon: Icons.person_outline,
                                focusNode: _usernameFocusNode,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildPhoneInput(),
                            const SizedBox(height: 16),

                            // Referral Section (Register Mode)
                            if (isRegisterMode && lookupProvider.isReferralActive) ...[
                              if (!_showReferralField)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showReferralField = true;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: Icon(Icons.redeem, size: 16, color: isDark ? AppTheme.primaryColor : const Color(0xFFFF7A00)),
                                    label: Text(
                                      'Have a referral code?',
                                      style: TextStyle(
                                        color: isDark ? AppTheme.primaryColor : const Color(0xFFFF7A00),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                _buildMaterialInput(
                                  controller: _referralController,
                                  label: 'Referral Code',
                                  icon: Icons.card_giftcard,
                                  focusNode: _referralFocusNode,
                                  textCapitalization: TextCapitalization.characters,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(15),
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                                  ],
                                  validator: (value) {
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),
                            ],

                            // Terms and Conditions checkbox
                            if (isRegisterMode) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _consentAccepted,
                                    onChanged: (val) {
                                      setState(() {
                                        _consentAccepted = val ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFFFF7A00),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF6B7280),
                                            fontSize: 12.5,
                                            height: 1.45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          children: [
                                            const TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms & Conditions',
                                              style: TextStyle(
                                                color: isDark ? AppTheme.primaryColor : const Color(0xFFFF7A00),
                                                fontWeight: FontWeight.bold,
                                                decoration: TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.push(
                                                    context,
                                                    CupertinoPageRoute(
                                                      builder: (_) =>
                                                          const LegalScreen(initialTabIndex: 0),
                                                    ),
                                                  );
                                                },
                                            ),
                                            const TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(
                                                color: isDark ? AppTheme.primaryColor : const Color(0xFFFF7A00),
                                                fontWeight: FontWeight.bold,
                                                decoration: TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.push(
                                                    context,
                                                    CupertinoPageRoute(
                                                      builder: (_) =>
                                                          const LegalScreen(initialTabIndex: 1),
                                                    ),
                                                  );
                                                },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Submit Action Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _canSubmit
                                    ? (isRegisterMode ? _submitRegister : _submitLogin)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7A00),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                  shadowColor: const Color(0xFFFF7A00).withValues(alpha: 0.35),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isRegisterMode ? 'Create Account' : 'Get OTP',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                            // Spacing before footer
                            const SizedBox(height: 24),

                            // Mode Switch footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isRegisterMode ? 'Already have an account? ' : 'New to Buuttii? ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF6B7280),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _setMode(
                                    isRegisterMode ? AuthMode.login : AuthMode.register,
                                  ),
                                  child: Text(
                                    isRegisterMode ? 'Login' : 'Register',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppTheme.primaryColor : const Color(0xFFFF7A00),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                // Extra bottom spacer when inputs are focused to allow instant, unclamped scrolling
                if (_phoneFocusNode.hasFocus || _usernameFocusNode.hasFocus || _referralFocusNode.hasFocus)
                  const SizedBox(height: 320),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
);
}

  Widget _buildCarouselPlaceholder(int index) {
    final titles = [
      'Premium Nutrition',
      '6-Day Trial Plan',
      'One-Day Lunch Orders',
      'Authentic Indian Tiffins',
      'Zero Hassle Delivery'
    ];

    final subtitles = [
      'Nutritious home-style meals crafted for everyday wellness.',
      'Try fresh daily meals for 6 days before committing.',
      'Order fresh hot lunches whenever you need them.',
      'Authentic Indian tiffins prepared with quality ingredients.',
      'Delivered reliably to your workplace, school, or doorstep.'
    ];

    final icons = [
      Icons.restaurant_menu,
      Icons.verified,
      Icons.calendar_month,
      Icons.restaurant,
      Icons.delivery_dining
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF7A00)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Icon(icons[index], size: 68, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              titles[index],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitles[index],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
        ),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: isDark ? AppTheme.textSecondaryDark : Colors.grey.shade600),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: TextStyle(
            color: isDark ? AppTheme.textSecondaryDark.withValues(alpha: 0.6) : Colors.grey.shade400,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Country Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? AppTheme.borderDark : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
                  ),
                ),
              ],
            ),
          ),
          // Phone Input
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => context.read<AuthProvider>().authMode == AuthMode.register
                  ? _submitRegister()
                  : _submitLogin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your WhatsApp number';
                }
                if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Please enter a valid 10-digit WhatsApp number';
                }
                return null;
              },
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
              ),
              decoration: InputDecoration(
                hintText: 'Phone Number',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                counterText: '',
                hintStyle: TextStyle(
                  color: isDark ? AppTheme.textSecondaryDark.withValues(alpha: 0.6) : Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
