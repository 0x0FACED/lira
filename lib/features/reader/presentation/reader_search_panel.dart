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
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: math.max(
            0,
            math.min(620, media.size.height * .78 - media.viewInsets.bottom),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
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
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                AppSearchField(
                  controller: textController,
                  autofocus: true,
                  hintText: l10n.readerSearchHint,
                  onChanged: search.updateQuery,
                  onSubmitted: (_) => onSubmit(),
                  onSearch: onSubmit,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListenableBuilder(
                    listenable: search,
                    builder: (context, _) => _buildResults(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (search.isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.compact),
            Text(l10n.readerSearching),
          ],
        ),
      );
    }
    if (search.error != null) {
      return SingleChildScrollView(
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
      return SingleChildScrollView(
        child: AppEmptyState(
          icon: Icons.manage_search,
          title: l10n.readerSearchPrompt,
        ),
      );
    }
    if (search.matches.isEmpty) {
      return SingleChildScrollView(
        child: AppEmptyState(
          icon: Icons.search_off,
          title: l10n.readerSearchNoResults,
          description: !search.hasText && isPdf
              ? l10n.readerSearchNoPdfText
              : l10n.readerSearchNoResultsHint,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              l10n.readerSearchCount(search.matches.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: search.matches.length,
            itemBuilder: (context, index) {
              final match = search.matches[index];
              return ListTile(
                selected: search.activeIndex == index,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                title: Text(
                  _sectionLabel(l10n, match),
                  style: Theme.of(context).textTheme.labelMedium,
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
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
            },
          ),
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
              tooltip: l10n.readerSearchPrevious,
              onPressed: canMove ? () => onMove(-1) : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: l10n.readerSearchNext,
              onPressed: canMove ? () => onMove(1) : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: l10n.readerSearchFinish,
              onPressed: onFinish,
              icon: const Icon(Icons.close),
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
                style: Theme.of(context).textTheme.labelMedium,
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
