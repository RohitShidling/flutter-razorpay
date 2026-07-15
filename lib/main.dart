import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/core/services/connectivity_service.dart';
import 'package:meal_app/core/storage/secure_storage.dart';
import 'package:meal_app/core/storage/local_cache.dart';
import 'package:meal_app/core/services/offline_cache_bootstrap.dart';
import 'package:meal_app/features/auth/data/repositories/auth_repository.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/auth/ui/screens/login_screen.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/home/ui/screens/home_screen.dart';
import 'package:meal_app/features/home/ui/screens/weekly_menu_screen.dart';
import 'package:meal_app/core/network/lookup_repository.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/features/children/data/repositories/children_repository.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/data/repositories/profile_repository.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/profile/ui/screens/settings_screen.dart';
import 'package:meal_app/core/providers/theme_provider.dart';
import 'package:meal_app/core/network/subscription_repository.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/features/home/data/repositories/homepage_repository.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/core/network/cart_repository.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/network/meal_repository.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/session_provider.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/reconnect_refresh_service.dart';
import 'package:meal_app/core/widgets/offline_banner.dart';
import 'package:meal_app/core/widgets/update_required_screen.dart';
import 'package:meal_app/features/bulk_order/data/repositories/bulk_order_repository.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_skip_screen.dart';
import 'package:meal_app/core/navigation/app_routes.dart';
import 'package:meal_app/core/utils/no_transition_route.dart';
import 'package:meal_app/core/network/announcement_repository.dart';
import 'package:meal_app/core/providers/announcement_provider.dart';
import 'package:meal_app/features/announcements/ui/screens/announcements_screen.dart';
import 'package:meal_app/features/quick_service/data/repositories/quick_service_repository.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/core/network/referral_repository.dart';
import 'package:meal_app/features/profile/providers/referral_provider.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load(fileName: ".env");
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.overlayFor(background: AppTheme.pageBackgroundLight, isDark: false),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // All singletons are created once in initState() — never inside build().
  late final SecureStorage _secureStorage;
  late final LocalCache _cache;
  late final SessionProvider _sessionProvider;
  late final ConnectivityService _connectivityService;
  late final DioClient _dioClient;
  late final AuthRepository _authRepository;
  late final LookupRepository _lookupRepository;
  late final ChildrenRepository _childrenRepository;
  late final ProfileRepository _profileRepository;
  late final PaymentRepository _paymentRepository;
  late final HomepageRepository _homepageRepository;
  late final CartRepository _cartRepository;
  late final MealRepository _mealRepository;
  late final BulkOrderRepository _bulkOrderRepository;
  late final AnnouncementRepository _announcementRepository;
  late final QuickServiceRepository _quickServiceRepository;
  late final ReferralRepository _referralRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _secureStorage = SecureStorage();
    _cache = LocalCache();
    // The session provider is a long-lived singleton shared between the
    // network layer (to push expire events) and the UI (to react to them).
    _sessionProvider = SessionProvider();
    _connectivityService = ConnectivityService()..start();
    _dioClient = DioClient(_secureStorage, sessionProvider: _sessionProvider);
    _authRepository = AuthRepository(_dioClient, _secureStorage);
    _lookupRepository = LookupRepository(_dioClient);
    _childrenRepository = ChildrenRepository(_dioClient);
    _profileRepository = ProfileRepository(_dioClient);
    _paymentRepository = PaymentRepository(_dioClient);
    _homepageRepository = HomepageRepository(_dioClient);
    _cartRepository = CartRepository(_dioClient);
    _mealRepository = MealRepository(_dioClient);
    _bulkOrderRepository = BulkOrderRepository(_dioClient);
    _announcementRepository = AnnouncementRepository(_dioClient);
    _quickServiceRepository = QuickServiceRepository(_dioClient);
    _referralRepository = ReferralRepository(_dioClient);

    // Start global online/offline monitor + attach Dio for queue replay.
    NetworkStatusService.instance.attachDioClient(_dioClient);
    NetworkStatusService.instance.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop the health-poll timer when the app is backgrounded to save battery.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      NetworkStatusService.instance.stop();
    } else if (state == AppLifecycleState.resumed) {
      NetworkStatusService.instance.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NetworkStatusService.instance.stop();
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _sessionProvider),
        ChangeNotifierProvider.value(value: _connectivityService),
        ChangeNotifierProvider(create: (_) => AuthProvider(_authRepository)),
        ChangeNotifierProvider(create: (_) => LookupProvider(_lookupRepository)),
        ChangeNotifierProvider(create: (_) => ChildrenProvider(_childrenRepository)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(_profileRepository)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(_secureStorage)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(SubscriptionRepository(_dioClient))),
        ChangeNotifierProvider(create: (_) => MenuProvider(_dioClient, _cache)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(_paymentRepository, _cache)),
        ChangeNotifierProvider(create: (_) => HomepageProvider(_homepageRepository)),
        ChangeNotifierProvider(create: (_) => CartProvider(_cartRepository)),
        ChangeNotifierProvider(create: (_) => MealProvider(_mealRepository, _cache)),
        ChangeNotifierProvider(create: (_) => BulkOrderProvider(_bulkOrderRepository)),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider(_announcementRepository)),
        ChangeNotifierProvider(create: (_) => QuickServiceProvider(_quickServiceRepository)),
        ChangeNotifierProvider(create: (_) => ReferralProvider(_referralRepository)),
      ],
      child: const MainApp(),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final scaffoldBg = isDark ? AppTheme.backgroundDark : AppTheme.pageBackgroundLight;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: scaffoldBg, isDark: isDark),
      child: MaterialApp(
        title: 'Buuttii',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: context.watch<ThemeProvider>().themeMode,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.home:
              return noTransitionRoute(const HomeScreen());
            case AppRoutes.weeklyMenu:
              return noTransitionRoute(const WeeklyMenuScreen());
            case AppRoutes.mealSkip:
              return noTransitionRoute(const MealSkipScreen());
            case AppRoutes.settings:
              return noTransitionRoute(const SettingsScreen());
            case AppRoutes.announcements:
              return noTransitionRoute(const AnnouncementsScreen());
            default:
              return null;
          }
        },
        builder: (context, child) {
          return ReconnectRefreshCoordinator(
            child: OfflineBanner(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        // navigatorKey lets us show messages from the network layer if needed.
        home: const AuthWrapper(),
      ),
    );
  }
}


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _logoutInFlight = false;
  SessionProvider? _sessionProvider;

  @override
  void initState() {
    super.initState();
    // Listen for session-expired events from the network layer.
    _sessionProvider = context.read<SessionProvider>();
    _sessionProvider?.addListener(_handleSessionChange);
  }

  @override
  void dispose() {
    _sessionProvider?.removeListener(_handleSessionChange);
    super.dispose();
  }

  /// When the network layer reports an expired session, force-logout and
  /// surface a clear message. This guarantees the user is always returned
  /// to the login screen with stale tokens cleared.
  Future<void> _handleSessionChange() async {
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    if (!session.isExpired || _logoutInFlight) return;
    _logoutInFlight = true;
    final reason = session.reason ?? 'Session expired. Please log in again.';
    try {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        OfflineCacheBootstrap.clearMemory(context);
      }
    } catch (_) {/* ignore */}
    if (!mounted) {
      _logoutInFlight = false;
      return;
    }
    session.acknowledge();
    _logoutInFlight = false;
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Show a non-blocking notice on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(reason),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  // Track the last resolved (non-loading) auth state so that transient
  // `loading` states during OTP verification don't yank the user back to
  // the login screen.
  AuthState? _lastResolvedState;

  @override
  Widget build(BuildContext context) {
    final isUpdateRequired = context.watch<SessionProvider>().isUpdateRequired;
    if (isUpdateRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
      return const UpdateRequiredScreen();
    }

    final authState = context.watch<AuthProvider>().state;

    // Only update the resolved state for definitive transitions.
    // `loading` is transient and must NOT trigger a screen switch.
    if (authState != AuthState.loading) {
      _lastResolvedState = authState;
    }

    final effectiveState = _lastResolvedState ?? authState;

    if (effectiveState != AuthState.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
    }

    switch (effectiveState) {
      case AuthState.initial:
        // Keep screen blank while native splash is preserved
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const SizedBox.shrink(),
        );
      case AuthState.authenticated:
        return const HomeScreen();
      case AuthState.loading:
      case AuthState.unauthenticated:
      case AuthState.error:
        return const LoginScreen();
    }
  }
}

