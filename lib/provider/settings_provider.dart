import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme_mode';
const _currencyKey = 'currency';
const _languageKey = 'language';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ThemeModeNotifier(prefs);
});

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return CurrencyNotifier(prefs);
});

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return LanguageNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences prefs;

  ThemeModeNotifier(this.prefs) : super(_getInitialTheme(prefs));

  static ThemeMode _getInitialTheme(SharedPreferences prefs) {
    final stored = prefs.getString(_themeKey);
    if (stored == 'light') return ThemeMode.light;
    if (stored == 'dark') return ThemeMode.dark;
    return ThemeMode.dark; // ✅ DEFAULT: dark instead of system
  }

  void toggle(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    prefs.setString(_themeKey, isDark ? 'dark' : 'light');
  }
}

class CurrencyNotifier extends StateNotifier<String> {
  final SharedPreferences prefs;

  CurrencyNotifier(this.prefs) : super(prefs.getString(_currencyKey) ?? 'USD');

  void set(String value) {
    state = value;
    prefs.setString(_currencyKey, value);
  }
}

class LanguageNotifier extends StateNotifier<String> {
  final SharedPreferences prefs;

  LanguageNotifier(this.prefs)
    : super(prefs.getString(_languageKey) ?? 'English');

  void set(String value) {
    state = value;
    prefs.setString(_languageKey, value);
  }
}
