import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../bookmarks/domain/models/bookmark_dto.dart';
import '../../bookmarks/domain/providers/bookmarks_provider.dart';
import '../../highlights/domain/models/highlight_dto.dart';
import '../../highlights/domain/providers/highlights_provider.dart';

enum _AnnotationsTab { highlights, bookmarks }

class ReaderAnnotationsPanel extends ConsumerStatefulWidget {
  const ReaderAnnotationsPanel({
    super.key,
    required this.bookId,
    required this.onNavigate,
  });

  final String bookId;
  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<ReaderAnnotationsPanel> createState() =>
      _ReaderAnnotationsPanelState();
}

class _ReaderAnnotationsPanelState
    extends ConsumerState<ReaderAnnotationsPanel> {
  _AnnotationsTab _tab = _AnnotationsTab.highlights;
  final _deletingHighlights = <String>{};
  final _deletingBookmarks = <String>{};
  final _highlightDeleteErrors = <String, String>{};
  final _bookmarkDeleteErrors = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final highlights = ref.watch(highlightsControllerProvider(widget.bookId));
    final bookmarks = ref.watch(bookmarksControllerProvider(widget.bookId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final count = _tab == _AnnotationsTab.highlights
        ? highlights.whenOrNull(data: (items) => items.length)
        : bookmarks.whenOrNull(data: (items) => items.length);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.annotations,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(label: '$count'),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact,
                vertical: AppSpacing.sm,
              ),
              child: SegmentedButton<_AnnotationsTab>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _AnnotationsTab.highlights,
                    label: Text(l10n.highlights),
                  ),
                  ButtonSegment(
                    value: _AnnotationsTab.bookmarks,
                    label: Text(l10n.bookmarks),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) {
                  setState(() {
                    _tab = selection.single;
                  });
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider()),
          if (_tab == _AnnotationsTab.highlights)
            highlights.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: AppEmptyState(
                  icon: Icons.error_outline,
                  title: l10n.highlightsLoadError,
                  description: '$error',
                  iconColor: theme.colorScheme.error,
                ),
              ),
              data: (items) => items.isEmpty
                  ? SliverToBoxAdapter(
                      child: AppEmptyState(
                        icon: Icons.highlight_outlined,
                        title: l10n.highlightsEmpty,
                        description: l10n.highlightsEmptyHint,
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.only(
                        bottom:
                            AppSpacing.compact +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildHighlightTile(items[index]),
                          childCount: items.length,
                        ),
                      ),
                    ),
            )
          else
            bookmarks.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: AppEmptyState(
                  icon: Icons.error_outline,
                  title: l10n.bookmarksLoadError,
                  description: '$error',
                  iconColor: theme.colorScheme.error,
                ),
              ),
              data: (items) => items.isEmpty
                  ? SliverToBoxAdapter(
                      child: AppEmptyState(
                        icon: Icons.bookmark_border,
                        title: l10n.bookmarksEmpty,
                        description: l10n.bookmarksEmptyHint,
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.only(
                        bottom:
                            AppSpacing.compact +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildBookmarkTile(items[index]),
                          childCount: items.length,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightTile(HighlightDto highlight) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deleting = _deletingHighlights.contains(highlight.id);
    final color = Color(
      int.parse('FF${highlight.color.replaceFirst('#', '')}', radix: 16),
    );

    return _AnnotationRow(
      key: ValueKey(highlight.id),
      error: _highlightDeleteErrors[highlight.id],
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: AppSpacing.xs,
          height: AppSpacing.xxl,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        title: Text(
          highlight.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: highlight.note != null
            ? Text(
                highlight.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: highlight.note != null ? l10n.editNote : l10n.addNote,
              icon: Icon(
                highlight.note != null
                    ? Icons.edit_note
                    : Icons.note_add_outlined,
                size: 20,
              ),
              onPressed: deleting ? null : () => _editNote(highlight),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: deleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, size: 20),
              onPressed: deleting ? null : () => _deleteHighlight(highlight),
            ),
          ],
        ),
        onTap: deleting ? null : () => widget.onNavigate(highlight.location),
      ),
    );
  }

  Widget _buildBookmarkTile(BookmarkDto bookmark) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deleting = _deletingBookmarks.contains(bookmark.id);
    final percentage = NumberFormat(
      '0.#',
      l10n.localeName,
    ).format(bookmark.percentage);

    return _AnnotationRow(
      key: ValueKey(bookmark.id),
      error: _bookmarkDeleteErrors[bookmark.id],
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.xs,
        ),
        leading: Icon(Icons.bookmark, color: theme.colorScheme.primary),
        title: Text(l10n.bookmarkPosition(percentage)),
        trailing: IconButton(
          tooltip: l10n.removeBookmark,
          icon: deleting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline, size: 20),
          onPressed: deleting ? null : () => _deleteBookmark(bookmark),
        ),
        onTap: deleting ? null : () => widget.onNavigate(bookmark.location),
      ),
    );
  }

  Future<void> _deleteHighlight(HighlightDto highlight) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _deletingHighlights.add(highlight.id);
      _highlightDeleteErrors.remove(highlight.id);
    });
    try {
      await ref
          .read(highlightsControllerProvider(widget.bookId).notifier)
          .removeHighlight(highlight.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _highlightDeleteErrors[highlight.id] = l10n.highlightDeleteError(
            '$error',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _deletingHighlights.remove(highlight.id));
      }
    }
  }

  Future<void> _deleteBookmark(BookmarkDto bookmark) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _deletingBookmarks.add(bookmark.id);
      _bookmarkDeleteErrors.remove(bookmark.id);
    });
    try {
      await ref
          .read(bookmarksControllerProvider(widget.bookId).notifier)
          .removeBookmark(bookmark.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _bookmarkDeleteErrors[bookmark.id] = l10n.bookmarkDeleteError(
            '$error',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _deletingBookmarks.remove(bookmark.id));
      }
    }
  }

  void _editNote(HighlightDto highlight) {
    final controller = ref.read(
      highlightsControllerProvider(widget.bookId).notifier,
    );
    showAppDialog<void>(
      context: context,
      builder: (_) => _HighlightNoteDialog(
        initialNote: highlight.note,
        onSave: (note) => controller.updateNote(highlight.id, note),
      ),
    );
  }
}

class _AnnotationRow extends StatelessWidget {
  const _AnnotationRow({super.key, required this.child, this.error});

  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact,
            vertical: AppSpacing.xs,
          ),
          child: _AnnotationError(message: error!),
        ),
    ],
  );
}

class _HighlightNoteDialog extends StatefulWidget {
  const _HighlightNoteDialog({required this.initialNote, required this.onSave});

  final String? initialNote;
  final Future<void> Function(String? note) onSave;

  @override
  State<_HighlightNoteDialog> createState() => _HighlightNoteDialogState();
}

class _HighlightNoteDialogState extends State<_HighlightNoteDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    // The dialog owns the controller until its route's closing animation ends.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.initialNote != null ? l10n.editNote : l10n.addNote),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              readOnly: _saving,
              decoration: InputDecoration(hintText: l10n.noteHint),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.compact),
              _AnnotationError(message: _error!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _controller.text.isNotEmpty ? _controller.text : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.noteSaveError('$error');
        });
      }
    }
  }
}

class _AnnotationError extends StatelessWidget {
  const _AnnotationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.compact),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colors.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
