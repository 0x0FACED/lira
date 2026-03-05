import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lira/features/search/domain/providers/search_state.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/providers/search_provider.dart';
import 'widgets/search_book_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text;
    if (query.trim().isEmpty) {
      return;
    }
    ref.read(searchProvider.notifier).search(query);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: l10n.searchBooks,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _performSearch(),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  ref.read(searchProvider.notifier).clear();
                  setState(() {}); // refresh cross icon visibility
                },
              ),
          ],
        ),
      ),
      body: searchState.map(
        initial: (_) => _buildInitialState(theme, l10n),
        loading: (_) => const Center(child: CircularProgressIndicator()),
        loaded: (state) {
          final books = state.books;
          if (books.isEmpty) {
            return Center(
              child: Text(
                'No results found',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              return SearchBookCard(book: books[index]);
            },
          );
        },
        error: (state) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error searching: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.primary.withAlpha(120),
            ),
            const SizedBox(height: 24),
            Text(l10n.searchBooks, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              "Search Anna's Archive for epub and pdf books. Enter a title, author, or ISBN.",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
