import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/domain/models/reading_progress_dto.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/book_organization_provider.dart';
import '../domain/providers/books_provider.dart';
import '../domain/providers/library_layout_provider.dart';
import 'widgets/book_card.dart';
import 'widgets/responsive_grid_delegate.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

enum _Shelf { all, reading, unread, finished }

typedef _Label = ({bool genre, String key});

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _Shelf _shelf = _Shelf.all;
  _Label? _label;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final books = ref.watch(booksControllerProvider);
    final progress = ref.watch(libraryReadingProgressProvider);
    final organizations = ref.watch(bookOrganizationsProvider);
    final sort = ref.watch(librarySortProvider);
    final listView = ref.watch(libraryListViewProvider);
    final columns = ref.watch(libraryColumnsProvider);
    final media = MediaQuery.of(context);
    final isPhone =
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        media.size.shortestSide < 600;
    final wide = media.size.width >= AppLayout.desktopBreakpoint;
    final gutter = AppLayout.pageGutter(context);

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
                SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: l10n.library,
                    keepActionsInline: true,
                    actions: [
                      _layoutAction(l10n, isPhone, columns, listView),
                      IconButton(
                        icon: Semantics(
                          label: l10n.importBook,
                          child: const Icon(Icons.add),
                        ),
                        onPressed: () => _importBook(context),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      0,
                      gutter,
                      AppSpacing.sm,
                    ),
                    child: AppSearchField(
                      controller: _searchController,
                      hintText: l10n.searchLibrary,
                      onChanged: (value) =>
                          setState(() => _query = _fold(value.trim())),
                    ),
                  ),
                ),
                ...books.when(
                  data: (items) => _shelfSlivers(
                    context,
                    l10n,
                    items,
                    organizations,
                    progress,
                    sort,
                    gutter: gutter,
                    wide: wide,
                    columns: isPhone ? columns : null,
                    listView: listView,
                  ),
                  loading: () => [
                    _stateSliver(
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.compact),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                  error: (error, _) => [
                    _stateSliver(
                      AppEmptyState(
                        icon: Icons.error_outline,
                        iconColor: colors.error,
                        title: l10n.errorLoadingBook,
                        description: '$error',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _layoutAction(
    AppLocalizations l10n,
    bool isPhone,
    int columns,
    bool listView,
  ) {
    final view = ref.read(libraryListViewProvider.notifier);
    final icon = listView
        ? Icons.view_list_outlined
        : columns == 3 && isPhone
        ? Icons.view_module_outlined
        : Icons.grid_view_outlined;
    if (!isPhone) {
      return IconButton(
        icon: Semantics(
          label: listView ? l10n.libraryGridView : l10n.libraryListView,
          child: Icon(
            listView ? Icons.grid_view_outlined : Icons.view_list_outlined,
          ),
        ),
        onPressed: () => view.setListView(!listView),
      );
    }
    return PopupMenuButton<int>(
      tooltip: '',
      initialValue: listView ? 0 : columns,
      icon: Semantics(label: l10n.libraryLayout, child: Icon(icon)),
      onSelected: (value) async {
        final density = ref.read(libraryColumnsProvider.notifier);
        if (value != 0) await density.setColumns(value);
        await view.setListView(value == 0);
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 2,
          checked: !listView && columns == 2,
          child: Text(l10n.libraryTwoBooksPerRow),
        ),
        CheckedPopupMenuItem(
          value: 3,
          checked: !listView && columns == 3,
          child: Text(l10n.libraryThreeBooksPerRow),
        ),
        CheckedPopupMenuItem(
          value: 0,
          checked: listView,
          child: Text(l10n.libraryListView),
        ),
      ],
    );
  }

  Future<void> _importBook(BuildContext context) async {
    try {
      await ref.read(booksControllerProvider.notifier).importBook();
    } catch (error) {
      if (!context.mounted) return;
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error', style: TextStyle(color: colors.onError)),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  List<Widget> _shelfSlivers(
    BuildContext context,
    AppLocalizations l10n,
    List<BookDto> books,
    Map<String, BookOrganization> organizations,
    AsyncValue<Map<String, ReadingProgressDto>> progress,
    LibrarySort sort, {
    required double gutter,
    required bool wide,
    required int? columns,
    required bool listView,
  }) {
    if (books.isEmpty) {
      return [
        _stateSliver(
          AppEmptyState(
            icon: Icons.local_library_outlined,
            title: l10n.noBooks,
            description: l10n.noBooksHint,
          ),
        ),
      ];
    }
    final labels = <_Label, String>{};
    for (final book in books) {
      final organization = organizations[book.id];
      if (organization == null) continue;
      for (final value in organization.genres) {
        labels.putIfAbsent((
          genre: true,
          key: value.toLowerCase(),
        ), () => value);
      }
      for (final value in organization.tags) {
        labels.putIfAbsent((
          genre: false,
          key: value.toLowerCase(),
        ), () => value);
      }
    }
    final activeLabel = labels.containsKey(_label) ? _label : null;
    final savedProgress = progress.valueOrNull;
    final needsProgress =
        _shelf != _Shelf.all ||
        sort == LibrarySort.recent ||
        sort == LibrarySort.progress;
    final List<BookDto>? visible = needsProgress && savedProgress == null
        ? null
        : _visibleBooks(
            books,
            organizations,
            savedProgress ?? const {},
            activeLabel,
            sort,
          );

    return [
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              for (final shelf in _Shelf.values)
                ChoiceChip(
                  label: Text(_shelfTitle(shelf, l10n)),
                  selected: _shelf == shelf,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _shelf = shelf),
                ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AppSpacing.xs,
            gutter,
            AppSpacing.compact,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visible == null
                          ? ''
                          : l10n.libraryBookCount(visible.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    isSelected: activeLabel != null,
                    onPressed: () =>
                        _chooseLabel(context, l10n, labels, activeLabel),
                    icon: Semantics(
                      label: l10n.libraryLabels,
                      child: const Icon(Icons.filter_list_rounded),
                    ),
                    selectedIcon: Semantics(
                      label: l10n.libraryLabels,
                      child: const Icon(Icons.filter_alt),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _sortMenu(context, l10n, sort),
                ],
              ),
              if (activeLabel != null)
                InputChip(
                  avatar: Icon(
                    activeLabel.genre
                        ? Icons.bookmark_border
                        : Icons.label_outline,
                    size: 16,
                  ),
                  label: Text(
                    labels[activeLabel]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () => setState(() => _label = null),
                ),
            ],
          ),
        ),
      ),
      if (visible == null)
        _stateSliver(
          progress.hasError
              ? AppEmptyState(
                  icon: Icons.error_outline,
                  title: l10n.errorLoadingProgress,
                )
              : const CircularProgressIndicator(),
        )
      else if (visible.isEmpty)
        _stateSliver(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(
                icon: Icons.search_off_rounded,
                title: _query.isNotEmpty
                    ? l10n.searchNoResults
                    : l10n.libraryNoMatchingBooks,
              ),
              TextButton(
                onPressed: _clearFilters,
                child: Text(l10n.libraryClearFilters),
              ),
            ],
          ),
        )
      else
        _bookSliver(
          context,
          visible,
          savedProgress ?? const {},
          gutter,
          wide,
          columns,
          listView,
        ),
    ];
  }

  Widget _sortMenu(
    BuildContext context,
    AppLocalizations l10n,
    LibrarySort sort,
  ) {
    final theme = Theme.of(context);
    return PopupMenuButton<LibrarySort>(
      tooltip: '',
      initialValue: sort,
      onSelected: ref.read(librarySortProvider.notifier).setSort,
      itemBuilder: (_) => [
        for (final option in LibrarySort.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == sort,
            child: Text(_sortTitle(option, l10n)),
          ),
      ],
      child: Semantics(
        label: l10n.librarySortBy,
        value: _sortTitle(sort, l10n),
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: AppLayout.minTouchTarget,
            maxWidth: MediaQuery.sizeOf(context).width < 480 ? 196 : 248,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    _sortTitle(sort, l10n),
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseLabel(
    BuildContext context,
    AppLocalizations l10n,
    Map<_Label, String> labels,
    _Label? current,
  ) async {
    final ordered = labels.entries.toList()
      ..sort((a, b) => _fold(a.value).compareTo(_fold(b.value)));
    final picked = await showAppBottomSheet<(_Label?,)>(
      context: context,
      builder: (sheet) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.libraryLabels,
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              if (ordered.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.bookLabelsEmpty),
              ],
              for (final genre in [true, false])
                if (ordered.any((entry) => entry.key.genre == genre)) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    genre ? l10n.bookGenres : l10n.bookTags,
                    style: Theme.of(sheet).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final entry in ordered)
                        if (entry.key.genre == genre)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: entry.key == current,
                            onSelected: (selected) => Navigator.pop(sheet, (
                              selected ? entry.key : null,
                            )),
                          ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ),
    );
    if (mounted && picked != null) setState(() => _label = picked.$1);
  }

  List<BookDto> _visibleBooks(
    List<BookDto> books,
    Map<String, BookOrganization> organizations,
    Map<String, ReadingProgressDto> progress,
    _Label? label,
    LibrarySort sort,
  ) {
    final visible = <BookDto>[];
    for (final book in books) {
      final percentage = progress[book.id]?.percentage ?? 0;
      if (!switch (_shelf) {
        _Shelf.all => true,
        _Shelf.reading => percentage > 0 && percentage < 100,
        _Shelf.unread => percentage <= 0,
        _Shelf.finished => percentage >= 100,
      })
        continue;
      final organization = organizations[book.id];
      if (label != null && !_hasLabel(organization, label)) continue;
      if (_query.isNotEmpty &&
          !_fold(book.title).contains(_query) &&
          !_fold(book.author).contains(_query) &&
          !(organization?.genres.any(
                (value) => _fold(value).contains(_query),
              ) ??
              false) &&
          !(organization?.tags.any((value) => _fold(value).contains(_query)) ??
              false)) {
        continue;
      }
      visible.add(book);
    }
    final names = switch (sort) {
      LibrarySort.title => {
        for (final book in visible) book.id: _fold(book.title),
      },
      LibrarySort.author => {
        for (final book in visible) book.id: _authorSortKey(book.author),
      },
      _ => const <String, String>{},
    };
    visible.sort((a, b) {
      final primary = switch (sort) {
        LibrarySort.added => 0,
        LibrarySort.recent => _latestFirst(
          progress[a.id]?.updatedAt,
          progress[b.id]?.updatedAt,
        ),
        LibrarySort.progress => (progress[b.id]?.percentage ?? -1).compareTo(
          progress[a.id]?.percentage ?? -1,
        ),
        LibrarySort.title ||
        LibrarySort.author => _nameOrder(names[a.id]!, names[b.id]!),
      };
      if (primary != 0) return primary;
      final added = b.createdAt.compareTo(a.createdAt);
      return added != 0 ? added : a.id.compareTo(b.id);
    });
    return visible;
  }

  Widget _bookSliver(
    BuildContext context,
    List<BookDto> books,
    Map<String, ReadingProgressDto> progress,
    double gutter,
    bool wide,
    int? columns,
    bool listView,
  ) {
    final controller = ref.read(booksControllerProvider.notifier);
    final indices = {for (var i = 0; i < books.length; i++) books[i].id: i};
    final delegate = SliverChildBuilderDelegate(
      (context, index) {
        final book = books[index];
        return BookCard(
          key: ValueKey(book.id),
          book: book,
          compact: listView,
          readingPercentage: progress[book.id]?.percentage,
          onTap: () => context.push('/book-detail', extra: book),
          onDelete: () => controller.removeBook(book.id),
        );
      },
      childCount: books.length,
      findChildIndexCallback: (key) => indices[(key as ValueKey<String>).value],
    );
    const extraHit = 2 * BookCard.hitInset;
    Widget sliver;
    if (listView) {
      sliver = SliverList(delegate: delegate);
    } else {
      var maxPages = 0;
      for (final book in books) {
        if (book.pageCount > maxPages) maxPages = book.pageCount;
      }
      final pageCountDigits = maxPages.toString().length;
      final textScaler = MediaQuery.textScalerOf(context);
      sliver = SliverGrid(
        gridDelegate: ResponsiveGridDelegate(
          crossAxisCount: columns,
          minCrossAxisExtent:
              (wide
                  ? AppLayout.bookCardMinWidthDesktop
                  : AppLayout.bookCardMinWidth) +
              extraHit,
          maxCrossAxisExtent: AppLayout.bookCardMaxWidth + extraHit,
          crossAxisSpacing: (wide ? AppSpacing.lg : AppSpacing.md) - extraHit,
          mainAxisSpacing: (wide ? AppSpacing.xl : AppSpacing.lg) - extraHit,
          childAspectRatio: BookCard.coverAspectRatio,
          mainAxisExtraExtentForWidth: (width) =>
              BookCard.metadataExtent(
                textScaler,
                cardWidth: width - extraHit,
                pageCountDigits: pageCountDigits,
              ) +
              extraHit -
              extraHit / BookCard.coverAspectRatio,
        ),
        delegate: delegate,
      );
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        gutter - BookCard.hitInset,
        0,
        gutter - BookCard.hitInset,
        AppSpacing.xl,
      ),
      sliver: sliver,
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _shelf = _Shelf.all;
      _label = null;
    });
  }

  Widget _stateSliver(Widget child) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(child: AppStateTransition(child: child)),
  );
}

