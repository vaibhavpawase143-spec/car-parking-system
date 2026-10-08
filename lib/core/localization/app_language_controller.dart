import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// Inherited notifier that triggers immediate widget subtree rebuilds
/// whenever the global application language changes.
class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return scope?.notifier ?? AppLanguageController.instance;
  }
}

/// Centralized state controller for application UI and default receipt language.
/// Backed by persistent local storage (SharedPreferences) to survive app restarts.
class AppLanguageController extends ChangeNotifier {
  static final AppLanguageController instance = AppLanguageController._internal();

  AppLanguageController._internal();

  static const String _prefKeyLanguage = 'app_language_code';

  AppLanguage _currentLanguage = AppLanguage.english;
  bool _initialized = false;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isMarathi => _currentLanguage == AppLanguage.marathi;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  AppLocaleStrings get strings => AppStrings.get(_currentLanguage);

  /// Convenient static accessor for current localized strings.
  static AppLocaleStrings get currentStrings => instance.strings;

  /// Inherited/context accessor for widgets with automatic dependency tracking.
  static AppLocaleStrings of(BuildContext? context) {
    if (context != null) {
      final scope = context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
      if (scope?.notifier != null) {
        return scope!.notifier!.strings;
      }
    }
    return instance.strings;
  }

  /// Initializes language from SharedPreferences. Defaults to English.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKeyLanguage);
      if (code != null && code.isNotEmpty) {
        _currentLanguage = AppLanguage.fromCode(code);
      }
    } catch (_) {
      // Fallback gracefully on web or initial run
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Sets and persists the selected language.
  /// Fires [notifyListeners] immediately so all active screens rebuild instantaneously.
  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyLanguage, language.code);
    } catch (_) {}
  }

  /// Toggles between English and Marathi.
  Future<void> toggleLanguage() async {
    final next = isMarathi ? AppLanguage.english : AppLanguage.marathi;
    await setLanguage(next);
  }
}

