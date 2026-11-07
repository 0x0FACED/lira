import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/core/widgets/app_components.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/discover/domain/discover_content_providers.dart';
import 'package:lira/features/discover/domain/discover_item.dart';
import 'package:lira/features/discover/domain/discover_source.dart';
import 'package:lira/features/discover/domain/discover_sources_provider.dart';
import 'package:lira/features/discover/presentation/discover_screen.dart';
import 'package:lira/features/discover/presentation/discover_widgets.dart';
import 'package:lira/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<BooksLocalRepository>(
      BooksLocalRepository(database),
    );
  });
  tearDown(() async {
    await getIt.reset();
    await database.close();
  });

  for (final layout in [(1600.0, 900.0, 1.0), (390.0, 844.0, 1.6)]) {
    testWidgets('loaded mixed shelf fits captions and aligns content at $layout', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(layout.$1, layout.$2);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final source = discoverSourceCatalog.firstWhere(
        (s) => s.id == DiscoverSourceIds.cloudflare,
      );
      final items = [
        DiscoverItem(
          id: 'image',
          sourceId: source.id,
          title:
              'Introducing Zero Wire, a hub for investigating critical Internet vulnerabilities',
          author: 'Daniele Molteni, Celso Martinho',
          url: Uri.parse('https://example.com/zero-wire'),
          imageUrl: Uri.parse('https://example.com/zero-wire.png'),
          publishedAt: DateTime(2026, 11, 3),
        ),
        DiscoverItem(
          id: 'text',
          sourceId: source.id,
          title: 'Understanding the post-quantum future of web privacy',
          author: 'Christopher Patton',
          url: Uri.parse('https://example.com/privacy'),
          summary:
              'A technical explanation of the connection between privacy, cryptography and changes to everyday network infrastructure.',
          publishedAt: DateTime(2026, 11, 6),
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            enabledDiscoverSourcesProvider.overrideWithValue([source]),
            discoverFeedProvider(source.id).overrideWith(
              (ref) async =>
                  DiscoverFeed(items: items, updatedAt: DateTime(2026, 11, 8)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(layout.$3)),
              child: child!,
            ),
            home: const DiscoverScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = find.byType(DiscoverItemCard).first;
      final title = find.text(items.first.title);
      final save = find.descendant(of: card, matching: find.byType(IconButton));
      final bounds = tester.getRect(card);
      expect(tester.getRect(title).bottom, lessThan(tester.getRect(save).top));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(bounds.bottom));
      final search = find.byType(AppSearchField);
      expect(bounds.left, closeTo(tester.getRect(search).left, 0.01));
      expect(
        find
            .descendant(
              of: find.byType(AppPageHeader),
              matching: find.byType(TextButton),
            )
            .hitTestable(),
        findsOneWidget,
      );
    });
  }
}
