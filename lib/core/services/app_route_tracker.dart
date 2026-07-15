/// Tracks which screen the user is on for targeted refresh after reconnect.
enum AppScreen {
  home,
  subscriptionManagement,
  cart,
  children,
  teacherProfile,
  professionalProfile,
  mealSkip,
  weeklyMenu,
  settings,
  other,
}

class AppRouteTracker {
  AppRouteTracker._();

  static final AppRouteTracker instance = AppRouteTracker._();

  AppScreen _current = AppScreen.home;

  AppScreen get current => _current;

  void setCurrent(AppScreen screen) {
    _current = screen;
  }

  void clearIfCurrent(AppScreen screen) {
    if (_current == screen) {
      _current = AppScreen.home;
    }
  }
}
