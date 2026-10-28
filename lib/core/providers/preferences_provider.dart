import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const _keyThemeMode = 'pref_theme_mode';
const _keyLocale = 'pref_locale';
const _keyZLibCookies = 'pref_zlib_cookies';
const _keyZLibEmail = 'pref_zlib_email';
const _keyProxyEnabled = 'pref_proxy_enabled';
const _keyProxyHost = 'pref_proxy_host';
const _keyProxyPort = 'pref_proxy_port';

/// Theme mode provider
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  () => ThemeModeNotifier(),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeMode) ?? 'light';
    state = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
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

class ZLibCredentials {
  final Map<String, String> cookies;
  final String email;

  const ZLibCredentials({required this.cookies, required this.email});
}

/// ZLibrary credentials provider
final zLibraryCredentialsProvider =
    NotifierProvider<ZLibraryCredentialsNotifier, ZLibCredentials?>(
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
        final cookies = decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        state = ZLibCredentials(cookies: cookies, email: email);
      } catch (e) {
        state = null;
      }
    } else {
      state = null;
    }
  }

  Future<void> saveCredentials(
    String email,
    Map<String, String> cookies,
  ) async {
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

/// SOCKS5 proxy configuration
class Socks5Config {
  final bool enabled;
  final String host;
  final int port;

  const Socks5Config({
    this.enabled = false,
    this.host = '127.0.0.1',
    this.port = 1080,
  });

  Socks5Config copyWith({bool? enabled, String? host, int? port}) {
    return Socks5Config(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }
}

final socks5ConfigProvider =
    NotifierProvider<Socks5ConfigNotifier, Socks5Config>(
      () => Socks5ConfigNotifier(),
    );

class Socks5ConfigNotifier extends Notifier<Socks5Config> {
  @override
  Socks5Config build() {
    _load();
    return const Socks5Config();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = Socks5Config(
      enabled: prefs.getBool(_keyProxyEnabled) ?? false,
      host: prefs.getString(_keyProxyHost) ?? '127.0.0.1',
      port: prefs.getInt(_keyProxyPort) ?? 1080,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProxyEnabled, enabled);
  }

  Future<void> setHost(String host) async {
    state = state.copyWith(host: host);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProxyHost, host);
  }

  Future<void> setPort(int port) async {
    state = state.copyWith(port: port);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyProxyPort, port);
  }
}
