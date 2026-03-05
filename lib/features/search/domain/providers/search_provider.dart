import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annas_archive_api/annas_archive_api.dart' as anna;
import 'search_state.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier();
});

class SearchNotifier extends StateNotifier<SearchState> {
  final anna.AnnaApi _api;

  SearchNotifier() : _api = anna.AnnaApi(), super(const SearchState.initial());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState.initial();
      return;
    }

    state = const SearchState.loading();

    try {
      final results = await _api.find(anna.SearchRequest(query: query));
      state = SearchState.loaded(results.books);
    } catch (e) {
      state = SearchState.error(e.toString());
    }
  }

  void clear() {
    state = const SearchState.initial();
  }
}
