import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/formatters.dart';
import 'package:lira/features/auth/domain/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AuthState> _loadAccess(ProviderContainer container) async {
  final loaded = Completer<AuthState>();
  final subscription = container.listen(authProvider, (_, next) {
    if (next.isAuthenticated && !loaded.isCompleted) loaded.complete(next);
  }, fireImmediately: true);
  try {
    return await loaded.future.timeout(const Duration(seconds: 2));
  } finally {
    subscription.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old local login preserves library access without a server identity',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_is_logged_in': true,
        'auth_username': 'Old local name',
        'pref_theme_mode': 'dark',
        'pref_proxy_port': 1081,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = await _loadAccess(container);
      expect(state.isGuest, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auth_is_guest'), isTrue);
      expect(prefs.containsKey('auth_is_logged_in'), isFalse);
      expect(prefs.containsKey('auth_username'), isFalse);
      expect(prefs.getString('pref_theme_mode'), 'dark');
      expect(prefs.getInt('pref_proxy_port'), 1081);
      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect((await _loadAccess(reopened)).isAuthenticated, isTrue);
    },
  );

  test('local entry persists without collecting credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).continueAsGuest();
    expect(container.read(authProvider).isAuthenticated, isTrue);
    final reopened = ProviderContainer();
    addTearDown(reopened.dispose);
    expect((await _loadAccess(reopened)).isGuest, isTrue);
  });

  test('library progress does not announce completion before 100 percent', () {
    expect(formatReadingPercentage(99.999, 'ru', floor: true), '99,9%');
    expect(formatReadingPercentage(100, 'ru', floor: true), '100,0%');
    expect(formatReadingPercentage(33.333, 'en'), '33.3%');
    expect(formatReadingPercentage(33.333, 'ru'), '33,3%');
  });
}
