import 'dart:async';
import 'dart:io';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/domain/models/book_dto.dart';
import '../../bookmarks/domain/models/bookmark_dto.dart';
import '../../bookmarks/domain/providers/bookmarks_provider.dart';
import '../../highlights/domain/models/highlight_dto.dart';
import '../../highlights/domain/providers/highlights_provider.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../../settings/presentation/settings_panel.dart';
import '../domain/engine/book_reader_engine.dart';
import '../domain/engine/epub_book_reader_engine.dart';
import '../domain/engine/pdf_book_reader_engine.dart';
import '../domain/models/book_location.dart';
import 'reader_annotations_panel.dart';

const _highlightColors = [
  // Reader annotations are content colors, independent of the app chrome.
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

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  late Future<BookReaderEngine> _engineFuture;
  BookReaderEngine? _engine;
  bool _showUi = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<_ReaderProgressState> _progressNotifier = ValueNotifier(
    const _ReaderProgressState(fraction: 0, label: ''),
  );
  bool _didSeedProgressFromStorage = false;
  BookLocation? _initialLocation;
  late ReadingProgressController _progressController;
  int _loadGeneration = 0;
  int? _closingGeneration;
  int? _highlightWriteGeneration;
  int? _bookmarkWriteGeneration;
  List<HighlightDto>? _mappedHighlights;
  List<Map<String, dynamic>> _highlightData = const [];

  String? _selectedText;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startBook();
  }

  void _startBook() {
    _bookmarkWriteGeneration = null;
    _mappedHighlights = null;
    _highlightData = const [];
    _progressController = ref.read(
      readingProgressControllerProvider(widget.book.id).notifier,
    );
    _engineFuture = _initEngine(++_loadGeneration);
  }

  @override
  void didUpdateWidget(covariant ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.fileUrl != widget.book.fileUrl ||
        oldWidget.book.format != widget.book.format) {
      _flushProgressInBackground();
      _engine?.dispose();
      _engine = null;
      _initialLocation = null;
      _didSeedProgressFromStorage = false;
      _selectedText = null;
      _selectedLocation = null;
      _showUi = false;
      _startBook();
    }
  }

  Future<BookReaderEngine> _initEngine(int generation) async {
    final book = widget.book;
    final BookReaderEngine engine;
    if (book.format == 'epub') {
      engine = EpubBookReaderEngine();
    } else if (book.format == 'pdf') {
      engine = PdfBookReaderEngine();
    } else {
      throw UnsupportedError('Format ${book.format} is not supported');
    }

    try {
      final bytes = await File(book.fileUrl!).readAsBytes();
      await engine.loadBook(bytes);
      if (!mounted || generation != _loadGeneration) {
        engine.dispose();
        return engine;
      }
      _engine = engine;
      return engine;
    } catch (_) {
      engine.dispose();
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flushProgressInBackground();
  }

  void _flushProgressInBackground() {
    unawaited(
      _progressController.flush().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'Lira reader',
            context: ErrorDescription('while saving the reading position'),
          ),
        );
      }),
    );
  }

  Future<void> _closeReader() async {
    final generation = _loadGeneration;
    if (_closingGeneration == generation) return;
    _closingGeneration = generation;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    try {
      await _progressController.flush();
      if (mounted &&
          generation == _loadGeneration &&
          route?.isCurrent == true) {
        await navigator.maybePop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.readerSavePositionError('$error'),
            ),
          ),
        );
      }
    } finally {
      if (_closingGeneration == generation) _closingGeneration = null;
    }
  }

  @override
  void dispose() {
    ++_loadGeneration;
    WidgetsBinding.instance.removeObserver(this);
    _flushProgressInBackground();
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final progressAsyncValue = ref.watch(
      readingProgressControllerProvider(widget.book.id),
    );
    final settings = ref.watch(readerSettingsProvider);
    final highlightsAsync = ref.watch(
      highlightsControllerProvider(widget.book.id),
    );
    final bookmarksAsync = ref.watch(
      bookmarksControllerProvider(widget.book.id),
    );
    ref.listen(readingProgressControllerProvider(widget.book.id), (_, next) {
      if (next.hasError && _initialLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.readerSavePositionError('${next.error}')),
            ),
          );
        });
      }
    });

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
            body: AppEmptyState(
              icon: Icons.error_outline,
              title: l10n.errorLoadingBook,
              description: '${snapshot.error}',
              iconColor: colors.error,
            ),
          );
        }

        final engine = snapshot.data;
        if (engine == null) {
          return Scaffold(
            body: AppEmptyState(
              icon: Icons.menu_book_outlined,
              title: l10n.failedToInitReader,
              iconColor: colors.error,
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          // The note dialog handles the keyboard; keep the book's pagination
          // and scroll viewport unchanged behind all annotation editors.
          resizeToAvoidBottomInset: false,
          drawer: _buildTocDrawer(engine),
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Color(settings.backgroundColor),
                  child: _initialLocation != null
                      ? _buildReaderWidget(engine, settings, highlightsAsync)
                      : progressAsyncValue.when(
                          skipError: true,
                          data: (progress) {
                            _initialLocation = BookLocation(
                              locator: progress?.location ?? '',
                            );
                            _seedProgressIndicator(progress?.percentage);
                            return _buildReaderWidget(
                              engine,
                              settings,
                              highlightsAsync,
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => AppEmptyState(
                            icon: Icons.error_outline,
                            title: l10n.errorLoadingProgress,
                            description: '$e',
                            iconColor: colors.error,
                          ),
                        ),
                ),
              ),
              if (settings.brightness < 1.0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withAlpha(
                        ((1.0 - settings.brightness) * 200).round(),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  duration: AppMotion.duration(context),
                  curve: _showUi ? AppMotion.curve : Curves.easeInCubic,
                  offset: _showUi ? Offset.zero : const Offset(0, -1),
                  child: IgnorePointer(
                    ignoring: !_showUi,
                    child: ExcludeFocus(
                      excluding: !_showUi,
                      child: AppSurface(
                        key: const ValueKey('reader-top-bar'),
                        padding: EdgeInsets.zero,
                        radius: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Center(
                            heightFactor: 1,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppLayout.contentMaxWidth,
                                minHeight: AppLayout.minTouchTarget,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).backButtonTooltip,
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: _closeReader,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        widget.book.title,
                                        style: theme.textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _buildBookmarkAction(bookmarksAsync),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  duration: AppMotion.duration(context),
                  curve: _showUi ? AppMotion.curve : Curves.easeInCubic,
                  offset: _showUi ? Offset.zero : const Offset(0, 1),
                  child: IgnorePointer(
                    ignoring: !_showUi,
                    child: ExcludeFocus(
                      excluding: !_showUi,
                      child: AppSurface(
                        key: const ValueKey('reader-bottom-bar'),
                        padding: EdgeInsets.zero,
                        radius: 0,
                        child: SafeArea(
                          top: false,
                          child: Center(
                            heightFactor: 1,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppLayout.contentMaxWidth,
                              ),
                              child: ValueListenableBuilder<_ReaderProgressState>(
                                valueListenable: _progressNotifier,
                                builder: (context, progressState, _) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.compact,
                                      AppSpacing.sm,
                                      AppSpacing.compact,
                                      AppSpacing.xs,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.sm,
                                                    ),
                                                child: LinearProgressIndicator(
                                                  value: progressState.fraction,
                                                  backgroundColor: colors
                                                      .surfaceContainerHighest,
                                                  minHeight: AppSpacing.xs,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.compact,
                                            ),
                                            Text(
                                              progressState.label,
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Wrap(
                                          alignment: WrapAlignment.spaceEvenly,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: AppSpacing.compact,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.format_list_bulleted,
                                              ),
                                              tooltip: l10n.tableOfContents,
                                              onPressed: () => _scaffoldKey
                                                  .currentState
                                                  ?.openDrawer(),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons
                                                    .collections_bookmark_outlined,
                                              ),
                                              tooltip: l10n.annotations,
                                              onPressed: () =>
                                                  _showAnnotationsPanel(
                                                    context,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.settings),
                                              tooltip: l10n.readerSettings,
                                              onPressed: () =>
                                                  _showSettings(context),
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
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: AppMotion.duration(context),
                curve: AppMotion.curve,
                right: _selectedText != null
                    ? AppSpacing.compact
                    : -(AppLayout.minTouchTarget + AppSpacing.md),
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: _selectedText == null,
                  child: ExcludeFocus(
                    excluding: _selectedText == null,
                    child: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.sizeOf(context).height -
                                AppSpacing.xl,
                          ),
                          child: _buildSelectionBar(),
                        ),
                      ),
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

  Widget _buildReaderWidget(
    BookReaderEngine engine,
    ReaderSettings settings,
    AsyncValue<List<HighlightDto>> highlights,
  ) {
    return engine.buildReaderWidget(
      context: context,
      settings: settings,
      theme: Theme.of(context),
      initialLocation: _initialLocation!,
      onCenterTapped: _toggleUi,
      highlights: _buildHighlightsData(highlights),
      onProgressChanged: (location, percentage) {
        if (!mounted || _engine != engine) return;
        _progressNotifier.value = _progressStateFromPercentage(
          percentage,
          location: location,
        );
        unawaited(
          _progressController.saveProgress(
            location: location.locator,
            percentage: percentage,
          ),
        );
      },
      onTextSelected: (text, location) {
        if (!mounted || _engine != engine) return;
        setState(() {
          final hasSelection =
              text.trim().isNotEmpty && location.locator.isNotEmpty;
          _selectedText = hasSelection ? text : null;
          _selectedLocation = hasSelection ? location.locator : null;
        });
      },
    );
  }

  List<Map<String, dynamic>> _buildHighlightsData(
    AsyncValue<List<HighlightDto>> highlightsAsync,
  ) {
    final highlights = highlightsAsync.valueOrNull ?? const <HighlightDto>[];
    if (identical(highlights, _mappedHighlights)) return _highlightData;
    final result = <Map<String, dynamic>>[];
    for (final h in highlights) {
      if (widget.book.format == 'pdf') {
        result.add({
          'highlightId': h.id,
          'location': h.location,
          'color': h.color,
        });
        continue;
      }
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
    _mappedHighlights = highlights;
    return _highlightData = result;
  }

  void _seedProgressIndicator(double? percentage) {
    if (_didSeedProgressFromStorage) return;
    _progressNotifier.value = _progressStateFromPercentage(percentage);
    _didSeedProgressFromStorage = true;
  }

  _ReaderProgressState _progressStateFromPercentage(
    double? percentage, {
    BookLocation? location,
  }) {
    final value = (percentage ?? 0).clamp(0.0, 100.0).toDouble();
    return _ReaderProgressState(
      fraction: value / 100,
      label: '${value.toStringAsFixed(1)}%',
      location: location,
    );
  }

  Widget _buildBookmarkAction(AsyncValue<List<BookmarkDto>> bookmarks) {
    return ValueListenableBuilder<_ReaderProgressState>(
      valueListenable: _progressNotifier,
      builder: (context, progress, _) {
        final location = progress.location;
        BookmarkDto? current;
        for (final bookmark in bookmarks.valueOrNull ?? const <BookmarkDto>[]) {
          if (bookmark.location == location?.locator) {
            current = bookmark;
            break;
          }
        }
        final l10n = AppLocalizations.of(context)!;
        return IconButton(
          tooltip: current == null ? l10n.addBookmark : l10n.removeBookmark,
          icon: Icon(
            current == null ? Icons.bookmark_add_outlined : Icons.bookmark,
          ),
          onPressed:
              location == null ||
                  location.locator.isEmpty ||
                  !bookmarks.hasValue ||
                  _bookmarkWriteGeneration == _loadGeneration
              ? null
              : () =>
                    _toggleBookmark(location, progress.fraction * 100, current),
        );
      },
    );
  }

  Future<void> _toggleBookmark(
    BookLocation location,
    double percentage,
    BookmarkDto? current,
  ) async {
    final generation = _loadGeneration;
    if (_bookmarkWriteGeneration == generation) return;
    final bookId = widget.book.id;
    setState(() => _bookmarkWriteGeneration = generation);
    try {
      final controller = ref.read(bookmarksControllerProvider(bookId).notifier);
      if (current == null) {
        await controller.addBookmark(
          location: location.locator,
          percentage: percentage,
        );
      } else {
        await controller.removeBookmark(current.id);
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              current == null
                  ? l10n.bookmarkSaveError('$error')
                  : l10n.bookmarkDeleteError('$error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted && _bookmarkWriteGeneration == generation) {
        setState(() => _bookmarkWriteGeneration = null);
      }
    }
  }

  Widget _buildSelectionBar() {
    final l10n = AppLocalizations.of(context)!;
    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      radius: AppRadius.md,
      child: SizedBox(
        width: AppLayout.minTouchTarget,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _highlightSwatch(Theme.of(context).colorScheme.primary),
              for (final color in _highlightColors)
                _highlightSwatch(_parseColor(color)),
              const SizedBox(height: AppSpacing.xs),
              IconButton(
                tooltip: l10n.addNote,
                icon: const Icon(Icons.note_add_outlined),
                onPressed: _addNote,
              ),
              IconButton(
                tooltip: l10n.copyText,
                icon: const Icon(Icons.copy_outlined),
                onPressed: _copySelection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlightSwatch(Color color) {
    return SizedBox.square(
      dimension: AppLayout.minTouchTarget,
      child: IconButton(
        tooltip: AppLocalizations.of(context)!.highlightText,
        onPressed: () => _saveHighlight(_colorHex(color)),
        icon: Container(
          width: AppSpacing.lg,
          height: AppSpacing.lg,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }

  Future<void> _saveHighlight(String color) async {
    final text = _selectedText;
    final location = _selectedLocation;
    if (text == null || location == null) return;
    await _persistHighlight(text, location, color: color);
  }

  Future<void> _persistHighlight(
    String text,
    String location, {
    required String color,
    String? note,
  }) async {
    final generation = _loadGeneration;
    if (_highlightWriteGeneration == generation) return;
    _highlightWriteGeneration = generation;
    final bookId = widget.book.id;
    try {
      await ref
          .read(highlightsControllerProvider(bookId).notifier)
          .addHighlight(
            text: text,
            location: location,
            color: color,
            note: note,
          );
      if (mounted &&
          generation == _loadGeneration &&
          widget.book.id == bookId &&
          _selectedText == text &&
          _selectedLocation == location) {
        setState(() {
          _selectedText = null;
          _selectedLocation = null;
        });
        FocusManager.instance.primaryFocus?.unfocus();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.highlightSaveError('$error'),
            ),
          ),
        );
      }
    } finally {
      if (_highlightWriteGeneration == generation)
        _highlightWriteGeneration = null;
    }
  }

  Future<void> _addNote() async {
    final text = _selectedText;
    final location = _selectedLocation;
    if (text == null ||
        location == null ||
        _highlightWriteGeneration == _loadGeneration)
      return;
    final bookId = widget.book.id;
    final generation = _loadGeneration;
    final l10n = AppLocalizations.of(context)!;
    final color = _colorHex(Theme.of(context).colorScheme.primary);
    var noteText = '';
    final note = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addNote),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${text.length > 100 ? '${text.substring(0, 100)}...' : text}"',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            TextField(
              onChanged: (value) => noteText = value,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(hintText: l10n.noteHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, noteText),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (note != null &&
        mounted &&
        generation == _loadGeneration &&
        widget.book.id == bookId) {
      await _persistHighlight(
        text,
        location,
        color: color,
        note: note.isEmpty ? null : note,
      );
    }
  }

  void _copySelection() {
    if (_selectedText != null) {
      Clipboard.setData(ClipboardData(text: _selectedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.copied),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedText = null;
      _selectedLocation = null;
    });
  }

  Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String _colorHex(Color color) {
    final rgb = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return '#${rgb.toUpperCase()}';
  }

  void _showAnnotationsPanel(BuildContext context) {
    showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => ReaderAnnotationsPanel(
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
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(title: l10n.tableOfContents),
            const Divider(),
            Expanded(
              child: toc.isEmpty
                  ? SingleChildScrollView(
                      child: AppEmptyState(
                        icon: Icons.format_list_bulleted,
                        title: l10n.tableOfContentsUnavailable,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.compact,
                      ),
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
    final padding = AppSpacing.compact + (depth * AppSpacing.md);

    if (item.subItems.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(
          left: padding,
          right: AppSpacing.compact,
        ),
        title: Text(item.title, style: Theme.of(context).textTheme.bodyLarge),
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
    showAppBottomSheet<void>(
      context: context,
      builder: (context) => const SettingsPanel(),
    );
  }
}

class _ReaderProgressState {
  final double fraction;
  final String label;
  final BookLocation? location;

  const _ReaderProgressState({
    required this.fraction,
    required this.label,
    this.location,
  });
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
          contentPadding: EdgeInsets.only(
            left: widget.padding,
            right: AppSpacing.compact,
          ),
          leading: IconButton(
            tooltip: _expanded
                ? MaterialLocalizations.of(context).expandedIconTapHint
                : MaterialLocalizations.of(context).collapsedIconTapHint,
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
          title: Text(
            widget.item.title,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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
          contentPadding: EdgeInsets.only(
            left: widget.padding + AppSpacing.md,
            right: AppSpacing.compact,
          ),
          title: Text(item.title, style: Theme.of(context).textTheme.bodyLarge),
          onTap: () => widget.onNavigate(item.fileName),
        );
      }

      return _ExpandableTocItem(
        item: item,
        padding: widget.padding + AppSpacing.md,
        depth: widget.depth + 1,
        onNavigate: widget.onNavigate,
      );
    }).toList();
  }
}
