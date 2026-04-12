import 'dart:io';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/domain/models/book_dto.dart';
import '../../highlights/domain/models/highlight_dto.dart';
import '../../highlights/domain/providers/highlights_provider.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../../settings/presentation/settings_panel.dart';
import '../domain/engine/book_reader_engine.dart';
import '../domain/engine/epub_book_reader_engine.dart';
import '../domain/engine/pdf_book_reader_engine.dart';
import '../domain/models/book_location.dart';

const _highlightColors = [
  '#BB86FC',
  '#FFEB3B',
  '#4CAF50',
  '#42A5F5',
  '#EF5350',
];

class ReaderScreen extends ConsumerStatefulWidget {
  final BookDto book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late Future<BookReaderEngine> _engineFuture;
  BookReaderEngine? _engine;
  bool _showUi = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<_ReaderProgressState> _progressNotifier = ValueNotifier(
    const _ReaderProgressState(fraction: 0, label: ''),
  );
  bool _didSeedProgressFromStorage = false;

  String? _selectedText;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _engineFuture = _initEngine();
  }

  Future<BookReaderEngine> _initEngine() async {
    BookReaderEngine engine;

    if (widget.book.format == 'epub') {
      engine = EpubBookReaderEngine();
    } else if (widget.book.format == 'pdf') {
      engine = PdfBookReaderEngine();
    } else {
      throw UnsupportedError('Format ${widget.book.format} is not supported');
    }

    final file = File(widget.book.fileUrl!);
    final bytes = await file.readAsBytes();
    await engine.loadBook(bytes);

    _engine = engine;
    return engine;
  }

  @override
  void dispose() {
    _engine?.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressAsyncValue = ref.watch(
      readingProgressControllerProvider(widget.book.id),
    );
    final settings = ref.watch(readerSettingsProvider);
    final highlightsAsync = ref.watch(
      highlightsControllerProvider(widget.book.id),
    );

    return FutureBuilder<BookReaderEngine>(
      future: _engineFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final engine = snapshot.data;
        if (engine == null) {
          return const Scaffold(
            body: Center(child: Text('Failed to initialize reader engine.')),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: _buildTocDrawer(engine),
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Color(settings.backgroundColor),
                  child: progressAsyncValue.when(
                    data: (progress) {
                      _seedProgressIndicator(progress?.percentage);
                      return engine.buildReaderWidget(
                        context: context,
                        settings: settings,
                        theme: Theme.of(context),
                        initialLocation: progress != null
                            ? BookLocation(locator: progress.location)
                            : const BookLocation(locator: ''),
                        onCenterTapped: _toggleUi,
                        highlights: _buildHighlightsData(highlightsAsync),
                        onProgressChanged: (location, percentage) {
                          _progressNotifier.value =
                              _progressStateFromPercentage(percentage);
                          ref
                              .read(
                                readingProgressControllerProvider(
                                  widget.book.id,
                                ).notifier,
                              )
                              .saveProgress(
                                location: location.locator,
                                percentage: percentage,
                              );
                        },
                        onTextSelected: (text, location) {
                          if (text.trim().isEmpty || location.locator.isEmpty) {
                            setState(() {
                              _selectedText = null;
                              _selectedLocation = null;
                            });
                            return;
                          }

                          setState(() {
                            _selectedText = text;
                            _selectedLocation = location.locator;
                          });
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) =>
                        const Center(child: Text('Error loading progress')),
                  ),
                ),
              ),
              if (settings.brightness < 1.0 && widget.book.format != 'epub')
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withAlpha(
                        ((1.0 - settings.brightness) * 200).round(),
                      ),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                top: _showUi ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black87,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.book.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                bottom: _showUi ? 0 : -120,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black87,
                  child: SafeArea(
                    top: false,
                    child: ValueListenableBuilder<_ReaderProgressState>(
                      valueListenable: _progressNotifier,
                      builder: (context, progressState, _) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 8,
                            bottom: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressState.fraction,
                                        backgroundColor: Colors.white24,
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      progressState.label,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                alignment: WrapAlignment.spaceEvenly,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 20,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.format_list_bulleted,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Table of Contents',
                                    onPressed: () =>
                                        _scaffoldKey.currentState?.openDrawer(),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.bookmark_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Highlights',
                                    onPressed: () =>
                                        _showHighlightsPanel(context),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Settings',
                                    onPressed: () => _showSettings(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                right: _selectedText != null ? 12 : -60,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height - 32,
                      ),
                      child: _buildSelectionBar(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _buildHighlightsData(
    AsyncValue<List<HighlightDto>> highlightsAsync,
  ) {
    final highlights = highlightsAsync.valueOrNull ?? [];
    final result = <Map<String, dynamic>>[];
    for (final h in highlights) {
      final cfi = EpubCfi.fromJson(h.location);
      if (cfi == null || !cfi.hasRange) continue;
      result.add({
        'highlightId': h.id,
        'chapterIndex': cfi.spineIndex,
        'startOffset': cfi.startOffset!,
        'endOffset': cfi.endOffset!,
        'color': h.color,
      });
    }
    return result;
  }

  void _seedProgressIndicator(double? percentage) {
    if (_didSeedProgressFromStorage) return;
    _progressNotifier.value = _progressStateFromPercentage(percentage);
    _didSeedProgressFromStorage = true;
  }

  _ReaderProgressState _progressStateFromPercentage(double? percentage) {
    final value = (percentage ?? 0).clamp(0.0, 100.0).toDouble();
    return _ReaderProgressState(
      fraction: value / 100,
      label: '${value.toStringAsFixed(1)}%',
    );
  }

  Widget _buildSelectionBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        width: 44,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in _highlightColors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () => _saveHighlight(color),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              _miniButton(Icons.note_add, _addNote),
              const SizedBox(height: 6),
              _miniButton(Icons.copy, _copySelection),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  void _saveHighlight(String color) {
    if (_selectedText == null || _selectedLocation == null) return;
    ref
        .read(highlightsControllerProvider(widget.book.id).notifier)
        .addHighlight(
          text: _selectedText!,
          location: _selectedLocation!,
          color: color,
        );
    setState(() {
      _selectedText = null;
      _selectedLocation = null;
    });
  }

  void _addNote() {
    if (_selectedText == null || _selectedLocation == null) return;
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${_selectedText!.length > 100 ? '${_selectedText!.substring(0, 100)}...' : _selectedText!}"',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Your note...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(highlightsControllerProvider(widget.book.id).notifier)
                  .addHighlight(
                    text: _selectedText!,
                    location: _selectedLocation!,
                    note: noteController.text.isNotEmpty
                        ? noteController.text
                        : null,
                  );
              Navigator.pop(ctx);
              setState(() {
                _selectedText = null;
                _selectedLocation = null;
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _copySelection() {
    if (_selectedText != null) {
      Clipboard.setData(ClipboardData(text: _selectedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
      );
    }
    setState(() {
      _selectedText = null;
      _selectedLocation = null;
    });
  }

  Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _showHighlightsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HighlightsPanel(
        bookId: widget.book.id,
        onNavigate: (location) {
          _engine?.goToLocation(BookLocation(locator: location));
          Navigator.pop(ctx);
          if (_showUi) _toggleUi();
        },
      ),
    );
  }

  Drawer _buildTocDrawer(BookReaderEngine engine) {
    final toc = engine.getToc();

    if (toc.isEmpty) {
      return Drawer(
        child: Center(
          child: Text(
            'Table of Contents is not available.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Contents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: toc.length,
                itemBuilder: (context, index) {
                  return _buildTocItem(toc[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTocItem(TOCItem item, {int depth = 0}) {
    final padding = 16.0 + (depth * 16.0);

    if (item.subItems.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: padding),
        title: Text(item.title),
        onTap: () {
          _engine?.goToLocation(BookLocation(locator: item.fileName));
          Navigator.pop(context);
          if (_showUi) _toggleUi();
        },
      );
    }

    return _ExpandableTocItem(
      item: item,
      padding: padding,
      depth: depth,
      onNavigate: (fileName) {
        _engine?.goToLocation(BookLocation(locator: fileName));
        Navigator.pop(context);
        if (_showUi) _toggleUi();
      },
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettingsPanel(),
    );
  }
}

class _ReaderProgressState {
  final double fraction;
  final String label;

  const _ReaderProgressState({required this.fraction, required this.label});
}

class _ExpandableTocItem extends StatefulWidget {
  final TOCItem item;
  final double padding;
  final int depth;
  final void Function(String fileName) onNavigate;

  const _ExpandableTocItem({
    required this.item,
    required this.padding,
    required this.depth,
    required this.onNavigate,
  });

  @override
  State<_ExpandableTocItem> createState() => _ExpandableTocItemState();
}

class _ExpandableTocItemState extends State<_ExpandableTocItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: widget.padding),
          leading: IconButton(
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
          title: Text(widget.item.title),
          onTap: () => widget.onNavigate(widget.item.fileName),
        ),
        if (_expanded) ..._buildSubItems(widget.item.subItems),
      ],
    );
  }

  List<Widget> _buildSubItems(List<TOCItem> items) {
    return items.map((item) {
      if (item.subItems.isEmpty) {
        return ListTile(
          contentPadding: EdgeInsets.only(left: widget.padding + 16),
          title: Text(item.title),
          onTap: () => widget.onNavigate(item.fileName),
        );
      }

      return _ExpandableTocItem(
        item: item,
        padding: widget.padding + 16,
        depth: widget.depth + 1,
        onNavigate: widget.onNavigate,
      );
    }).toList();
  }
}

class _HighlightsPanel extends ConsumerWidget {
  final String bookId;
  final void Function(String location) onNavigate;

  const _HighlightsPanel({required this.bookId, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(highlightsControllerProvider(bookId));
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Highlights', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    highlightsAsync.whenOrNull(
                          data: (list) => Text(
                            '${list.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ) ??
                        const SizedBox.shrink(),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: highlightsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (highlights) {
                    if (highlights.isEmpty) {
                      return Center(
                        child: Text(
                          'No highlights yet.\nSelect text in the book to highlight it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(100),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: highlights.length,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemBuilder: (ctx, i) => _buildHighlightTile(
                        context,
                        ref,
                        highlights[i],
                        theme,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighlightTile(
    BuildContext context,
    WidgetRef ref,
    HighlightDto highlight,
    ThemeData theme,
  ) {
    final color = _parseHex(highlight.color);
    return Dismissible(
      key: Key(highlight.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withAlpha(40),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) {
        ref
            .read(highlightsControllerProvider(bookId).notifier)
            .removeHighlight(highlight.id);
      },
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          highlight.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: highlight.note != null
            ? Text(
                highlight.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(
            highlight.note != null ? Icons.edit_note : Icons.note_add_outlined,
            size: 18,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
          onPressed: () => _editNote(context, ref, highlight),
        ),
        onTap: () => onNavigate(highlight.location),
      ),
    );
  }

  void _editNote(BuildContext context, WidgetRef ref, HighlightDto highlight) {
    final controller = TextEditingController(text: highlight.note ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Your note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(highlightsControllerProvider(bookId).notifier)
                  .updateNote(
                    highlight.id,
                    controller.text.isNotEmpty ? controller.text : null,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
