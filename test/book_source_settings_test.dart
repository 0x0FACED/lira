import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/discover/domain/discover_source.dart';
import 'package:lira/features/discover/domain/discover_sources_provider.dart';
import 'package:lira/features/search/data/anna_archive_client.dart';
import 'package:lira/features/search/domain/models/search_result_item.dart';
import 'package:lira/features/search/domain/providers/anna_access_provider.dart';
import 'package:lira/features/search/domain/providers/book_source_clients.dart';
import 'package:lira/features/search/domain/providers/download_provider.dart';
import 'package:lira/features/search/domain/providers/search_provider.dart';
import 'package:lira/features/search/domain/providers/zlibrary_mirrors_provider.dart';
import 'package:lira/features/search/presentation/anna_access_screen.dart';
import 'package:lira/features/search/presentation/book_search_results.dart';
import 'package:lira/features/search/presentation/widgets/search_book_card.dart';
import 'package:lira/features/search/presentation/zlibrary_mirrors_screen.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchBook = SearchResultItem(
  id: 'first',
  title: 'Short title',
  author: 'Known author',
  format: 'epub',
  size: '1 MB',
  imgUrl: '',
  source: SearchResultSource.anna,
  originalObject: null,
);

void main() {
  test(
    'approved mirror edits preserve priority and survive reopening without readding removed defaults',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ZLibraryMirrorsNotifier(prefs);
      addTearDown(notifier.dispose);
      await notifier.setMirrors([
        'z-library.biz',
        'https://Z-LIB.SK/',
        'https://z-library.biz',
      ]);
      final reopened = ZLibraryMirrorsNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state, ['https://z-library.biz', 'https://z-lib.sk']);
      await reopened.setMirrors(['https://z-lib.sk']);
      final afterRemoval = ZLibraryMirrorsNotifier(prefs);
      addTearDown(afterRemoval.dispose);
      expect(afterRemoval.state, ['https://z-lib.sk']);
    },
  );

  test('unsafe mirror edits cannot replace the approved list', () async {
    SharedPreferences.setMockInitialValues({
      ZLibraryMirrorsNotifier.storageKey: ['https://z-library.biz'],
    });
    final notifier = ZLibraryMirrorsNotifier(
      await SharedPreferences.getInstance(),
    );
    addTearDown(notifier.dispose);
    for (final value in [
      'http://z-library.biz',
      'https://user:password@z-library.biz',
      'https://z-library.biz/search',
      'https://z-library.biz?token=secret',
    ]) {
      expect(() => notifier.setMirrors([value]), throwsFormatException);
      expect(notifier.state, ['https://z-library.biz']);
    }
    expect(() => notifier.setMirrors([]), throwsFormatException);
  });

  test(
    'Anna browser session stays pinned to its approved origin and can be removed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = AnnaAccessNotifier(prefs);
      addTearDown(notifier.dispose);
      await notifier.setSession(
        AnnaAccessSession(
          origin: 'https://annas-archive.gd',
          cookieHeader: 'Cookie: verification=opaque==; preference=one',
          userAgent: 'Test browser',
        ),
      );
      final reopened = AnnaAccessNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state?.origin, 'https://annas-archive.gd');
      expect(reopened.state?.cookies, {
        'verification': 'opaque==',
        'preference': 'one',
      });
      expect(
        () => AnnaAccessSession(
          origin: 'https://unapproved.example',
          cookieHeader: 'session=secret',
          userAgent: 'Test browser',
        ),
        throwsFormatException,
      );
      expect(
        () => AnnaAccessSession(
          origin: 'https://annas-archive.gd',
          cookieHeader: 'session=x\r\nInjected: value',
          userAgent: 'Test browser',
        ),
        throwsFormatException,
      );
      await reopened.setSession(null);
      final cleared = AnnaAccessNotifier(prefs);
      addTearDown(cleared.dispose);
      expect(cleared.state, isNull);
    },
  );
  test(
    'a failed participating source retains its identity and original error',
    () async {
      final source = discoverSourceCatalog.singleWhere(
        (source) => source.id == DiscoverSourceIds.anna,
      );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              error: StateError('offline fixture'),
            ),
          ),
        ),
      );
      final client = AnnaArchiveClient(
        dio: dio,
        mirrors: const ['https://annas-archive.gd'],
      );
      addTearDown(client.close);
      final container = ProviderContainer(
        overrides: [
          enabledDiscoverSourcesProvider.overrideWithValue([source]),
          annaArchiveClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        bookSearchProvider((query: 'offline', sourceId: null)).future,
      );

      expect(result.books, isEmpty);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.source, same(source));
      expect(result.failures.single.error, isA<AnnaArchiveException>());
    },
  );

  for (final language in ['en', 'ru']) {
    for (final partial in [false, true]) {
      testWidgets(
        '$language ${partial ? 'partial' : 'global'} failure recovers only the failed source',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final source = discoverSourceCatalog.singleWhere(
            (source) =>
                source.id ==
                (partial ? DiscoverSourceIds.zlibrary : DiscoverSourceIds.anna),
          );
          var attempts = 0;
          final container = ProviderContainer(
            overrides: [
              annaAccessPreferencesProvider.overrideWithValue(prefs),
              zLibraryMirrorPreferencesProvider.overrideWithValue(prefs),
              bookSearchProvider((query: 'books', sourceId: null)).overrideWith(
                (ref) async {
                  attempts++;
                  if (attempts > 1) return const BookSearchResult();
                  return BookSearchResult(
                    books: partial ? const [_searchBook] : const [],
                    failures: [
                      BookSearchFailure(
                        source: source,
                        error: StateError('transport fixture'),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: BookSearchResults(query: 'books')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(BookSearchResults)),
          )!;
          final recovery = find.widgetWithText(
            TextButton,
            partial ? l10n.zLibraryMirrors : l10n.annaSessionTitle,
          );
          expect(recovery, findsOneWidget);
          expect(
            find.widgetWithText(
              TextButton,
              partial ? l10n.annaSessionTitle : l10n.zLibraryMirrors,
            ),
            findsNothing,
          );
          expect(find.textContaining('transport fixture'), findsNothing);

          await tester.tap(recovery);
          await tester.pumpAndSettle();
          expect(
            partial
                ? find.byType(ZLibraryMirrorsScreen)
                : find.byType(AnnaAccessScreen),
            findsOneWidget,
          );
          Navigator.of(
            tester.element(
              partial
                  ? find.byType(ZLibraryMirrorsScreen)
                  : find.byType(AnnaAccessScreen),
            ),
          ).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.searchRetry));
          await tester.pumpAndSettle();
          expect(attempts, 2);
          expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
          expect(find.byType(SearchBookCard), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'scaled search captions align and downloading keeps cancellation usable',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const other = SearchResultItem(
        id: 'second',
        title: 'A long title that wraps over two lines in the search shelf',
        author: '',
        format: 'pdf',
        size: '10 MB',
        imgUrl: '',
        source: SearchResultSource.zlibrary,
        originalObject: null,
      );
      final container = ProviderContainer(
        overrides: [
          bookSearchProvider((query: 'books', sourceId: null)).overrideWith(
            (ref) async => const BookSearchResult(books: [_searchBook, other]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const Scaffold(body: BookSearchResults(query: 'books')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BookSearchResults)),
      )!;
      final firstTitle = find.text(_searchBook.title).last;
      final secondTitle = find.text(other.title).last;
      expect(
        tester.getTopLeft(firstTitle).dy,
        tester.getTopLeft(secondTitle).dy,
      );
      expect(
        tester.getTopLeft(find.text(_searchBook.author).last).dy,
        tester.getTopLeft(find.text(l10n.bookAuthorUnknown).last).dy,
      );
      expect(
        tester.getTopLeft(find.text("EPUB · Anna's · 1 MB")).dy,
        tester.getTopLeft(find.text('PDF · Z-Lib · 10 MB')).dy,
      );
      final before = tester.getTopLeft(firstTitle);
      final downloads = container.read(downloadNotifierProvider.notifier);
      final token = downloads.startDownload(_searchBook.id);
      downloads.setProgress(_searchBook.id, 0.5);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(firstTitle), before);
      await tester.tap(find.bySemanticsLabel(l10n.cancelDownload));
      await tester.pumpAndSettle();
      expect(token.isCancelled, isTrue);
      expect(find.bySemanticsLabel(l10n.cancelDownload), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
