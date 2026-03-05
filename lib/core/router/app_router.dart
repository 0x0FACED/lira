import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/navigation/presentation/main_shell.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/books/presentation/book_detail_screen.dart';
import '../../features/books/domain/models/book_dto.dart';
import '../../features/auth/domain/providers/auth_provider.dart';

/// Converts a Riverpod provider into a [Listenable] so GoRouter
/// can call [redirect] without rebuilding the entire router.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Stable router provider — GoRouter is created once, redirect reacts
/// to auth changes via [refreshListenable].
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthChangeNotifier(ref);

  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/book-detail',
        builder: (context, state) {
          final book = state.extra as BookDto;
          return BookDetailScreen(book: book);
        },
      ),
      GoRoute(
        path: '/reader',
        builder: (context, state) {
          final book = state.extra as BookDto;
          return ReaderScreen(book: book);
        },
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isOnLogin = state.matchedLocation == '/login';

      // Not authenticated at all → force login
      if (!auth.isAuthenticated && !isOnLogin) {
        return '/login';
      }
      // Fully logged-in user (not guest) on login page → go home
      if (auth.isLoggedIn && isOnLogin) {
        return '/';
      }
      return null;
    },
  );
});
