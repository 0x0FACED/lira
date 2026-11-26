import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'socks5_secure_storage.dart';

const _keyThemeMode = 'pref_theme_mode';
const _keyLocale = 'pref_locale';
const _keyZLibCookies = 'pref_zlib_cookies';
const _keyZLibEmail = 'pref_zlib_email';
const _keyProxyEnabled = 'pref_proxy_enabled';
const _keyProxyHost = 'pref_proxy_host';
const _keyProxyPort = 'pref_proxy_port';
const _keyProxyEndpoint = 'pref_proxy_endpoint_v1';
const _keyProxySecret = 'socks5_endpoint_v1';

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
  final String? username;
  final String? password;
  final bool credentialsUnavailable;

  const Socks5Config({
    this.enabled = false,
    this.host = '127.0.0.1',
    this.port = 1080,
    this.username,
    this.password,
    this.credentialsUnavailable = false,
  });

  static bool validCredentials(String? username, String? password) {
    if (username == null && password == null) return true;
    if (username == null || password == null) return false;
    return validCredentialLength(utf8.encode(username).length) &&
        validCredentialLength(utf8.encode(password).length);
  }

  static bool validCredentialLength(int bytes) => bytes >= 1 && bytes <= 255;

  Socks5Config copyWith({
    bool? enabled,
    String? host,
    int? port,
    bool? credentialsUnavailable,
  }) {
    return Socks5Config(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username,
      password: password,
      credentialsUnavailable:
          credentialsUnavailable ?? this.credentialsUnavailable,
    );
  }
}

/// A single secure record owns both the authenticated endpoint and its pair.
/// The public manifest records auth intent before a first secret write, so an
/// unavailable keychain can never silently turn authentication off on restart.
class Socks5PreferencesStore {
  final SharedPreferences _prefs;
  final Socks5SecureStorage _secure;

  Socks5PreferencesStore(this._prefs, {Socks5SecureStorage? secureStorage})
    : _secure = secureStorage ?? PlatformSocks5SecureStorage();

  Future<Socks5Config> load() async {
    final enabled = _prefs.getBool(_keyProxyEnabled) ?? false;
    var host = _prefs.getString(_keyProxyHost) ?? '127.0.0.1';
    var port = _prefs.getInt(_keyProxyPort) ?? 1080;
    final manifest = _prefs.getString(_keyProxyEndpoint);
    if (manifest == null) {
      return Socks5Config(enabled: enabled, host: host, port: port);
    }
    try {
      final metadata = jsonDecode(manifest) as Map<String, dynamic>;
      host = metadata['host'] as String;
      port = metadata['port'] as int;
      if (!_validEndpoint(host, port)) throw const FormatException();
      final authenticated = metadata['authenticated'] as bool;
      if (!authenticated) {
        return Socks5Config(enabled: enabled, host: host, port: port);
      }
      final secret = await _secure.read(_keyProxySecret);
      if (secret == null) throw const FormatException();
      final record = jsonDecode(secret) as Map<String, dynamic>;
      final secretHost = record['host'] as String;
      final secretPort = record['port'] as int;
      final username = record['username'] as String;
      final password = record['password'] as String;
      if (!_validEndpoint(secretHost, secretPort) ||
          !Socks5Config.validCredentials(username, password)) {
        throw const FormatException();
      }
      return Socks5Config(
        enabled: enabled,
        host: secretHost,
        port: secretPort,
        username: username,
        password: password,
      );
    } catch (_) {
      return Socks5Config(
        enabled: enabled,
        host: host,
        port: port,
        credentialsUnavailable: true,
      );
    }
  }

  Future<Socks5Config> setEnabled(bool enabled) async {
    if (!await _prefs.setBool(_keyProxyEnabled, enabled)) {
      throw StateError('Could not save proxy settings');
    }
    return load();
  }

