import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyIsGuest = 'auth_is_guest';

/// Local access only. Lira does not have a server account service.
class AuthState {
  final bool isGuest;

  const AuthState({this.isGuest = false});

  bool get isAuthenticated => isGuest;
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  bool _active = true;

  @override
  AuthState build() {
    _active = true;
    ref.onDispose(() => _active = false);
    _loadState();
    return const AuthState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    // Older builds stored a local name as if it were a server login. Preserve
    // access to that library, without presenting it as a verified account.
    final legacyLogin = prefs.getBool('auth_is_logged_in') ?? false;
    final localAccess = (prefs.getBool(_keyIsGuest) ?? false) || legacyLogin;
    if (legacyLogin) {
      await prefs.setBool(_keyIsGuest, true);
      await prefs.remove('auth_is_logged_in');
      await prefs.remove('auth_username');
    }
    if (_active) state = AuthState(isGuest: localAccess);
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
    if (_active) state = const AuthState(isGuest: true);
  }
}
