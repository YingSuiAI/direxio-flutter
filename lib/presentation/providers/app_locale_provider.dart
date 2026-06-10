import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLocaleMode {
  system,
  zh,
  en,
  ja;

  Locale? get locale {
    return switch (this) {
      AppLocaleMode.system => null,
      AppLocaleMode.zh => const Locale('zh'),
      AppLocaleMode.en => const Locale('en'),
      AppLocaleMode.ja => const Locale('ja'),
    };
  }

  static AppLocaleMode fromStorageValue(String? value) {
    return switch (value) {
      'zh' => AppLocaleMode.zh,
      'en' => AppLocaleMode.en,
      'ja' => AppLocaleMode.ja,
      _ => AppLocaleMode.system,
    };
  }

  String get storageValue {
    return switch (this) {
      AppLocaleMode.system => 'system',
      AppLocaleMode.zh => 'zh',
      AppLocaleMode.en => 'en',
      AppLocaleMode.ja => 'ja',
    };
  }
}

class AppLocaleNotifier extends StateNotifier<AppLocaleMode> {
  AppLocaleNotifier() : super(AppLocaleMode.system) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'app_locale_mode';

  Future<void> _load() async {
    final value = await _storage.read(key: _storageKey);
    state = AppLocaleMode.fromStorageValue(value);
  }

  Future<void> setMode(AppLocaleMode mode) async {
    state = mode;
    await _storage.write(key: _storageKey, value: mode.storageValue);
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, AppLocaleMode>((ref) {
  return AppLocaleNotifier();
});
