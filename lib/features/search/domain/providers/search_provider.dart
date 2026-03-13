import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annas_archive_api/annas_archive_api.dart' as anna;
import 'package:zlibrary_api/zlibrary_api.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../models/search_result_item.dart';
import 'search_state.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  final anna.AnnaApi _annaApi;

  SearchNotifier(this._ref)
    : _annaApi = anna.AnnaApi(),
      super(const SearchState.initial());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState.initial();
      return;
    }

    state = const SearchState.loading();

    final source = _ref.read(searchSourceProvider);
    final zLibCreds = _ref.read(zLibraryCredentialsProvider);

    final zLibApi = ZLibraryApi(cookies: zLibCreds?.cookies);

    List<SearchResultItem> allResults = [];
    List<String> errors = [];

    Future<void> fetchAnna() async {
      try {
        final results = await _annaApi.find(
          anna.SearchRequest(
            query: query,
            formats: [anna.Format.epub, anna.Format.pdf],
          ),
        );
        allResults.addAll(
          results.books.map((b) => SearchResultItem.fromAnnaBook(b)),
        );
      } catch (e) {
        errors.add("Anna's Archive: $e");
      }
    }

    Future<void> fetchZLibrary() async {
      try {
        final results = await zLibApi.search(
          query: query,
          extensions: ['epub', 'pdf'],
        );
        allResults.addAll(
          results.map((b) => SearchResultItem.fromZLibraryBook(b)),
        );
      } catch (e) {
        errors.add('Z-Library: $e');
      }
    }

    try {
      if (source == SearchSource.anna) {
        await fetchAnna();
      } else if (source == SearchSource.zlibrary) {
        await fetchZLibrary();
      } else if (source == SearchSource.both) {
        await Future.wait([fetchAnna(), fetchZLibrary()]);
      }

      if (errors.isNotEmpty && allResults.isEmpty) {
        state = SearchState.error(errors.join('\n'));
      } else if (errors.isNotEmpty && allResults.isNotEmpty) {
        state = SearchState.error(
          errors.join('\n'),
          partialResults: allResults,
        );
      } else {
        state = SearchState.loaded(allResults);
      }
    } catch (e) {
      state = SearchState.error(e.toString());
    }
  }

  void clear() {
    state = const SearchState.initial();
  }
}