String _fold(String value) => value.toLowerCase().replaceAll('ё', 'е');

String _authorSortKey(String author) {
  final name = author.trim();
  return name == 'Unknown Author' ? '' : _fold(name);
}

bool _hasLabel(BookOrganization? organization, _Label label) =>
    (label.genre ? organization?.genres : organization?.tags)?.any(
      (value) => value.toLowerCase() == label.key,
    ) ??
    false;

int _latestFirst(DateTime? a, DateTime? b) => a == null
    ? (b == null ? 0 : 1)
    : b == null
    ? -1
    : b.compareTo(a);

int _nameOrder(String a, String b) => a.isEmpty
    ? (b.isEmpty ? 0 : 1)
    : b.isEmpty
    ? -1
    : a.compareTo(b);

String _shelfTitle(_Shelf shelf, AppLocalizations l10n) => switch (shelf) {
  _Shelf.all => l10n.libraryAllBooks,
  _Shelf.reading => l10n.libraryInProgress,
  _Shelf.unread => l10n.libraryUnread,
  _Shelf.finished => l10n.libraryFinished,
};

String _sortTitle(LibrarySort sort, AppLocalizations l10n) => switch (sort) {
  LibrarySort.added => l10n.librarySortAdded,
  LibrarySort.recent => l10n.librarySortRecent,
  LibrarySort.progress => l10n.librarySortProgress,
  LibrarySort.title => l10n.librarySortTitle,
  LibrarySort.author => l10n.librarySortAuthor,
};
