import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/book_search.dart';
import 'reader_search_controller.dart';

class ReaderSearchPanel extends StatelessWidget {
  const ReaderSearchPanel({
    super.key,
    required this.search,
    required this.textController,
    required this.isPdf,
    required this.onSelect,
    required this.onSubmit,
    required this.onClose,
  });

  final ReaderSearchController search;
  final TextEditingController textController;
  final bool isPdf;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final gutter = AppLayout.pageGutter(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: math.min(
            620,
            math.max(0, media.size.height - media.viewInsets.bottom) * .78,
          ),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.readerSearch,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: Semantics(
                              label: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              child: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppSearchField(
                        controller: textController,
                        autofocus: true,
                        hintText: l10n.readerSearchHint,
                        onChanged: search.updateQuery,
                        onSubmitted: (_) => onSubmit(),
                        onSearch: onSubmit,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                sliver: ListenableBuilder(
                  listenable: search,
                  builder: (context, _) => _buildResults(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (search.isSearching) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.compact),
                Text(l10n.readerSearching),
              ],
            ),
          ),
        ),
      );
    }
    if (search.error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.search_off,
          title: l10n.readerSearchError,
          action: FilledButton(
            onPressed: search.searchNow,
            child: Text(l10n.readerSearchRetry),
          ),
        ),
      );
    }
    if (!search.hasSearched) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.manage_search,
          title: l10n.readerSearchPrompt,
        ),
      );
    }
    if (search.matches.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.search_off,
          title: l10n.readerSearchNoResults,
          description: !search.hasText && isPdf
              ? l10n.readerSearchNoPdfText
              : l10n.readerSearchNoResultsHint,
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                l10n.readerSearchCount(search.matches.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final match = search.matches[index];
            return ListTile(
              selected: search.activeIndex == index,
              selectedTileColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              title: Text(
                _sectionLabel(l10n, match),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: search.activeIndex == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: match.excerpt.before),
                      TextSpan(
                        text: match.excerpt.text,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: match.excerpt.after),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              onTap: () => onSelect(index),
            );
          }, childCount: search.matches.length),
        ),
      ],
    );
  }

  String _sectionLabel(AppLocalizations l10n, BookSearchMatch match) {
    if (match.pageNumber != null)
      return l10n.readerSearchPage(match.pageNumber!);
    final title = match.sectionTitle;
    return title != null && title.trim().isNotEmpty
        ? title
        : l10n.readerSearchChapter(match.sectionIndex + 1);
  }
}

class ReaderSearchNavigation extends StatelessWidget {
  const ReaderSearchNavigation({
    super.key,
    required this.search,
    required this.canReturn,
    required this.onOpen,
    required this.onMove,
    required this.onReturn,
    required this.onFinish,
  });

  final ReaderSearchController search;
  final bool canReturn;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final VoidCallback onReturn;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canMove = !search.isSearching && search.matches.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.search, size: 20),
                label: Text(
                  search.query.isEmpty ? l10n.readerSearch : search.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              onPressed: canMove ? () => onMove(-1) : null,
              icon: Semantics(
                label: l10n.readerSearchPrevious,
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            ),
            IconButton(
              onPressed: canMove ? () => onMove(1) : null,
              icon: Semantics(
                label: l10n.readerSearchNext,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
            IconButton(
              onPressed: onFinish,
              icon: Semantics(
                label: l10n.readerSearchFinish,
                child: const Icon(Icons.close),
              ),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.compact,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                search.isSearching
                    ? l10n.readerSearching
                    : l10n.readerSearchPosition(
                        search.activeIndex + 1,
                        search.matches.length,
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (canReturn)
              TextButton.icon(
                onPressed: onReturn,
                icon: const Icon(Icons.undo, size: 18),
                label: Text(l10n.readerSearchReturn),
              ),
          ],
        ),
      ],
    );
  }
}
