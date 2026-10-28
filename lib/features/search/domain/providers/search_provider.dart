import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../discover/domain/discover_source.dart';
import '../../../discover/domain/discover_sources_provider.dart';
import '../models/search_result_item.dart';
import 'book_source_clients.dart';

typedef BookSearchQuery = ({String query, String? sourceId});

class BookSearchResult {
  const BookSearchResult({this.books = const [], this.errors = const []});
  final List<SearchResultItem> books;
  final List<String> errors;
}

final bookSearchProvider = FutureProvider.autoDispose
    .family<BookSearchResult, BookSearchQuery>((ref, request) async {
      final query = request.query.trim();
      if (query.isEmpty) return const BookSearchResult();
      final catalog = ref.watch(discoverCatalogProvider);
      final sources = request.sourceId == null
          ? ref
                .watch(enabledDiscoverSourcesProvider)
                .where((source) => source.isBookSource)
                .toList()
          : catalog
                .where(
                  (source) =>
                      source.id == request.sourceId && source.isBookSource,
                )
                .toList();

      final results = await Future.wait(
        sources.map((source) async {
          try {
            final List<SearchResultItem> books;
            switch (source.kind) {
              case DiscoverSourceKind.anna:
                books = await ref
                    .watch(annaArchiveClientProvider)
                    .search(query);
              case DiscoverSourceKind.zlibrary:
                final response = await ref
                    .watch(zLibraryApiProvider)
                    .search(query: query, extensions: ['epub', 'pdf']);
                books = response
                    .map(SearchResultItem.fromZLibraryBook)
                    .toList();
              default:
                throw StateError('Unsupported book source: ${source.id}');
            }
            return BookSearchResult(books: books);
          } catch (error) {
            return BookSearchResult(errors: ['${source.name}: $error']);
          }
        }),
      );
      final books = <SearchResultItem>[];
      final seen = <String>{};
      for (final result in results) {
        for (final book in result.books) {
          if (seen.add('${book.source.name}:${book.id}')) books.add(book);
        }
      }
      return BookSearchResult(
        books: books,
        errors: [for (final result in results) ...result.errors],
      );
    });
