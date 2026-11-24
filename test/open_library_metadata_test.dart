import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/books/data/open_library_client.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/open_library_genres.dart';
import 'package:lira/features/books/domain/providers/book_organization_provider.dart';
import 'package:lira/features/books/domain/providers/open_library_provider.dart';
import 'package:lira/features/books/presentation/open_library_dialog.dart';
import 'package:lira/l10n/app_localizations.dart';

class _PreviewCatalog extends OpenLibraryClient {
  _PreviewCatalog()
    : super(client: MockClient((_) => throw StateError('Unexpected request')));

  @override
  Future<List<OpenLibraryCandidate>> search({
    String? isbn,
    String? title,
    String? author,
    String? language,
  }) async => [
    OpenLibraryCandidate(
      workKey: '/works/OL1W',
      title: 'Catalog title',
      authors: ['Catalog author'],
      subjects: [],
    ),
  ];
}

void main() {
  test(
    'an ISBN shared by two editions cannot look like a unique match',
    () async {
      final client = OpenLibraryClient(
        searchInterval: Duration.zero,
        client: MockClient((request) async {
          final result = switch (request.url.path) {
            '/search.json' => {
              'numFound': 1,
              'docs': [
                {
                  'key': '/works/OL77W',
                  'title': 'The same work',
                  'editions': {
                    'numFound': 2,
                    'docs': [
                      {
                        'key': '/books/OL11M',
                        'isbn': ['9780140328721'],
                      },
                    ],
                  },
                },
              ],
            },
            '/works/OL77W/editions.json' => {
              'size': 3,
              'entries': [
                {
                  'key': '/books/OL11M',
                  'isbn_13': ['9780140328721'],
                },
                {
                  'key': '/books/OL12M',
                  'isbn_10': ['0140328726'],
                },
                {
                  'key': '/books/OL13M',
                  'isbn_13': ['9780140328738'],
                },
              ],
            },
            _ => throw StateError('Unexpected ${request.url}'),
          };
          return http.Response(jsonEncode(result), 200);
        }),
      );
      addTearDown(client.close);

      final matches = await client.search(isbn: '0-140-32872-6');
      expect(matches.map((match) => match.editionKey), [
        '/books/OL11M',
        '/books/OL12M',
      ]);
    },
  );

  test(
    'catalog changes cannot overwrite a local edit made during lookup',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = BooksLocalRepository(db);
      final original = BookDto(
        id: 'lookup-in-progress',
        title: 'draft-file',
        author: '',
        format: 'epub',
        createdAt: DateTime.utc(2026),
      );
      await repository.saveBook(original);
      await repository.updateBook(original.copyWith(author: 'Local author'));

      final rejected = await repository.applyCatalogMetadata(
        original,
        title: 'Catalog title',
        author: 'Catalog author',
      );
      expect(rejected, isNull);
      final stored = (await repository.getBookById(original.id))!;
      expect((stored.title, stored.author), ('draft-file', 'Local author'));

      // Applying just the selected title does not conflict with the author edit.
      await repository.applyCatalogMetadata(original, title: 'Catalog title');
      final applied = (await repository.getBookById(original.id))!;
      expect(
        (applied.title, applied.author),
        ('Catalog title', 'Local author'),
      );
    },
  );

  test(
    'catalog subjects add genres without replacing manual labels or aliases',
    () {
      final genreNames = openLibraryGenres([
        'Fiction, science fiction, general',
        'Science fiction',
        'Memory',
        'Plays',
        'Biography',
      ], russian: true);
      final merged = mergeOpenLibraryGenres([
        'To reread',
        'Sci-fi',
      ], genreNames);
      expect(merged, ['To reread', 'Sci-fi', 'Биография']);
    },
  );

  testWidgets(
    'preview fits a narrow window without artwork and applies only selected fields',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = BooksLocalRepository(db);
      getIt.registerSingleton<BooksLocalRepository>(repository);
      addTearDown(() async {
        await getIt.reset();
        await db.close();
      });
      final book = BookDto(
        id: 'narrow-preview',
        title: 'Local title',
        author: 'Local author',
        format: 'epub',
        createdAt: DateTime.utc(2026),
      );
      await repository.saveBook(book);
      final client = _PreviewCatalog();
      addTearDown(client.close);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 500);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [openLibraryClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => OpenLibraryDialog(
                      book: book,
                      organization: const BookOrganization(),
                    ),
                  ),
                  child: const Text('Open metadata'),
                ),
              ),
            ),
          ),
        ),
      );
      try {
        await tester.tap(find.text('Open metadata'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(OpenLibraryDialog)),
        )!;
        await tester.tap(find.widgetWithText(FilledButton, l10n.search));
        await tester.pumpAndSettle();
        final result = find.text('Catalog title');
        await tester.ensureVisible(result);
        await tester.tap(result);
        await tester.pumpAndSettle();
        expect(find.text(l10n.openLibraryPreview), findsOneWidget);

        final author = find.widgetWithText(
          CheckboxListTile,
          l10n.editBookAuthor,
        );
        await tester.ensureVisible(author);
        await tester.tap(author);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.openLibraryApply),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OpenLibraryDialog), findsNothing);
        final saved = (await repository.getBookById(book.id))!;
        expect((saved.title, saved.author), ('Catalog title', 'Local author'));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
