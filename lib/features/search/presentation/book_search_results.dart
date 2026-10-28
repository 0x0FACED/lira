import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/presentation/widgets/responsive_grid_delegate.dart';
import '../../discover/domain/discover_source.dart';
import '../domain/models/search_result_item.dart';
import '../domain/providers/search_provider.dart';
import 'anna_access_screen.dart';
import 'zlibrary_mirrors_screen.dart';
import 'widgets/search_book_card.dart';

enum _FormatFilter { all, epub, pdf }

enum _SortOrder { relevance, titleAsc, titleDesc, authorAsc }

class BookSearchResults extends ConsumerStatefulWidget {
  const BookSearchResults({super.key, required this.query, this.sourceId});
  final String query;
  final String? sourceId;

  @override
  ConsumerState<BookSearchResults> createState() => _BookSearchResultsState();
}

class _BookSearchResultsState extends ConsumerState<BookSearchResults> {
  _FormatFilter _format = _FormatFilter.all;
  _SortOrder _sort = _SortOrder.relevance;

  @override
  void didUpdateWidget(covariant BookSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.sourceId != widget.sourceId) {
      _format = _FormatFilter.all;
      _sort = _SortOrder.relevance;
    }
  }

  List<SearchResultItem> _filter(List<SearchResultItem> books) {
    final result = books
        .where(
          (book) =>
              _format == _FormatFilter.all ||
              book.format.toLowerCase() == _format.name,
        )
        .toList();
    switch (_sort) {
      case _SortOrder.relevance:
        break;
      case _SortOrder.titleAsc:
        result.sort((a, b) => a.title.compareTo(b.title));
      case _SortOrder.titleDesc:
        result.sort((a, b) => b.title.compareTo(a.title));
      case _SortOrder.authorAsc:
        result.sort((a, b) => a.author.compareTo(b.author));
    }
    return result;
  }

  String _sortLabel(AppLocalizations l10n, _SortOrder sort) => switch (sort) {
    _SortOrder.relevance => l10n.searchSortRelevance,
    _SortOrder.titleAsc => l10n.searchSortTitleAsc,
    _SortOrder.titleDesc => l10n.searchSortTitleDesc,
    _SortOrder.authorAsc => l10n.searchSortAuthorAsc,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.query.trim().isEmpty) {
      return AppEmptyState(
        icon: Icons.manage_search_outlined,
        title: l10n.searchBooks,
      );
    }
    final request = (query: widget.query, sourceId: widget.sourceId);
    return ref
        .watch(bookSearchProvider(request))
        .when(
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.searchLoading),
              ],
            ),
          ),
          error: (error, stack) => _failure(l10n, error.toString(), request),
          data: (result) {
            if (result.books.isEmpty && result.errors.isNotEmpty) {
              return _failure(l10n, result.errors.join('\n'), request);
            }
            final books = _filter(result.books);
            final theme = Theme.of(context);
            final bodySize = theme.textTheme.bodyMedium!.fontSize!;
            final textScale =
                MediaQuery.textScalerOf(context).scale(bodySize) / bodySize;
            return CustomScrollView(
              key: PageStorageKey(
                'book-search-${widget.sourceId}-${widget.query}',
              ),
              slivers: [
                if (result.errors.isNotEmpty)
                  SliverToBoxAdapter(
                    child: AppSurface(
                      margin: const EdgeInsets.all(AppSpacing.compact),
                      color: theme.colorScheme.secondaryContainer,
                      child: Text(
                        '${l10n.searchSourcesPartialFailure}\n${result.errors.join('\n')}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                if (result.books.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.compact),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final format in _FormatFilter.values)
                                ChoiceChip(
                                  label: Text(
                                    format == _FormatFilter.all
                                        ? l10n.searchAllFormats
                                        : format.name.toUpperCase(),
                                  ),
                                  selected: _format == format,
                                  onSelected: (_) =>
                                      setState(() => _format = format),
                                ),
                              PopupMenuButton<_SortOrder>(
                                initialValue: _sort,
                                tooltip: l10n.searchSort,
                                onSelected: (value) =>
                                    setState(() => _sort = value),
                                itemBuilder: (_) => [
                                  for (final sort in _SortOrder.values)
                                    CheckedPopupMenuItem(
                                      value: sort,
                                      checked: _sort == sort,
                                      child: Text(_sortLabel(l10n, sort)),
                                    ),
                                ],
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: AppLayout.minTouchTarget,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sort_rounded),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(_sortLabel(l10n, _sort)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.searchResultsCount(books.length),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: result.books.isEmpty
                          ? Icons.search_off_rounded
                          : Icons.filter_alt_off_outlined,
                      title: result.books.isEmpty
                          ? l10n.searchNoResults
                          : l10n.searchNoFilterResults,
                      action: result.books.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () => setState(() {
                                _format = _FormatFilter.all;
                                _sort = _SortOrder.relevance;
                              }),
                              child: Text(l10n.searchResetFilters),
                            ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.compact),
                    sliver: SliverGrid(
                      gridDelegate: ResponsiveGridDelegate(
                        minCrossAxisExtent:
                            MediaQuery.sizeOf(context).width >=
                                AppLayout.desktopBreakpoint
                            ? AppLayout.bookCardMinWidthDesktop
                            : AppLayout.bookCardMinWidth,
                        maxCrossAxisExtent: AppLayout.bookCardMaxWidth,
                        crossAxisSpacing: AppSpacing.compact,
                        mainAxisSpacing: AppSpacing.compact,
                        childAspectRatio:
                            AppLayout.bookCardAspectRatio /
                            (textScale < 1 ? 1 : textScale),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => SearchBookCard(book: books[index]),
                        childCount: books.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
  }

  Widget _failure(
    AppLocalizations l10n,
    String message,
    BookSearchQuery request,
  ) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.searchFailed,
          description: message,
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => ref.invalidate(bookSearchProvider(request)),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.searchRetry),
              ),
              if (widget.sourceId == null ||
                  widget.sourceId == DiscoverSourceIds.anna)
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const AnnaAccessScreen()),
                  ),
                  child: Text(l10n.annaSessionTitle),
                ),
              if (widget.sourceId == null ||
                  widget.sourceId == DiscoverSourceIds.zlibrary)
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const ZLibraryMirrorsScreen(),
                    ),
                  ),
                  child: Text(l10n.zLibraryMirrors),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
