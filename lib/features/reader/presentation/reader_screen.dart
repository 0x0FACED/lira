import 'dart:async';
import 'dart:io';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/foundation.dart';
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
import '../../settings/presentation/reader_page_dimming.dart';
import '../../settings/presentation/reader_settings_workspace.dart';
import '../domain/engine/book_reader_engine.dart';
import '../domain/engine/epub_book_reader_engine.dart';
import '../domain/engine/pdf_book_reader_engine.dart';
import '../domain/models/book_location.dart';
import '../domain/models/book_search.dart';
import '../domain/models/bookmark_region.dart';
import 'reader_annotations_panel.dart';
import 'reader_search_controller.dart';
import 'reader_search_panel.dart';

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
  static const _readerChromeChannel = MethodChannel(
    'dev.u0xfaced.lira/reader_chrome',
  );
  bool _showUi = false;
  bool _settingsOpen = false;
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

  final _searchTextController = TextEditingController();
  ReaderSearchController? _search;
  bool _searchActive = false;
  bool _searchHasNavigated = false;
  bool _searchPanelOpen = false;
  BuildContext? _searchPanelContext;
  BookLocation? _searchOrigin;
  int _searchNavigationGeneration = 0;
  List<BookSearchMatch>? _mappedSearchMatches;
  List<Map<String, dynamic>> _searchHighlights = const [];
  List<Map<String, dynamic>>? _combinedAnnotationData;
  List<Map<String, dynamic>>? _combinedSearchData;
  int _combinedActiveIndex = -1;
  List<Map<String, dynamic>> _combinedHighlightData = const [];

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
    _syncAndroidSystemBars();
  }

  @override
  void didUpdateWidget(covariant ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.fileUrl != widget.book.fileUrl ||
        oldWidget.book.format != widget.book.format) {
      _flushProgressInBackground();
      _disposeSearch();
      _engine?.dispose();
      _engine = null;
      _initialLocation = null;
      _didSeedProgressFromStorage = false;
      _selectedText = null;
      _selectedLocation = null;
      _showUi = false;
      _settingsOpen = false;
      _startBook();
    }
  }

  Future<BookReaderEngine> _initEngine(int generation) async {
    final book = widget.book;
    BookReaderEngine? engine;
    try {
      if (book.format == 'epub') {
        engine = EpubBookReaderEngine();
      } else if (book.format == 'pdf') {
        engine = PdfBookReaderEngine();
      } else {
        throw UnsupportedError('Format ${book.format} is not supported');
      }
      final bytes = await File(book.fileUrl!).readAsBytes();
      await engine.loadBook(bytes);
      if (!mounted || generation != _loadGeneration) {
        engine.dispose();
        return engine;
      }
      _engine = engine;
      _search = ReaderSearchController(engine)..addListener(_onSearchChanged);
      return engine;
    } catch (_) {
      engine?.dispose();
      if (mounted && generation == _loadGeneration) {
        _showUi = true;
        _syncAndroidSystemBars();
      }
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAndroidSystemBars();
    } else {
      _flushProgressInBackground();
    }
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
    _syncAndroidSystemBars(restore: true);
    _flushProgressInBackground();
    _disposeSearch(dismissPanel: false);
    _searchTextController.dispose();
    _engine?.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  void _toggleUi() {
    if (_settingsOpen) return;
    setState(() {
      _showUi = !_showUi;
    });
    _syncAndroidSystemBars();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final matches = _search?.matches ?? const <BookSearchMatch>[];
    if (!identical(matches, _mappedSearchMatches)) {
      _mappedSearchMatches = matches;
      _searchHighlights = [
        for (final match in matches) _searchHighlight(match, '#FFEB3B'),
      ];
    }
    setState(() {});
  }

  Map<String, dynamic> _searchHighlight(BookSearchMatch match, String color) {
    if (widget.book.format == 'pdf') {
      return {'location': match.location.locator, 'color': color};
    }
    final cfi = EpubCfi.fromJson(match.location.locator)!;
    return {
      'chapterIndex': cfi.spineIndex,
      'startOffset': cfi.startOffset!,
      'endOffset': cfi.endOffset!,
      'color': color,
    };
  }

  Future<void> _showSearch() async {
    final search = _search;
    if (_searchPanelOpen ||
        search == null ||
        _initialLocation == null ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    if (!_searchActive) {
      _searchOrigin =
          _progressNotifier.value.location ??
          (_initialLocation!.locator.isNotEmpty
              ? _initialLocation
              : BookLocation(
                  locator: widget.book.format == 'pdf'
                      ? '1'
                      : EpubLocation.fromPosition(
                          chapterIndex: 0,
                          charOffset: 0,
                          hasExactCharOffset: true,
                        ).toJson(),
                ));
    }
    setState(() {
      _searchActive = true;
      _showUi = true;
      _selectedText = null;
      _selectedLocation = null;
      _searchPanelOpen = true;
    });
    _syncAndroidSystemBars();
    try {
      await showAppBottomSheet<void>(
        context: context,
        builder: (ctx) {
          _searchPanelContext = ctx;
          return ReaderSearchPanel(
            search: search,
            textController: _searchTextController,
            isPdf: widget.book.format == 'pdf',
            onClose: () => Navigator.pop(ctx),
            onSubmit: _submitSearch,
            onSelect: (index) {
              FocusScope.of(ctx).unfocus();
              Navigator.pop(ctx);
              unawaited(_goToSearchResult(index));
            },
          );
        },
      );
    } finally {
      if (mounted && identical(_search, search)) {
        _searchPanelContext = null;
        _searchPanelOpen = false;
      }
    }
  }

  Future<void> _submitSearch() async {
    final search = _search;
    if (search == null || search.query.isEmpty) return;
    final query = search.query;
    if (search.isSearching || !search.hasSearched || search.error != null) {
      await search.searchNow();
    }
    if (!mounted ||
        !identical(_search, search) ||
        search.query != query ||
        search.isSearching ||
        search.error != null ||
        search.matches.isEmpty)
      return;
    _dismissSearchPanel();
    await _goToSearchResult(
      search.activeIndex < 0
          ? 0
          : (search.activeIndex + 1) % search.matches.length,
    );
  }

  void _moveSearch(int direction) {
    final search = _search;
    if (search == null || search.isSearching || search.matches.isEmpty) return;
    final index = search.activeIndex < 0
        ? (direction > 0 ? 0 : search.matches.length - 1)
        : (search.activeIndex + direction) % search.matches.length;
    unawaited(_goToSearchResult(index));
  }

  Future<void> _goToSearchResult(int index) async {
    final search = _search;
    final engine = _engine;
    if (search == null ||
        engine == null ||
        search.isSearching ||
        index < 0 ||
        index >= search.matches.length)
      return;
    final generation = ++_searchNavigationGeneration;
    search.select(index);
    setState(() => _searchHasNavigated = true);
    try {
      await engine.goToLocation(search.matches[index].location);
    } catch (_) {
      if (mounted &&
          identical(engine, _engine) &&
          generation == _searchNavigationGeneration)
        _showSearchNavigationError();
    }
  }

  Future<void> _returnFromSearch() async {
    final origin = _searchOrigin;
    final engine = _engine;
    if (origin == null || engine == null) return;
    final generation = ++_searchNavigationGeneration;
    try {
      await engine.goToLocation(origin);
      if (mounted &&
          identical(engine, _engine) &&
          generation == _searchNavigationGeneration)
        _finishSearch();
    } catch (_) {
      if (mounted &&
          identical(engine, _engine) &&
          generation == _searchNavigationGeneration)
        _showSearchNavigationError();
    }
  }

  void _showSearchNavigationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.readerSearchNavigationError,
        ),
      ),
    );
  }

  void _dismissSearchPanel() {
    final panel = _searchPanelContext;
    if (panel != null &&
        panel.mounted &&
        ModalRoute.of(panel)?.isCurrent == true) {
      FocusScope.of(panel).unfocus();
      Navigator.pop(panel);
    }
  }

  void _finishSearch() {
    ++_searchNavigationGeneration;
    _dismissSearchPanel();
    _search?.clear();
    _searchTextController.clear();
    setState(() {
      _searchActive = false;
      _searchHasNavigated = false;
      _searchOrigin = null;
      _showUi = false;
    });
    _syncAndroidSystemBars();
  }

  void _disposeSearch({bool dismissPanel = true}) {
    ++_searchNavigationGeneration;
    if (dismissPanel) {
      _dismissSearchPanel();
      _searchTextController.clear();
    }
    _search?.removeListener(_onSearchChanged);
    _search?.dispose();
    _search = null;
    _searchPanelContext = null;
    _searchPanelOpen = false;
    _searchActive = false;
    _searchHasNavigated = false;
    _searchOrigin = null;
    _mappedSearchMatches = null;
    _searchHighlights = const [];
    _combinedAnnotationData = null;
    _combinedSearchData = null;
    _combinedHighlightData = const [];
  }

  void _syncAndroidSystemBars({bool restore = false}) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(
      _readerChromeChannel
          .invokeMethod<void>(
            restore ? 'restoreSystemBars' : 'setReaderChromeVisible',
            restore ? null : (_showUi || _searchActive),
          )
          .catchError((Object error, StackTrace stack) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'Lira reader',
                context: ErrorDescription('while updating Android system bars'),
              ),
            );
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final chromeVisible = (_showUi || _searchActive) && !_settingsOpen;
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _showSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _showSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_settingsOpen) {
            _closeSettings();
          } else if (_searchActive) {
            _finishSearch();
          }
        },
      },
      child: FocusScope(
        autofocus: true,
        child: FutureBuilder<BookReaderEngine>(
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
              body: ReaderSettingsWorkspace(
                isOpen: _settingsOpen,
                onOpen: () => _showSettings(context),
                onClose: _closeSettings,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Color(settings.backgroundColor),
                        child: _initialLocation != null
                            ? _buildReaderWidget(
                                engine,
                                settings,
                                highlightsAsync,
                              )
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
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, st) => AppEmptyState(
                                  icon: Icons.error_outline,
                                  title: l10n.errorLoadingProgress,
                                  description: '$e',
                                  iconColor: colors.error,
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
                        curve: chromeVisible
                            ? AppMotion.curve
                            : Curves.easeInCubic,
                        offset: chromeVisible
                            ? Offset.zero
                            : const Offset(0, -1),
                        child: IgnorePointer(
                          ignoring: !chromeVisible,
                          child: ExcludeFocus(
                            excluding: !chromeVisible,
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
                                      padding: const EdgeInsets.all(
                                        AppSpacing.xs,
                                      ),
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
                                              style:
                                                  theme.textTheme.titleMedium,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          IconButton(
                                            tooltip: l10n.readerSearch,
                                            icon: const Icon(Icons.search),
                                            onPressed: _showSearch,
                                          ),
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
                        curve: chromeVisible
                            ? AppMotion.curve
                            : Curves.easeInCubic,
                        offset: chromeVisible
                            ? Offset.zero
                            : const Offset(0, 1),
                        child: IgnorePointer(
                          ignoring: !chromeVisible,
                          child: ExcludeFocus(
                            excluding: !chromeVisible,
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
                                              if (_searchActive &&
                                                  _search != null)
                                                ReaderSearchNavigation(
                                                  search: _search!,
                                                  canReturn:
                                                      _searchHasNavigated,
                                                  onOpen: _showSearch,
                                                  onMove: _moveSearch,
                                                  onReturn: _returnFromSearch,
                                                  onFinish: _finishSearch,
                                                ),
                                              if (!_searchActive)
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppRadius.sm,
                                                            ),
                                                        child: LinearProgressIndicator(
                                                          value: progressState
                                                              .fraction,
                                                          backgroundColor: colors
                                                              .surfaceContainerHighest,
                                                          minHeight:
                                                              AppSpacing.xs,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: AppSpacing.compact,
                                                    ),
                                                    Text(
                                                      progressState.label,
                                                      style: theme
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: colors
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              if (!_searchActive)
                                                const SizedBox(
                                                  height: AppSpacing.xs,
                                                ),
                                              if (!_searchActive)
                                                Wrap(
                                                  alignment:
                                                      WrapAlignment.spaceEvenly,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  spacing: AppSpacing.compact,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons
                                                            .format_list_bulleted,
                                                      ),
                                                      tooltip:
                                                          l10n.tableOfContents,
                                                      onPressed: () =>
                                                          _scaffoldKey
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
                                                      icon: const Icon(
                                                        Icons.settings,
                                                      ),
                                                      tooltip:
                                                          l10n.readerSettings,
                                                      onPressed: () =>
                                                          _showSettings(
                                                            context,
                                                          ),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReaderWidget(
    BookReaderEngine engine,
    ReaderSettings settings,
    AsyncValue<List<HighlightDto>> highlights,
  ) {
    return ReaderPageDimming(
      brightness: settings.brightness,
      child: engine.buildReaderWidget(
        context: context,
        settings: settings,
        theme: Theme.of(context),
        initialLocation: _initialLocation!,
        onCenterTapped: _toggleUi,
        highlights: _buildReaderHighlights(highlights),
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
      ),
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

  List<Map<String, dynamic>> _buildReaderHighlights(
    AsyncValue<List<HighlightDto>> highlightsAsync,
  ) {
    final annotations = _buildHighlightsData(highlightsAsync);
    if (!_searchActive || _searchHighlights.isEmpty) return annotations;
    final activeIndex = _search?.activeIndex ?? -1;
    if (identical(annotations, _combinedAnnotationData) &&
        identical(_searchHighlights, _combinedSearchData) &&
        activeIndex == _combinedActiveIndex)
      return _combinedHighlightData;
    _combinedAnnotationData = annotations;
    _combinedSearchData = _searchHighlights;
    _combinedActiveIndex = activeIndex;
    return _combinedHighlightData = [
      ...annotations,
      ..._searchHighlights,
      if (_search?.activeMatch case final match?)
        _searchHighlight(match, '#FF9800'),
    ];
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
        final current = bookmarkNearLocation(
          bookmarks: bookmarks.valueOrNull ?? const <BookmarkDto>[],
          format: widget.book.format,
          locator: location?.locator ?? '',
        );
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
    setState(() => _settingsOpen = true);
  }

  void _closeSettings() {
    setState(() => _settingsOpen = false);
    unawaited(
      ref
          .read(readerSettingsProvider.notifier)
          .flush()
          .catchError((Object _) {}),
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
