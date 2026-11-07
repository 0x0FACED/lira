import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatters.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../bookmarks/domain/models/bookmark_dto.dart';
import '../../bookmarks/domain/providers/bookmarks_provider.dart';
import '../../books/domain/models/book_dto.dart';
import '../../highlights/domain/models/highlight_dto.dart';
import '../../highlights/domain/providers/highlights_provider.dart';
import '../domain/annotation_tools.dart';

enum _AnnotationsTab { highlights, bookmarks }

enum _ExportScope { all, visible, selected }

class ReaderAnnotationsPanel extends ConsumerStatefulWidget {
  const ReaderAnnotationsPanel({
    super.key,
    required this.book,
    required this.onNavigate,
  });

  final BookDto book;
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
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  String? _color;
  bool _hasNote = false;
  bool _exporting = false;
  String? _exportError;

  AnnotationFilter get _filter => AnnotationFilter(
    query: _searchController.text,
    color: _color,
    hasNote: _hasNote,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlights = ref.watch(highlightsControllerProvider(widget.book.id));
    final bookmarks = ref.watch(bookmarksControllerProvider(widget.book.id));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final count = _tab == _AnnotationsTab.highlights
        ? highlights.whenOrNull(data: (items) => items.length)
        : bookmarks.whenOrNull(data: (items) => items.length);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.pageGutter(context),
                  AppSpacing.md,
                  AppLayout.pageGutter(context),
                  AppSpacing.sm,
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
                      AppMetadata(label: '$count'),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.pageGutter(context),
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
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
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
                data: _buildHighlights,
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
                            (context, index) =>
                                _buildBookmarkTile(items[index]),
                            childCount: items.length,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights(List<HighlightDto> items) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          icon: Icons.highlight_outlined,
          title: l10n.highlightsEmpty,
          description: l10n.highlightsEmptyHint,
        ),
      );
    }
    final visible = _filter.apply(items);
    final colors =
        items.map((item) => item.color.toUpperCase()).toSet().toList()..sort();
    final selected = visible
        .where((item) => _selectedIds.contains(item.id))
        .length;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.pageGutter(context),
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('annotations-search'),
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.annotationsToolsSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilterChip(
                      label: Text(l10n.annotationsToolsHasNote),
                      selected: _hasNote,
                      onSelected: (value) => setState(() => _hasNote = value),
                    ),
                    for (final color in colors)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(
                              'FF${color.replaceFirst('#', '')}',
                              radix: 16,
                            ),
                          ),
                          radius: 7,
                        ),
                        label: Text(color),
                        selected: _color == color,
                        onSelected: (value) =>
                            setState(() => _color = value ? color : null),
                      ),
                    if (_filter.isActive)
                      TextButton(
                        onPressed: _clearFilters,
                        child: Text(l10n.annotationsToolsClearFilters),
                      ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${visible.length} / ${items.length}'),
                    TextButton(
                      onPressed: visible.isEmpty
                          ? null
                          : () {
                              setState(() {
                                if (selected == visible.length) {
                                  _selectedIds.removeAll(
                                    visible.map((item) => item.id),
                                  );
                                } else {
                                  _selectedIds.addAll(
                                    visible.map((item) => item.id),
                                  );
                                }
                              });
                            },
                      child: Text(
                        selected == visible.length && visible.isNotEmpty
                            ? l10n.annotationsToolsDeselectVisible
                            : l10n.annotationsToolsSelectVisible,
                      ),
                    ),
                    Text(l10n.annotationsToolsSelected('$selected')),
                    OutlinedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _chooseExport(items, visible),
                      icon: _exporting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(l10n.annotationsToolsExport),
                    ),
                  ],
                ),
                if (_exportError != null)
                  _AnnotationError(message: _exportError!),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.search_off,
              title: l10n.annotationsToolsNoMatches,
              description: l10n.annotationsToolsNoMatchesHint,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildHighlightTile(visible[index]),
              childCount: visible.length,
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.compact + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _color = null;
      _hasNote = false;
    });
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppLayout.pageGutter(context),
              vertical: AppSpacing.sm,
            ),
            title: Text(highlight.text, style: theme.textTheme.bodyMedium),
            subtitle: highlight.note != null
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      highlight.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
            onTap: deleting
                ? null
                : () => widget.onNavigate(highlight.location),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.pageGutter(context),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                SizedBox.square(
                  dimension: AppLayout.minTouchTarget,
                  child: Checkbox(
                    value: _selectedIds.contains(highlight.id),
                    semanticLabel: l10n.annotationsToolsSelectQuote,
                    onChanged: deleting
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(highlight.id);
                              } else {
                                _selectedIds.remove(highlight.id);
                              }
                            });
                          },
                  ),
                ),
                ExcludeSemantics(
                  child: CircleAvatar(backgroundColor: color, radius: 7),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: AppLayout.minTouchTarget,
                    height: AppLayout.minTouchTarget,
                  ),
                  icon: Semantics(
                    label: l10n.annotationsToolsCopyQuote,
                    child: const Icon(Icons.copy_outlined, size: 20),
                  ),
                  onPressed: () => _copyQuote(highlight),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: AppLayout.minTouchTarget,
                    height: AppLayout.minTouchTarget,
                  ),
                  icon: Semantics(
                    label: highlight.note != null
                        ? l10n.editNote
                        : l10n.addNote,
                    child: Icon(
                      highlight.note != null
                          ? Icons.edit_note
                          : Icons.note_add_outlined,
                      size: 20,
                    ),
                  ),
                  onPressed: deleting ? null : () => _editNote(highlight),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: AppLayout.minTouchTarget,
                    height: AppLayout.minTouchTarget,
                  ),
                  icon: Semantics(
                    label: l10n.delete,
                    child: deleting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 20),
                  ),
                  onPressed: deleting
                      ? null
                      : () => _deleteHighlight(highlight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkTile(BookmarkDto bookmark) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deleting = _deletingBookmarks.contains(bookmark.id);
    final percentage = formatReadingPercentage(
      bookmark.percentage,
      l10n.localeName,
    );

    return _AnnotationRow(
      key: ValueKey(bookmark.id),
      error: _bookmarkDeleteErrors[bookmark.id],
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppLayout.pageGutter(context),
          vertical: AppSpacing.sm,
        ),
        leading: Icon(
          Icons.bookmark_border,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(l10n.bookmarkPosition(percentage)),
        trailing: IconButton(
          icon: Semantics(
            label: l10n.removeBookmark,
            child: deleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, size: 20),
          ),
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
          .read(highlightsControllerProvider(widget.book.id).notifier)
          .removeHighlight(highlight.id);
      if (mounted) setState(() => _selectedIds.remove(highlight.id));
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
          .read(bookmarksControllerProvider(widget.book.id).notifier)
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
      highlightsControllerProvider(widget.book.id).notifier,
    );
    showAppDialog<void>(
      context: context,
      builder: (_) => _HighlightNoteDialog(
        initialNote: highlight.note,
        onSave: (note) => controller.updateNote(highlight.id, note),
      ),
    );
  }

  Future<void> _copyQuote(HighlightDto highlight) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(
        ClipboardData(text: attributedQuote(highlight.text, widget.book)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.copied)));
    } catch (error) {
      if (mounted) {
        setState(() => _exportError = l10n.annotationsToolsCopyError('$error'));
      }
    }
  }

  Future<void> _chooseExport(
    List<HighlightDto> all,
    List<HighlightDto> visible,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = visible
        .where((item) => _selectedIds.contains(item.id))
        .toList();
    var scope = selected.isEmpty ? _ExportScope.visible : _ExportScope.selected;
    var format = AnnotationExportFormat.markdown;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final count = switch (scope) {
            _ExportScope.all => all.length,
            _ExportScope.visible => visible.length,
            _ExportScope.selected => selected.length,
          };
          return AlertDialog(
            title: Text(l10n.annotationsToolsExport),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<_ExportScope>(
                  initialValue: scope,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.annotationsToolsExportScope,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _ExportScope.all,
                      child: Text(
                        l10n.annotationsToolsAllSaved('${all.length}'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: _ExportScope.visible,
                      child: Text(
                        l10n.annotationsToolsVisible('${visible.length}'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: _ExportScope.selected,
                      child: Text(
                        l10n.annotationsToolsSelectedVisible(
                          '${selected.length}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => scope = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<AnnotationExportFormat>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(
                      value: AnnotationExportFormat.markdown,
                      label: Text('Markdown'),
                    ),
                    ButtonSegment(
                      value: AnnotationExportFormat.text,
                      label: Text(l10n.annotationsToolsPlainText),
                    ),
                  ],
                  selected: {format},
                  onSelectionChanged: (value) =>
                      update(() => format = value.single),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: count == 0
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(l10n.annotationsToolsExport),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final items = switch (scope) {
      _ExportScope.all => all,
      _ExportScope.visible => visible,
      _ExportScope.selected => selected,
    };
    await _saveExport(items, format);
  }

  Future<void> _saveExport(
    List<HighlightDto> items,
    AnnotationExportFormat format,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final renderBox = context.findRenderObject();
    final shareOrigin = renderBox is RenderBox && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    Directory? temporary;
    try {
      final now = DateTime.now();
      final text = exportAnnotations(
        book: widget.book,
        annotations: items,
        format: format,
        exportedAt: now,
        labels: AnnotationExportLabels(
          title: l10n.annotationsToolsSourceTitle,
          author: l10n.annotationsToolsSourceAuthor,
          format: l10n.annotationsToolsSourceFormat,
          bookId: l10n.annotationsToolsSourceId,
          sourceAdded: l10n.annotationsToolsSourceAdded,
          exported: l10n.annotationsToolsExportedAt,
          annotations: l10n.highlights,
          note: l10n.annotationsToolsNote,
          color: l10n.annotationsToolsColor,
          created: l10n.annotationsToolsCreatedAt,
          chapter: l10n.annotationsToolsChapter,
          page: l10n.annotationsToolsPage,
        ),
      );
      final extension = format == AnnotationExportFormat.markdown
          ? 'md'
          : 'txt';
      final mime = format == AnnotationExportFormat.markdown
          ? 'text/markdown'
          : 'text/plain';
      final title = widget.book.title
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
          .trim();
      final safeTitle = title.isEmpty ? 'annotations' : title;
      final filename =
          '$safeTitle-annotations-${now.millisecondsSinceEpoch}.$extension';
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(text)),
        name: filename,
        mimeType: mime,
      );
      if (Platform.isAndroid || Platform.isIOS) {
        temporary = await (await getTemporaryDirectory()).createTemp(
          'lira-annotations-',
        );
        final path = p.join(temporary.path, filename);
        await file.saveTo(path);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: mime)],
            sharePositionOrigin: shareOrigin,
          ),
        );
      } else {
        final location = await getSaveLocation(
          suggestedName: filename,
          acceptedTypeGroups: [
            XTypeGroup(
              label: extension.toUpperCase(),
              extensions: [extension],
              mimeTypes: [mime],
              uniformTypeIdentifiers: ['public.plain-text'],
            ),
          ],
        );
        if (location == null) return;
        await file.saveTo(location.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.annotationsToolsSaved(location.path))),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _exportError = l10n.annotationsToolsExportError('$error'),
        );
      }
    } finally {
      if (temporary != null) {
        try {
          await temporary.delete(recursive: true);
        } on FileSystemException {
          // The OS also reclaims temporary files if a share extension holds one.
        }
      }
      if (mounted) setState(() => _exporting = false);
    }
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
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.pageGutter(context),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.compact),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