  Future<Socks5Config> setEndpoint(
    String host,
    int port, {
    String? username,
    String? password,
  }) async {
    if (!_validEndpoint(host, port) ||
        !Socks5Config.validCredentials(username, password)) {
      throw ArgumentError('Invalid proxy endpoint or credentials');
    }
    final authenticated = username != null;
    final oldManifest = _prefs.getString(_keyProxyEndpoint);
    // Malformed metadata must also require an explicit successful clear.
    var previouslyAuthenticated = oldManifest != null;
    if (oldManifest != null) {
      try {
        previouslyAuthenticated =
            (jsonDecode(oldManifest)
                as Map<String, dynamic>)['authenticated'] !=
            false;
      } catch (_) {
        previouslyAuthenticated = true;
      }
    }
    final manifest = jsonEncode({
      'host': host,
      'port': port,
      'authenticated': authenticated,
    });
    if (authenticated) {
      if (!previouslyAuthenticated) await _writeManifest(manifest);
      await _secure.write(
        _keyProxySecret,
        jsonEncode({
          'host': host,
          'port': port,
          'username': username,
          'password': password,
        }),
      );
      if (previouslyAuthenticated) await _writeManifest(manifest);
    } else if (previouslyAuthenticated) {
      // Clear before publishing no-auth. A failed delete leaves the manifest
      // authenticated, and a failed manifest write leaves it fail-closed.
      await _secure.delete(_keyProxySecret);
      if (await _secure.read(_keyProxySecret) != null) {
        throw StateError('Could not clear proxy credentials');
      }
    }
    if (!authenticated) await _writeManifest(manifest);
    // Read once after committing. Also catches keychains that acknowledge a
    // write without retaining it, without publishing incomplete credentials.
    final config = await load();
    if (config.credentialsUnavailable ||
        config.host != host ||
        config.port != port ||
        config.username != username ||
        config.password != password) {
      throw StateError('Could not save proxy settings');
    }
    return config;
  }

  Future<void> _writeManifest(String manifest) async {
    if (!await _prefs.setString(_keyProxyEndpoint, manifest)) {
      throw StateError('Could not save proxy settings');
    }
  }

  Future<Socks5Config> reloadAfterFailure() async {
    try {
      // SharedPreferences updates its cache even when persistence fails.
      await _prefs.reload();
      return await load();
    } catch (_) {
      return const Socks5Config(enabled: true, credentialsUnavailable: true);
    }
  }

  static bool _validEndpoint(String host, int port) =>
      host.isNotEmpty && port >= 1 && port <= 65535;
}

final socks5PreferencesStoreProvider = FutureProvider<Socks5PreferencesStore>(
  (ref) async => Socks5PreferencesStore(await SharedPreferences.getInstance()),
);

/// Production overrides this after loading persistence, before clients exist.
final initialSocks5ConfigProvider = Provider<Socks5Config?>((ref) => null);

final socks5ConfigProvider =
    NotifierProvider<Socks5ConfigNotifier, Socks5Config>(
      () => Socks5ConfigNotifier(),
    );

class Socks5ConfigNotifier extends Notifier<Socks5Config> {
  late Future<void> _ready;
  Future<void> _pending = Future<void>.value();
  bool _disposed = false;

  @override
  Socks5Config build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final initial = ref.read(initialSocks5ConfigProvider);
    if (initial != null) {
      _ready = Future<void>.value();
      return initial;
    }
    _ready = _load();
    // Until preferences have loaded, never allow a transient direct request.
    return const Socks5Config(enabled: true, credentialsUnavailable: true);
  }

  Future<void> _load() async {
    try {
      final store = await ref.read(socks5PreferencesStoreProvider.future);
      final config = await store.load();
      if (!_disposed) state = config;
    } catch (_) {
      // A preferences failure is not evidence that the proxy was disabled.
      if (!_disposed) {
        state = const Socks5Config(enabled: true, credentialsUnavailable: true);
      }
    }
  }

  Future<void> setEnabled(bool enabled) =>
      _save((store) => store.setEnabled(enabled));

  Future<void> setEndpoint(
    String host,
    int port, {
    String? username,
    String? password,
  }) => _save(
    (store) =>
        store.setEndpoint(host, port, username: username, password: password),
  );

  Future<void> _save(
    Future<Socks5Config> Function(Socks5PreferencesStore store) operation,
  ) {
    final result = _pending.then((_) async {
      await _ready;
      Socks5PreferencesStore? store;
      try {
        final resolved = await ref.read(socks5PreferencesStoreProvider.future);
        store = resolved;
        final config = await operation(resolved);
        if (!_disposed) state = config;
      } catch (_) {
        final config = store == null
            ? const Socks5Config(enabled: true, credentialsUnavailable: true)
            : await store.reloadAfterFailure();
        if (!_disposed) state = config;
        // Never expose platform error details, which may contain secret data.
        throw StateError('Could not save proxy settings');
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
