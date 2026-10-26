import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/presentation/widgets/responsive_grid_delegate.dart';
import '../domain/models/search_result_item.dart';
import '../domain/providers/search_provider.dart';
import '../domain/providers/search_state.dart';
import 'widgets/search_book_card.dart';

/// Format filter for search results (client-side filtering).
enum FormatFilter { all, epub, pdf }

/// Sort order for search results.
enum SortOrder { relevance, titleAsc, titleDesc, authorAsc }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  FormatFilter _formatFilter = FormatFilter.all;
  SortOrder _sortOrder = SortOrder.relevance;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text;
    if (query.trim().isEmpty) return;
    ref.read(searchProvider.notifier).search(query);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    ref.read(searchProvider.notifier).clear();
    _resetFilters();
  }

  void _resetFilters() {
    setState(() {
      _formatFilter = FormatFilter.all;
      _sortOrder = SortOrder.relevance;
    });
  }

  List<SearchResultItem> _applyFilters(List<SearchResultItem> books) {
    var filtered = books;
    if (_formatFilter == FormatFilter.epub) {
      filtered = filtered
          .where((book) => book.format.toLowerCase() == 'epub')
          .toList();
    } else if (_formatFilter == FormatFilter.pdf) {
      filtered = filtered
          .where((book) => book.format.toLowerCase() == 'pdf')
          .toList();
    }
    switch (_sortOrder) {
      case SortOrder.relevance:
        break;
      case SortOrder.titleAsc:
        filtered = List.of(filtered)
          ..sort((a, b) => a.title.compareTo(b.title));
      case SortOrder.titleDesc:
        filtered = List.of(filtered)
          ..sort((a, b) => b.title.compareTo(a.title));
      case SortOrder.authorAsc:
        filtered = List.of(filtered)
          ..sort((a, b) => a.author.compareTo(b.author));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchState = ref.watch(searchProvider);
    final source = ref.watch(searchSourceProvider);
    final resultBooks = searchState.maybeMap(
      loaded: (state) => state.books,
      error: (state) => state.partialResults,
      orElse: () => null,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: AppPageHeader(title: l10n.search)),
                SliverToBoxAdapter(child: _buildSearchHeader(l10n, source)),
                if (resultBooks != null && resultBooks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFilters(
                      l10n,
                      _applyFilters(resultBooks).length,
                    ),
                  ),
                ..._buildContentSlivers(searchState, l10n, source),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.md),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(AppLocalizations l10n, SearchSource source) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.compact,
        0,
        AppSpacing.compact,
        AppSpacing.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: _searchController,
            focusNode: _focusNode,
            hintText: l10n.searchBooks,
            onSubmitted: (_) => _performSearch(),
            onSearch: _performSearch,
            onClear: _clearSearch,
          ),
          const SizedBox(height: AppSpacing.compact),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _sourceChip(
                "Anna's Archive",
                SearchSource.anna,
                source,
                Icons.public_outlined,
              ),
              _sourceChip(
                l10n.zLibrary,
                SearchSource.zlibrary,
                source,
                Icons.menu_book_outlined,
              ),
              _sourceChip(
                l10n.searchBothSources,
                SearchSource.both,
                source,
                Icons.merge_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(
    String label,
    SearchSource value,
    SearchSource current,
    IconData icon,
  ) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: current == value,
      onSelected: (_) {
        ref.read(searchSourceProvider.notifier).setSource(value);
        if (_searchController.text.isNotEmpty) _performSearch();
      },
    );
  }

  Widget _buildFilters(AppLocalizations l10n, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.compact,
        0,
        AppSpacing.compact,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _formatChip(l10n.searchAllFormats, FormatFilter.all),
              _formatChip('EPUB', FormatFilter.epub),
              _formatChip('PDF', FormatFilter.pdf),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _sortLabel(l10n, _sortOrder),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  PopupMenuButton<SortOrder>(
                    initialValue: _sortOrder,
                    tooltip: l10n.searchSort,
                    icon: const Icon(Icons.sort_rounded),
                    onSelected: (value) => setState(() => _sortOrder = value),
                    itemBuilder: (context) => [
                      for (final order in SortOrder.values)
                        CheckedPopupMenuItem(
                          value: order,
                          checked: _sortOrder == order,
                          child: Text(_sortLabel(l10n, order)),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.searchResultsCount(count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label, FormatFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _formatFilter == filter,
      onSelected: (_) => setState(() => _formatFilter = filter),
    );
  }

  String _sortLabel(AppLocalizations l10n, SortOrder order) => switch (order) {
    SortOrder.relevance => l10n.searchSortRelevance,
    SortOrder.titleAsc => l10n.searchSortTitleAsc,
    SortOrder.titleDesc => l10n.searchSortTitleDesc,
    SortOrder.authorAsc => l10n.searchSortAuthorAsc,
  };

  List<Widget> _buildContentSlivers(
    SearchState state,
    AppLocalizations l10n,
    SearchSource source,
  ) {
    final colors = Theme.of(context).colorScheme;
    return state.map(
      initial: (_) => [
        _stateSliver(
          AppEmptyState(
            key: const ValueKey('search-initial'),
            icon: Icons.manage_search_outlined,
            title: l10n.searchBooks,
            description: switch (source) {
              SearchSource.anna => l10n.searchAnnaDescription,
              SearchSource.zlibrary => l10n.searchZLibraryDescription,
              SearchSource.both => l10n.searchBothDescription,
            },
          ),
        ),
      ],
      loading: (_) => [
        _stateSliver(
          Padding(
            key: const ValueKey('search-loading'),
            padding: const EdgeInsets.all(AppSpacing.compact),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.searchLoading,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      loaded: (result) => _resultSlivers(result.books, l10n),
      error: (error) {
        final partial = error.partialResults;
        if (partial != null && partial.isNotEmpty) {
          return [
            SliverToBoxAdapter(
              child: AppSurface(
                color: colors.secondaryContainer,
                padding: const EdgeInsets.all(AppSpacing.compact),
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.compact,
                  0,
                  AppSpacing.compact,
                  AppSpacing.compact,
                ),
                radius: AppRadius.md,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.compact),
                    Expanded(
                      child: Text(
                        '${l10n.searchSourcesPartialFailure}\n${error.message}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._resultSlivers(partial, l10n),
          ];
        }
        return [
          _stateSliver(
            AppEmptyState(
              key: const ValueKey('search-error'),
              icon: Icons.cloud_off_outlined,
              iconColor: colors.error,
              title: l10n.searchFailed,
              description: error.message,
              action: FilledButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.searchRetry),
              ),
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _resultSlivers(
    List<SearchResultItem> books,
    AppLocalizations l10n,
  ) {
    final filtered = _applyFilters(books);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (filtered.isEmpty) {
      return [
        _stateSliver(
          AppEmptyState(
            key: ValueKey(books.isEmpty ? 'search-empty' : 'search-filtered'),
            icon: books.isEmpty
                ? Icons.search_off_rounded
                : Icons.filter_alt_off_outlined,
            title: books.isEmpty
                ? l10n.searchNoResults
                : l10n.searchNoFilterResults,
            action: books.isEmpty
                ? null
                : TextButton(
                    onPressed: _resetFilters,
                    child: Text(l10n.searchResetFilters),
                  ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
        sliver: SliverGrid(
          gridDelegate: ResponsiveGridDelegate(
            minCrossAxisExtent:
                MediaQuery.sizeOf(context).width >= AppLayout.desktopBreakpoint
                ? 180
                : 148,
            maxCrossAxisExtent: 240,
            crossAxisSpacing: AppSpacing.compact,
            mainAxisSpacing: AppSpacing.compact,
            childAspectRatio: 0.40 / (textScale < 1 ? 1 : textScale),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => SearchBookCard(book: filtered[index]),
            childCount: filtered.length,
          ),
        ),
      ),
    ];
  }

  Widget _stateSliver(Widget child) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: AppStateTransition(child: child)),
    );
  }
}
