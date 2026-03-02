import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyIsGuest = 'auth_is_guest';
const _keyIsLoggedIn = 'auth_is_logged_in';
const _keyUsername = 'auth_username';

/// Auth state
class AuthState {
  final bool isGuest;
  final bool isLoggedIn;
  final String? username;

  const AuthState({
    this.isGuest = false,
    this.isLoggedIn = false,
    this.username,
  });

  bool get isAuthenticated => isGuest || isLoggedIn;
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _loadState();
    return const AuthState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = AuthState(
      isGuest: prefs.getBool(_keyIsGuest) ?? false,
      isLoggedIn: prefs.getBool(_keyIsLoggedIn) ?? false,
      username: prefs.getString(_keyUsername),
    );
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
    state = const AuthState(isGuest: true);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    // TODO: Call auth API
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUsername, username);
    state = AuthState(isLoggedIn: true, username: username);
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    // TODO: Call register API
    await login(username: username, password: password);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }
}
