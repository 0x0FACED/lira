import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/data/settings_provider.dart' show sharedPrefs;
import '../../data/anna_archive_client.dart';

class AnnaAccessSession {
  AnnaAccessSession({
    required String origin,
    required String cookieHeader,
    required String userAgent,
  }) : origin = Uri.parse(origin).origin,
       cookieHeader = cookieHeader.trim().replaceFirst(
         RegExp(r'^cookie:\s*', caseSensitive: false),
         '',
       ),
       userAgent = userAgent.trim() {
    if (!defaultAnnaArchiveMirrors.contains(this.origin) ||
        this.userAgent.isEmpty ||
        this.userAgent.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException(
        'Invalid Anna browser session origin or User-Agent',
      );
    }
    if (cookies.isEmpty)
      throw const FormatException('Browser cookies are required');
  }

  final String origin;
  final String cookieHeader;
  final String userAgent;

  late final Map<String, String> cookies = _parseCookies();

  Map<String, String> _parseCookies() {
    final parsed = <String, String>{};
    for (final part in cookieHeader.split(';')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      final separator = token.indexOf('=');
      if (separator <= 0) throw const FormatException('Invalid Cookie header');
      final key = token.substring(0, separator);
      final value = token.substring(separator + 1);
      if (!RegExp(r'^[!#$%&\x27*+\-.^_`|~0-9A-Za-z]+$').hasMatch(key) ||
          value.contains(RegExp(r'[\x00-\x20\x7f]'))) {
        throw const FormatException('Invalid Cookie header');
      }
      parsed[key] = value;
    }
    return Map.unmodifiable(parsed);
  }

  Map<String, String> toJson() => {
    'origin': origin,
    'cookieHeader': cookieHeader,
    'userAgent': userAgent,
  };
  factory AnnaAccessSession.fromJson(Map<String, dynamic> json) =>
      AnnaAccessSession(
        origin: json['origin'] as String,
        cookieHeader: json['cookieHeader'] as String,
        userAgent: json['userAgent'] as String,
      );
}

final annaAccessPreferencesProvider = Provider<SharedPreferences>(
  (ref) => sharedPrefs,
);
final annaAccessSessionProvider =
    StateNotifierProvider<AnnaAccessNotifier, AnnaAccessSession?>(
      (ref) => AnnaAccessNotifier(ref.watch(annaAccessPreferencesProvider)),
    );

class AnnaAccessNotifier extends StateNotifier<AnnaAccessSession?> {
  AnnaAccessNotifier(this._prefs) : super(_load(_prefs));
  static const storageKey = 'anna_browser_access_session';
  final SharedPreferences _prefs;
  Future<void> _pending = Future<void>.value();

  static AnnaAccessSession? _load(SharedPreferences prefs) {
    final stored = prefs.getString(storageKey);
    if (stored == null) return null;
    try {
      return AnnaAccessSession.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setSession(AnnaAccessSession? session) {
    final write = _pending.then((_) async {
      try {
        final saved = session == null
            ? await _prefs.remove(storageKey)
            : await _prefs.setString(storageKey, jsonEncode(session.toJson()));
        if (!saved) throw StateError('Could not persist Anna browser access');
        if (mounted) state = session;
      } catch (_) {
        try {
          await _prefs.reload();
        } catch (_) {}
        rethrow;
      }
    });
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
