import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/navigation/presentation/main_shell.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/books/domain/models/book_dto.dart';
import '../../features/auth/domain/providers/auth_provider.dart';

GoRouter appRouter(WidgetRef ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: auth.isAuthenticated ? '/' : '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/reader',
        builder: (context, state) {
          final book = state.extra as BookDto;
          return ReaderScreen(book: book);
        },
      ),
    ],
    redirect: (context, state) {
      final isOnLogin = state.matchedLocation == '/login';

      if (!auth.isAuthenticated && !isOnLogin) {
        return '/login';
      }
      if (auth.isAuthenticated && isOnLogin) {
        return '/';
      }
      return null;
    },
  );
}
