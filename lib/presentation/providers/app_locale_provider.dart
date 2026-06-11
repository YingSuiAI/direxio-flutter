import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLocaleMode {
  system,
  zh,
  en,
  ja;

  Locale get explicitLocale {
    return switch (this) {
      AppLocaleMode.system => AppLocaleMode.resolveSystemLocale(),
      AppLocaleMode.zh => const Locale('zh'),
      AppLocaleMode.en => const Locale('en'),
      AppLocaleMode.ja => const Locale('ja'),
    };
  }

  int get mobileIndex {
    return switch (this) {
      AppLocaleMode.system => 0,
      AppLocaleMode.zh => 1,
      AppLocaleMode.en => 2,
      AppLocaleMode.ja => 4,
    };
  }

  static AppLocaleMode fromStorageValue(String? value) {
    final index = int.tryParse(value ?? '');
    if (index != null) return fromMobileIndex(index);
    return switch (value) {
      'system' => AppLocaleMode.system,
      'zh' => AppLocaleMode.zh,
      'en' => AppLocaleMode.en,
      'ja' => AppLocaleMode.ja,
      _ => AppLocaleMode.system,
    };
  }

  static AppLocaleMode fromMobileIndex(int index) {
    return switch (index) {
      1 || 3 => AppLocaleMode.zh,
      2 || 5 => AppLocaleMode.en,
      4 => AppLocaleMode.ja,
      _ => AppLocaleMode.system,
    };
  }

  static Locale resolveSystemLocale([Locale? systemLocale]) {
    final locale =
        systemLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
    return switch (locale.languageCode.toLowerCase()) {
      'zh' => const Locale('zh'),
      'ja' => const Locale('ja'),
      _ => const Locale('en'),
    };
  }
}

class AppLocaleState {
  const AppLocaleState({
    required this.mode,
    required this.locale,
  });

  factory AppLocaleState.fromMode(
    AppLocaleMode mode, [
    Locale? systemLocale,
  ]) {
    final locale = switch (mode) {
      AppLocaleMode.system => AppLocaleMode.resolveSystemLocale(systemLocale),
      _ => mode.explicitLocale,
    };
    return AppLocaleState(mode: mode, locale: locale);
  }

  final AppLocaleMode mode;
  final Locale locale;
}

class AppLocaleNotifier extends StateNotifier<AppLocaleState>
    with WidgetsBindingObserver {
  AppLocaleNotifier() : super(AppLocaleState.fromMode(AppLocaleMode.system)) {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'language';
  static const _legacyStorageKey = 'app_locale_mode';

  Future<void> _load() async {
    final value = await _storage.read(key: _storageKey);
    final legacyValue =
        value == null ? await _storage.read(key: _legacyStorageKey) : null;
    final mode = AppLocaleMode.fromStorageValue(value ?? legacyValue);
    state = AppLocaleState.fromMode(mode);
    if (value == null && legacyValue != null) {
      await _storage.write(key: _storageKey, value: '${mode.mobileIndex}');
    }
  }

  Future<void> setMode(AppLocaleMode mode) async {
    state = AppLocaleState.fromMode(mode);
    await _storage.write(key: _storageKey, value: '${mode.mobileIndex}');
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (state.mode != AppLocaleMode.system) return;
    state = AppLocaleState.fromMode(
      AppLocaleMode.system,
      locales?.firstOrNull,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, AppLocaleState>((ref) {
  return AppLocaleNotifier();
});
