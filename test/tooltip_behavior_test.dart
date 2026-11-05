import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/router/app_router.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/presentation/book_detail_screen.dart';
import 'package:lira/features/books/presentation/widgets/book_card.dart';
import 'package:lira/features/discover/domain/discover_item.dart';
import 'package:lira/features/discover/domain/discover_source.dart';
import 'package:lira/features/discover/presentation/discover_widgets.dart';
import 'package:lira/features/discover/presentation/material_detail_screen.dart';
import 'package:lira/features/search/domain/models/search_result_item.dart';
import 'package:lira/features/search/presentation/widgets/search_book_card.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:lira/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final book = BookDto(
    id: 'hover-book',
    title: 'A deliberately long book title that must not cover adjacent cards',
    author: 'A deliberately long author name',
    format: 'epub',
    pageCount: 1234,
    createdAt: DateTime(2026),
  );
  final source = discoverSourceCatalog.first;
  final item = DiscoverItem(
    id: 'hover-article',
    sourceId: source.id,
    title: 'A discovery article title that must stay inside its card',
    author: 'Article author',
    summary: 'An article summary for the discovery card.',
    url: Uri.parse('https://example.org/article'),
  );
  const searchBook = SearchResultItem(
    id: 'hover-search',
    title: 'A search result title',
    author: 'Search result author',
    format: 'epub',
    size: '1 MB',
    imgUrl: '',
    source: SearchResultSource.anna,
    originalObject: null,
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    await sharedPrefs.clear();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = BooksLocalRepository(database);
    getIt.registerSingleton<BooksLocalRepository>(repository);
    await repository.saveBook(book);
    addTearDown(() async {
      await getIt.reset();
      await database.close();
    });
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 210,
                  height:
                      210 / BookCard.coverAspectRatio +
                      BookCard.metadataExtent(
                        TextScaler.noScaling,
                        cardWidth: 210,
                        pageCountDigits: 4,
                      ),
                  child: BookCard(
                    book: book,
                    onTap: () => router.push('/book'),
                    onDelete: () =>
                        getIt<BooksLocalRepository>().deleteBook(book.id),
                  ),
                ),
                SizedBox(
                  width: 272,
                  height: 400,
                  child: DiscoverItemCard(
                    item: item,
                    source: source,
                    onTap: () => router.push('/article'),
                  ),
                ),
                const SizedBox(
                  width: 210,
                  height: 480,
                  child: SearchBookCard(book: searchBook),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/book',
          builder: (_, _) => BookDetailScreen(book: book),
        ),
        GoRoute(
          path: '/article',
          builder: (_, _) => MaterialDetailScreen(item: item, source: source),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [appRouterProvider.overrideWithValue(router)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LiraApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await mouse.removePointer();
  }

  Finder paintedTextContaining(String value) => find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(value),
  );

  testWidgets(
    'hovering book and page count never adds floating text',
    (tester) async {
      await mount(tester);
      await hover(tester, find.byType(BookCard));
      await hover(tester, find.text('1234'));
      expect(paintedTextContaining('1234'), findsOneWidget);
      await tester.tap(find.byType(BookCard));
      await tester.pumpAndSettle();
      expect(find.byType(BookDetailScreen), findsOneWidget);
      final semantics = tester.ensureSemantics();
      final back = find.byType(BackButton);
      final label = MaterialLocalizations.of(
        tester.element(back),
      ).backButtonTooltip;
      expect(tester.getSemantics(back).label, contains(label));
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('discovery save action stays named without a hover popup', (
    tester,
  ) async {
    await mount(tester);
    final card = find.byType(DiscoverItemCard);
    final l10n = AppLocalizations.of(tester.element(card))!;
    await hover(tester, card);
    expect(paintedTextContaining(item.title), findsOneWidget);
    final save = find.descendant(of: card, matching: find.byType(IconButton));
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(save).label, contains(l10n.discoverSave));
    await hover(tester, save);
    expect(paintedTextContaining(l10n.discoverSave), findsNothing);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search download action stays named without a hover popup', (
    tester,
  ) async {
    await mount(tester);
    final card = find.byType(SearchBookCard);
    final l10n = AppLocalizations.of(tester.element(card))!;
    final download = find.descendant(
      of: card,
      matching: find.byType(IconButton),
    );
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(download).label, contains(l10n.downloadBook));
    await hover(tester, download);
    expect(paintedTextContaining(l10n.downloadBook), findsNothing);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
