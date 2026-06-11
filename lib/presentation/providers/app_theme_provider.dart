import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get materialThemeMode {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  static AppThemeMode fromStorageValue(String? value) {
    return switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }
}

class AppThemeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeNotifier() : super(AppThemeMode.system) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'theme_mode';

  Future<void> _load() async {
    final value = await _storage.read(key: _storageKey);
    state = AppThemeMode.fromStorageValue(value);
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await _storage.write(key: _storageKey, value: mode.name);
  }
}

final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeMode>((ref) {
  return AppThemeNotifier();
});
