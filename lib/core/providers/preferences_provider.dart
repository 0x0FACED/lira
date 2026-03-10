import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const _keyThemeMode = 'pref_theme_mode';
const _keyLocale = 'pref_locale';
const _keySearchSource = 'pref_search_source';
const _keyZLibCookies = 'pref_zlib_cookies';
const _keyZLibEmail = 'pref_zlib_email';

enum SearchSource {
  anna,
  zlibrary,
  both,
}

/// Theme mode provider
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  () => ThemeModeNotifier(),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.dark;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeMode) ?? 'dark';
    state = value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      await prefs.setString(_keyThemeMode, 'light');
    } else {
      state = ThemeMode.dark;
      await prefs.setString(_keyThemeMode, 'dark');
    }
  }
}

/// Locale provider
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  () => LocaleNotifier(),
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return const Locale('en');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLocale) ?? 'en';
    state = Locale(code);
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, languageCode);
    state = Locale(languageCode);
  }
}

/// Search source provider
final searchSourceProvider = NotifierProvider<SearchSourceNotifier, SearchSource>(
  () => SearchSourceNotifier(),
);

class SearchSourceNotifier extends Notifier<SearchSource> {
  @override
  SearchSource build() {
    _load();
    return SearchSource.anna; // Default to anna since it doesn't require login
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keySearchSource);
    if (val == 'zlibrary') {
      state = SearchSource.zlibrary;
    } else if (val == 'both') {
      state = SearchSource.both;
    } else {
      state = SearchSource.anna;
    }
  }

  Future<void> setSource(SearchSource source) async {
    state = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySearchSource, source.name);
  }
}

class ZLibCredentials {
  final Map<String, String> cookies;
  final String email;

  const ZLibCredentials({required this.cookies, required this.email});
}

/// ZLibrary credentials provider
final zLibraryCredentialsProvider = NotifierProvider<ZLibraryCredentialsNotifier, ZLibCredentials?>(
  () => ZLibraryCredentialsNotifier(),
);

class ZLibraryCredentialsNotifier extends Notifier<ZLibCredentials?> {
  @override
  ZLibCredentials? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cookiesStr = prefs.getString(_keyZLibCookies);
    final email = prefs.getString(_keyZLibEmail);

    if (cookiesStr != null && email != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cookiesStr);
        final cookies = decoded.map((key, value) => MapEntry(key, value.toString()));
        state = ZLibCredentials(cookies: cookies, email: email);
      } catch (e) {
        state = null;
      }
    } else {
      state = null;
    }
  }

  Future<void> saveCredentials(String email, Map<String, String> cookies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyZLibEmail, email);
    await prefs.setString(_keyZLibCookies, jsonEncode(cookies));
    state = ZLibCredentials(cookies: cookies, email: email);
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyZLibEmail);
    await prefs.remove(_keyZLibCookies);
    state = null;
  }
}

