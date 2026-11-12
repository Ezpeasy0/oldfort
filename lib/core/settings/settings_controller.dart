import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider in main.dart'),
);

class AppSettings {
  const AppSettings({required this.themeMode, required this.textScale});

  final ThemeMode themeMode;
  final double textScale; 

  AppSettings copyWith({ThemeMode? themeMode, double? textScale}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _textScaleKey = 'text_scale';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.light.index;
    return AppSettings(
      themeMode: ThemeMode.values[themeIndex],
      textScale: prefs.getDouble(_textScaleKey) ?? 1.0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setInt(_themeKey, mode.index);
  }

  Future<void> setTextScale(double scale) async {
    state = state.copyWith(textScale: scale);
    await ref.read(sharedPreferencesProvider).setDouble(_textScaleKey, scale);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);