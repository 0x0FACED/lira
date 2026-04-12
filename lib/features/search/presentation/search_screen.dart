import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lira/features/search/domain/providers/search_state.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../books/presentation/library_screen.dart' show kBottomNavBarHeight;
import '../domain/models/search_result_item.dart';
import '../domain/providers/search_provider.dart';
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
  bool _hasFocus = false;

  FormatFilter _formatFilter = FormatFilter.all;
  SortOrder _sortOrder = SortOrder.relevance;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
    _searchController.addListener(() => setState(() {}));
  }

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

  List<SearchResultItem> _applyFilters(List<SearchResultItem> books) {
    var filtered = books;

    // Format filter
    if (_formatFilter == FormatFilter.epub) {
      filtered = filtered
          .where((b) => b.format.toLowerCase() == 'epub')
          .toList();
    } else if (_formatFilter == FormatFilter.pdf) {
      filtered = filtered
          .where((b) => b.format.toLowerCase() == 'pdf')
          .toList();
    }

    // Sort
    switch (_sortOrder) {
      case SortOrder.relevance:
        break; // keep original order
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final searchState = ref.watch(searchProvider);
    final searchSource = ref.watch(searchSourceProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            _buildSearchHeader(theme, l10n, searchSource),

            // Filters row (only visible when there are results)
            searchState.maybeMap(
              loaded: (state) => state.books.isNotEmpty
                  ? _buildFiltersRow(theme, state.books.length)
                  : const SizedBox.shrink(),
              error: (state) =>
                  state.partialResults != null &&
                      state.partialResults!.isNotEmpty
                  ? _buildFiltersRow(theme, state.partialResults!.length)
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),

            // Content
            Expanded(
              child: searchState.map(
                initial: (_) => _buildInitialState(theme, l10n, searchSource),
                loading: (_) => _buildLoadingState(theme),
                loaded: (state) => _buildResultsList(theme, state.books),
                error: (state) => _buildErrorState(theme, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search Header
  // ---------------------------------------------------------------------------

  Widget _buildSearchHeader(
    ThemeData theme,
    AppLocalizations l10n,
    SearchSource source,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF1A1D22)
        : const Color(0xFFF7F7F9);
    final fieldColor = isDark ? const Color(0xFF101317) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outline.withAlpha(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hasFocus
                      ? theme.colorScheme.primary.withAlpha(160)
                      : theme.colorScheme.outline.withAlpha(32),
                  width: _hasFocus ? 1.4 : 1,
                ),
                boxShadow: _hasFocus
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(18),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.search_rounded,
                    color: _hasFocus
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withAlpha(120),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: l10n.searchBooks,
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(100),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        isCollapsed: true,
                      ),
                      style: const TextStyle(fontSize: 16),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty) ...[
                    _buildHeaderIconButton(
                      icon: Icons.close_rounded,
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchProvider.notifier).clear();
                        setState(() {
                          _formatFilter = FormatFilter.all;
                          _sortOrder = SortOrder.relevance;
                        });
                      },
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ],
                  _buildHeaderIconButton(
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _performSearch,
                    color: _searchController.text.isNotEmpty
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withAlpha(80),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _buildSourceChips(theme, source),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Source Chips
  // ---------------------------------------------------------------------------

  Widget _buildSourceChips(ThemeData theme, SearchSource current) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _sourceChip(
          theme,
          "Anna's Archive",
          SearchSource.anna,
          current,
          Icons.public_rounded,
        ),
        _sourceChip(
          theme,
          'Z-Library',
          SearchSource.zlibrary,
          current,
          Icons.menu_book_rounded,
        ),
        _sourceChip(
          theme,
          'Both',
          SearchSource.both,
          current,
          Icons.merge_rounded,
        ),
      ],
    );
  }

  Widget _sourceChip(
    ThemeData theme,
    String label,
    SearchSource value,
    SearchSource current,
    IconData icon,
  ) {
    final selected = current == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(searchSourceProvider.notifier).setSource(value);
          if (_searchController.text.isNotEmpty) {
            _performSearch();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withAlpha(20)
                : theme.colorScheme.surface.withAlpha(140),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withAlpha(120)
                  : theme.colorScheme.outline.withAlpha(32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(150),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filters Row (format, sort, result count)
  // ---------------------------------------------------------------------------

  Widget _buildFiltersRow(ThemeData theme, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Format filter chips
          _formatChip(theme, 'All', FormatFilter.all),
          const SizedBox(width: 6),
          _formatChip(theme, 'EPUB', FormatFilter.epub),
          const SizedBox(width: 6),
          _formatChip(theme, 'PDF', FormatFilter.pdf),

          const Spacer(),

          // Sort button
          PopupMenuButton<SortOrder>(
            initialValue: _sortOrder,
            onSelected: (order) => setState(() => _sortOrder = order),
            tooltip: 'Sort',
            position: PopupMenuPosition.under,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              _sortMenuItem(
                SortOrder.relevance,
                'Relevance',
                Icons.auto_awesome_rounded,
              ),
              _sortMenuItem(
                SortOrder.titleAsc,
                'Title A–Z',
                Icons.sort_by_alpha_rounded,
              ),
              _sortMenuItem(
                SortOrder.titleDesc,
                'Title Z–A',
                Icons.sort_by_alpha_rounded,
              ),
              _sortMenuItem(
                SortOrder.authorAsc,
                'Author A–Z',
                Icons.person_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SortOrder> _sortMenuItem(
    SortOrder value,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
          if (_sortOrder == value) ...[
            const Spacer(),
            Icon(
              Icons.check_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  String _sortLabel() {
    return switch (_sortOrder) {
      SortOrder.relevance => 'Relevance',
      SortOrder.titleAsc => 'Title A–Z',
      SortOrder.titleDesc => 'Title Z–A',
      SortOrder.authorAsc => 'Author A–Z',
    };
  }

  Widget _formatChip(ThemeData theme, String label, FormatFilter filter) {
    final selected = _formatFilter == filter;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _formatFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withAlpha(30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withAlpha(100)
                  : theme.colorScheme.outline.withAlpha(40),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------------

  Widget _buildInitialState(
    ThemeData theme,
    AppLocalizations l10n,
    SearchSource source,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated gradient icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withAlpha(30),
                    theme.colorScheme.secondary.withAlpha(20),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.manage_search_rounded,
                size: 48,
                color: theme.colorScheme.primary.withAlpha(180),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.searchBooks,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _sourceDescription(source),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(140),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Quick hint chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _hintChip(theme, 'Title'),
                _hintChip(theme, 'Author'),
                _hintChip(theme, 'ISBN'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sourceDescription(SearchSource source) {
    return switch (source) {
      SearchSource.anna => "Search Anna's Archive for EPUB and PDF books.",
      SearchSource.zlibrary => 'Search Z-Library for EPUB and PDF books.',
      SearchSource.both =>
        "Search Anna's Archive and Z-Library simultaneously.",
    };
  }

  Widget _hintChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Searching...',
            style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(ThemeData theme, List<SearchResultItem> books) {
    final filtered = _applyFilters(books);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'No results match your filters',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _formatFilter = FormatFilter.all;
                _sortOrder = SortOrder.relevance;
              }),
              child: const Text('Reset filters'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withAlpha(100),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              kBottomNavBarHeight + MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return SearchBookCard(book: filtered[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, dynamic state) {
    final partialResults = state.partialResults as List<SearchResultItem>?;
    if (partialResults != null && partialResults.isNotEmpty) {
      final filtered = _applyFilters(partialResults);
      return Column(
        children: [
          // Warning banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Some sources failed: ${state.message}',
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withAlpha(100),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                kBottomNavBarHeight +
                    MediaQuery.of(context).padding.bottom +
                    16,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return SearchBookCard(book: filtered[index]);
              },
            ),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withAlpha(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Search failed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.message}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(120),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
