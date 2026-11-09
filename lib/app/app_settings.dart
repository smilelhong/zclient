import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_kv.dart';

/// App-level presentation settings (theme mode + locale), persisted in
/// AppKv and hydrated asynchronously on startup.
class AppSettings extends Notifier<({ThemeMode theme, Locale? locale})> {
  static const _themeKey = 'zc.settings.theme';
  static const _localeKey = 'zc.settings.locale';

  @override
  ({ThemeMode theme, Locale? locale}) build() {
    unawaited(_hydrate());
    return (theme: ThemeMode.system, locale: null);
  }

  Future<void> _hydrate() async {
    try {
      final t = await AppKv.instance.getString(_themeKey);
      final l = await AppKv.instance.getString(_localeKey);
      state = (
        theme: switch (t) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        locale: switch (l) {
          'zh' => const Locale('zh'),
          'en' => const Locale('en'),
          _ => null,
        },
      );
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = (theme: mode, locale: state.locale);
    try {
      await AppKv.instance.setString(_themeKey, mode.name);
    } catch (_) {}
  }

  Future<void> setLocale(Locale? locale) async {
    state = (theme: state.theme, locale: locale);
    try {
      if (locale == null) {
        await AppKv.instance.remove(_localeKey);
      } else {
        await AppKv.instance.setString(_localeKey, locale.languageCode);
      }
    } catch (_) {}
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettings, ({ThemeMode theme, Locale? locale})>(
  AppSettings.new,
);
