import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl {
    final env = dotenv.env['ENVIRONMENT'] ?? 'development';
    
    if (env == 'production') {
      return dotenv.env['API_BASE_URL_PRODUCTION'] ?? '';
    }

    String domain;
    if (Platform.isAndroid) {
      domain = dotenv.env['API_BASE_URL_ANDROID'] ?? 'http://10.0.2.2:3000';
    } else {
      domain = dotenv.env['API_BASE_URL_IOS'] ?? 'http://localhost:3000';
    }
    return domain;
  }

  /// Public health check (no auth) — use for reachability only.
  static const String health = '/health';

  /// Whether the Razorpay SDK should run in test mode.
  /// Production-grade behavior: any non-`production` ENVIRONMENT is test mode.
  /// Optional override via RAZORPAY_TEST_MODE=true|false in .env.
  static bool get isTestModePayment {
    final override = dotenv.env['RAZORPAY_TEST_MODE'];
    if (override != null && override.isNotEmpty) {
      return override.toLowerCase() == 'true';
    }
    final env = (dotenv.env['ENVIRONMENT'] ?? 'development').toLowerCase();
    return env != 'production';
  }

  // Auth - Login (existing user)
  static const String loginSendOtp = '/api/client/auth/login/send-otp';
  static const String loginVerifyOtp = '/api/client/auth/login/verify-otp';
  static const String loginCarousel = '/api/client/auth/login-carousel';
  static const String publicReferralSettings = '/api/client/auth/referral-settings';

  // Auth - Register (new user)
  static const String registerSendOtp = '/api/client/auth/register/send-otp';
  static const String registerVerifyOtp = '/api/client/auth/register/verify-otp';

  // Auth - Common
  static const String logout = '/api/client/auth/logout';
  static const String refresh = '/api/client/auth/refresh';
  static const String me = '/api/client/auth/me';
  static const String deleteAccount = '/api/client/auth/delete-account';

  // Legacy (kept for backward compat — remove later)
  static const String sendOtp = '/api/client/auth/send-otp';
  static const String verifyOtp = '/api/client/auth/verify-otp';

  // Children
  static const String children = '/api/client/children';
  static String child(String id) => '/api/client/children/$id';

  // Profiles
  static const String parentProfile = '/api/client/parent/profile';
  static const String professionalProfile = '/api/client/professional/profile';
  static const String teacherProfile = '/api/client/teacher/profile';
  static const String teacherProfiles = '/api/client/teacher/profiles';
  static String teacherProfileWithId(String id) => '/api/client/teacher/profiles/$id';
  static const String professionalProfiles = '/api/client/professional/profiles';
  static String professionalProfileWithId(String id) => '/api/client/professional/profiles/$id';

  // Lookup
  static const String schools = '/api/client/schools';
  static const String mealSizes = '/api/common/lookup/meal-sizes';
  static const String standards = '/api/common/lookup/standards';
  static const String divisions = '/api/common/lookup/divisions';
  static const String contactUsInfo = '/api/common/lookup/contact-us-info';
  static const String deliveryTimeSettings = '/api/common/lookup/delivery-time-settings';
  static const String corporateLocations = '/api/common/corporate-locations';
  /// Client catalog (requires client JWT; server rejects admin tokens on this path).
  static const String subscriptions = '/api/common/subscription-plan-days';
  static const String homepage = '/api/common/homepage';
  static const String announcements = '/api/client/announcements';
  static const String states = '/api/common/lookup/states';
  static const String cities = '/api/common/lookup/cities';
  static const String companies = '/api/common/lookup/companies';
  static const String allowedAddresses = '/api/common/lookup/allowed-addresses';

  // Common Menu
  static const String commonMenuToday = '/api/common/menu/today';
  static const String commonMenuWeekly = '/api/common/menu/weekly/all';
  static String commonMenuByDate(String date) => '/api/common/menu/$date';
  static const String commonMenuHistory = '/api/common/menu/history/all';

  // Cart
  static const String viewCart = '/api/client/cart';
  static const String addToCart = '/api/client/cart/add';
  static String removeCartItem(int itemId) => '/api/client/cart/item/$itemId';
  static const String clearCart = '/api/client/cart/clear';

  // Payment
  static const String initiatePayment = '/api/client/payment/initiate';
  static const String initiateMealSizeUpgrade = '/api/client/payment/meal-size-upgrade/initiate';
  static const String mealSizeUpgradeOptions = '/api/client/payment/meal-size-upgrade/options';
  static const String applyMealSizeDowngrade = '/api/client/payment/meal-size-downgrade/apply';
  static const String cancelPendingMealSizeUpgrade = '/api/client/payment/meal-size-upgrade/cancel-pending';
  static const String mealSizeUpgradePrices = '/api/client/meals/meal-size-upgrade-prices';
  static const String wallet = '/api/client/wallet';
  static const String walletPreview = '/api/client/wallet/preview';
  static const String walletTransactions = '/api/client/wallet/transactions';
  static const String checkoutCart = '/api/client/payment/checkout-cart';
  static const String abandonPayment = '/api/client/payment/abandon';
  static String paymentStatus(String txnId) => '/api/client/payment/status/$txnId';
  static const String paymentHistory = '/api/client/payment/history';
  static const String activeSubscriptions = '/api/client/payment/active-subscriptions';
  static String forceSync(String txnId) => '/api/client/payment/force-sync/$txnId';
  static String get paymentStatusPage => '$baseUrl/api/client/payment/status-page';

  // Client Subscriptions
  static const String subscriptionStatus = '/api/client/subscriptions/status';
  static const String subscriptionAlerts = '/api/client/subscriptions/alerts';
  static const String updateStartDate = '/api/client/subscriptions/update-start-date';

  // Meals
  static const String todayMeal = '/api/client/meals/today';
  static const String weeklyMeal = '/api/client/meals/weekly';
  static const String mealStatus = '/api/client/meals/status';
  static const String skipMeal = '/api/client/meals/skip';
  static const String mealSkips = '/api/client/meals/skips';
  static const String mealSkipPolicy = '/api/client/meals/skip-policy';
  static String cancelSkip(int skipId) => '/api/client/meals/skip/$skipId';
  static String deleteSkip(int skipId) => '/api/client/meals/skip/$skipId/delete';
  static const String clientMenuNutritionToday = '/api/client/menu-nutrition/today';
  static const String clientMenuNutritionWeekly = '/api/client/menu-nutrition/weekly';

  // Bulk orders
  static const String bulkOrderConfig = '/api/common/bulk-orders/config';
  static String bulkOrderMenus(String deliveryDate) =>
      '/api/common/bulk-orders/menus?deliveryDate=$deliveryDate';
  static const String bulkOrderVarietyCategories = '/api/common/bulk-orders/variety-categories';
  static String bulkOrderCategoryMeals(String categoryId) =>
      '/api/common/bulk-orders/variety-categories/$categoryId/meals';
  static const String bulkOrderQuote = '/api/client/bulk-orders/quote';
  static const String bulkOrderInitiatePayment = '/api/client/bulk-orders/initiate-payment';
  static const String bulkOrderInitiateBundlePayment = '/api/client/bulk-orders/initiate-bundle-payment';
  static const String bulkOrderCart = '/api/client/bulk-orders/cart';
  static String bulkOrderById(String id) => '/api/client/bulk-orders/$id';

  // Quick service
  static const String quickServiceDeliveryAddress = '/api/client/quick-service/delivery-address';
  static const String clientDeliveryAddresses = '/api/client/quick-service/delivery-addresses';
  static const String oneDayLunchConfig = '/api/client/quick-service/one-day-lunch/config';
  static const String oneDayLunchQuote = '/api/client/quick-service/one-day-lunch/quote';
  static const String oneDayLunchInitiatePayment = '/api/client/quick-service/one-day-lunch/initiate-payment';
  static const String specialDishCategories = '/api/client/quick-service/special-dishes/categories';
  static String specialDishItems(String categoryId) =>
      '/api/client/quick-service/special-dishes/categories/$categoryId/items';
  static const String specialDishCart = '/api/client/quick-service/special-dishes/cart';
  static const String specialDishConfig = '/api/client/quick-service/special-dishes/config';
  static const String specialDishInitiatePayment = '/api/client/quick-service/special-dishes/initiate-payment';

  // Referral system
  static const String referralRewards = '/api/client/referrals/rewards';
  static const String applyReferralCode = '/api/client/referrals/apply-code';
  static const String allocateReferral = '/api/client/referrals/allocate';
  static const String allocateReferralMultiple = '/api/client/referrals/allocate-multiple';
}
