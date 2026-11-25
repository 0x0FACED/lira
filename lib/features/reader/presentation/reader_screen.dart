import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/formatters.dart';
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
import '../domain/annotation_tools.dart';
import '../domain/engine/book_reader_engine.dart';
import '../domain/engine/epub_book_reader_engine.dart';
import '../domain/engine/pdf_book_reader_engine.dart';
import '../domain/models/book_location.dart';
import '../domain/models/book_search.dart';
import '../domain/models/bookmark_region.dart';
import 'reader_annotations_panel.dart';
import 'reader_search_controller.dart';
import 'reader_search_panel.dart';

part 'reader_toc_list.dart';

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
  EdgeInsets? _androidBarInsets;
  final _currentChapter = ValueNotifier<TOCItem?>(null);
  final ValueNotifier<_ReaderProgressState> _progressNotifier = ValueNotifier(
    const _ReaderProgressState(fraction: 0),
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
  final _selectionViewportKey = GlobalKey();
  final _selectionAnchor = ValueNotifier<Rect?>(null);

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
    unawaited(_refreshAndroidBarInsets());
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
      _currentChapter.value = null;
      _clearSelection();
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
        final epubEngine = EpubBookReaderEngine(
          paginatedTopPadding: AppSpacing.sm,
          onPositionBeforeProgress: (location) {
            if (mounted && generation == _loadGeneration) {
              _recordReadingPosition(location);
            }
          },
        );
        engine = epubEngine;
        await epubEngine.loadBookFile(book.fileUrl!);
      } else if (book.format == 'pdf') {
        engine = PdfBookReaderEngine();
        final bytes = await File(book.fileUrl!).readAsBytes();
        await engine.loadBook(bytes);
      } else {
        throw UnsupportedError('Format ${book.format} is not supported');
      }
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
      unawaited(_refreshAndroidBarInsets());
    } else {
      _flushProgressInBackground();
    }
  }

  @override
  void didChangeMetrics() => unawaited(_refreshAndroidBarInsets());

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
    _currentChapter.dispose();
    _selectionAnchor.dispose();
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
      _clearSelection();
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

  Future<void> _refreshAndroidBarInsets() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final values = await _readerChromeChannel.invokeListMethod<double>(
        'getReaderBarInsets',
      );
      if (!mounted || values == null) return;
      final insets = EdgeInsets.only(top: values[0], bottom: values[1]);
      if (insets != _androidBarInsets)
        setState(() => _androidBarInsets = insets);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Lira reader',
          context: ErrorDescription('while reading Android system bar insets'),
        ),
      );
    }
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
                appBar: AppBar(
                  leading: Navigator.canPop(context)
                      ? MergeSemantics(
                          child: Semantics(
                            label: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                            child: const BackButton(),
                          ),
                        )
                      : null,
                  title: Text(widget.book.title),
                ),
                body: AppScrollableState(
                  child: AppEmptyState(
                    icon: Icons.error_outline,
                    title: l10n.errorLoadingBook,
                    description: '${snapshot.error}',
                    iconColor: colors.error,
                  ),
                ),
              );
            }

            final engine = snapshot.data;
            if (engine == null) {
              return Scaffold(
                body: AppScrollableState(
                  child: AppEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: l10n.failedToInitReader,
                    iconColor: colors.error,
                  ),
                ),
              );
            }

            final chromeTheme = _readerChromeTheme(theme, settings, context);
            final toc = engine.getToc();
            final paginated =
                widget.book.format == 'epub' &&
                settings.readingMode == ReadingMode.horizontal;
            final media = MediaQuery.of(context);
            final nativeInsets = _androidBarInsets ?? EdgeInsets.zero;
            final stableInsets = paginated
                ? EdgeInsets.only(
                    top: math.max(nativeInsets.top, media.viewPadding.top),
                    bottom: math.max(
                      nativeInsets.bottom,
                      media.viewPadding.bottom,
                    ),
                  )
                : null;
            final chapterStyle = chromeTheme.textTheme.bodySmall!.copyWith(
              color: chromeTheme.colorScheme.onSurfaceVariant,
            );
            final chapterExtent =
                (MediaQuery.textScalerOf(
                          context,
                        ).scale(chapterStyle.fontSize ?? 12) *
                        (chapterStyle.height ?? 1.5))
                    .ceilToDouble() +
                2 * AppSpacing.xs;
            final chapterTop = paginated
                ? stableInsets!.top
                : media.padding.top +
                      (chromeVisible
                          ? _ReaderChromeBar.rowExtent
                          : AppSpacing.xs);
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: paginated
                  ? chromeTheme.colorScheme.surface
                  : null,
              // The note dialog handles the keyboard; keep the book's pagination
              // and scroll viewport unchanged behind all annotation editors.
              resizeToAvoidBottomInset: false,
              drawer: _buildTocDrawer(toc),
              body: ReaderSettingsWorkspace(
                isOpen: _settingsOpen,
                onOpen: () => _showSettings(context),
                onClose: _closeSettings,
                child: Stack(
                  key: _selectionViewportKey,
                  children: [
                    Positioned.fill(
                      child: CustomMultiChildLayout(
                        delegate: _ReaderPageLayout(
                          reserveChrome: paginated,
                          chapterTop: chapterTop,
                        ),
                        children: [
                          LayoutId(
                            id: _ReaderPageSlot.book,
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
                                        _seedProgressIndicator(
                                          progress?.percentage,
                                        );
                                        return _buildReaderWidget(
                                          engine,
                                          settings,
                                          highlightsAsync,
                                        );
                                      },
                                      loading: () => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      error: (e, st) => AppScrollableState(
                                        child: AppEmptyState(
                                          icon: Icons.error_outline,
                                          title: l10n.errorLoadingProgress,
                                          description: '$e',
                                          iconColor: colors.error,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (toc.isNotEmpty)
                            LayoutId(
                              id: _ReaderPageSlot.chapter,
                              child: SizedBox(
                                height: chapterExtent,
                                child: ClipRect(
                                  child: ExcludeSemantics(
                                    excluding: paginated && chromeVisible,
                                    child: _ReaderChapterLabel(
                                      chapter: _currentChapter,
                                      style: chapterStyle,
                                      paper: chromeTheme.colorScheme.surface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          LayoutId(
                            id: _ReaderPageSlot.topBar,
                            child: _ReaderChromeBar(
                              surfaceKey: const ValueKey('reader-top-bar'),
                              visible: chromeVisible,
                              top: true,
                              stableInsets: stableInsets,
                              theme: chromeTheme,
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
                                      style: chromeTheme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontSize: 17,
                                            color: chromeTheme
                                                .colorScheme
                                                .onSurface,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
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
                          LayoutId(
                            id: _ReaderPageSlot.bottomBar,
                            child: _ReaderChromeBar(
                              surfaceKey: const ValueKey('reader-bottom-bar'),
                              visible: chromeVisible,
                              top: false,
                              stableInsets: stableInsets,
                              theme: chromeTheme,
                              child: _searchActive && _search != null
                                  ? ReaderSearchNavigation(
                                      search: _search!,
                                      canReturn: _searchHasNavigated,
                                      onOpen: _showSearch,
                                      onMove: _moveSearch,
                                      onReturn: _returnFromSearch,
                                      onFinish: _finishSearch,
                                    )
                                  : Row(
                                      children: [
                                        IconButton(
                                          tooltip: l10n.tableOfContents,
                                          icon: const Icon(
                                            Icons.format_list_bulleted,
                                          ),
                                          onPressed: () => _scaffoldKey
                                              .currentState
                                              ?.openDrawer(),
                                        ),
                                        IconButton(
                                          tooltip: l10n.annotations,
                                          icon: const Icon(
                                            Icons.collections_bookmark_outlined,
                                          ),
                                          onPressed: () =>
                                              _showAnnotationsPanel(context),
                                        ),
                                        IconButton(
                                          tooltip: l10n.readerSettings,
                                          icon: ExcludeSemantics(
                                            child: Builder(
                                              builder: (context) => Text(
                                                'Aa',
                                                style: TextStyle(
                                                  fontFamily: 'Lora',
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1,
                                                  color: IconTheme.of(
                                                    context,
                                                  ).color,
                                                ),
                                              ),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _showSettings(context),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child:
                                              ValueListenableBuilder<
                                                _ReaderProgressState
                                              >(
                                                valueListenable:
                                                    _progressNotifier,
                                                builder:
                                                    (context, progress, _) =>
                                                        _ReaderChromeProgress(
                                                          fraction:
                                                              progress.fraction,
                                                        ),
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_settingsOpen)
                      Positioned.fill(
                        child: ValueListenableBuilder<Rect?>(
                          valueListenable: _selectionAnchor,
                          child: _buildSelectionBar(),
                          builder: (context, anchor, child) {
                            if (anchor == null) return const SizedBox.shrink();
                            return CustomSingleChildLayout(
                              delegate: _SelectionBarLayout(
                                anchor,
                                MediaQuery.paddingOf(context),
                              ),
                              child: child,
                            );
                          },
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
          _recordReadingPosition(location, percentage: percentage);
        },
        onTextSelected: (text, location) {
          if (!mounted || _engine != engine) return;
          if (text.trim().isEmpty || location.locator.isEmpty) {
            _clearSelection();
          } else {
            _selectedText = text;
            _selectedLocation = location.locator;
          }
        },
        onSelectionAnchorChanged: (anchor) {
          if (!mounted || _engine != engine || _selectedText == null) return;
          final viewport = _selectionViewportKey.currentContext
              ?.findRenderObject();
          _selectionAnchor.value = anchor != null && viewport is RenderBox
              ? Rect.fromPoints(
                  viewport.globalToLocal(anchor.topLeft),
                  viewport.globalToLocal(anchor.bottomRight),
                )
              : null;
        },
      ),
    );
  }

  void _recordReadingPosition(BookLocation location, {double? percentage}) {
    if (_progressNotifier.value.location != location) {
      _currentChapter.value = _engine?.tocItemAt(location);
    }
    // An exact EPUB locator is usable before the total text weight is ready.
    // Keep the last known percentage rather than estimate it from raw XHTML.
    final value = percentage ?? _progressNotifier.value.fraction * 100;
    _progressNotifier.value = _progressStateFromPercentage(
      value,
      location: location,
    );
    unawaited(
      _progressController.saveProgress(
        location: location.locator,
        percentage: value,
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
    return _ReaderProgressState(fraction: value / 100, location: location);
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
        final activeColor = Theme.of(context).colorScheme.primary;
        return IconButton(
          tooltip: current == null ? l10n.addBookmark : l10n.removeBookmark,
          icon: Icon(
            current == null ? Icons.bookmark_add_outlined : Icons.bookmark,
          ),
          style: current == null
              ? null
              : IconButton.styleFrom(foregroundColor: activeColor),
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

  void _clearSelection() {
    _selectedText = null;
    _selectedLocation = null;
    _selectionAnchor.value = null;
  }

  Widget _buildSelectionBar() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final swatches = Wrap(
      alignment: WrapAlignment.center,
      children: [
        _highlightSwatch(colors.primary),
        for (final color in _highlightColors)
          _highlightSwatch(_parseColor(color)),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.addNote,
          icon: const Icon(Icons.note_add_outlined),
          onPressed: _addNote,
        ),
        IconButton(
          tooltip: l10n.annotationsToolsCopyQuote,
          icon: const Icon(Icons.copy_outlined),
          onPressed: _copySelection,
        ),
      ],
    );
    return Theme(
      data: theme.copyWith(
        iconButtonTheme: _readerIconButtons(
          theme,
          context,
          colors.onSurfaceVariant,
        ),
      ),
      child: Material(
        key: const ValueKey('reader-selection-actions'),
        color: colors.surfaceContainer,
        shadowColor: colors.shadow.withValues(alpha: 0.22),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const separatorSpace = 2 * AppSpacing.xs + 1;
              final singleRowWidth =
                  (_highlightColors.length + 3) * AppLayout.minTouchTarget +
                  separatorSpace;
              if (constraints.maxWidth >= singleRowWidth) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    swatches,
                    SizedBox(
                      height: AppSpacing.lg,
                      child: VerticalDivider(
                        width: separatorSpace,
                        thickness: 1,
                        color: colors.outlineVariant,
                      ),
                    ),
                    actions,
                  ],
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  swatches,
                  SizedBox(
                    width: 2 * AppLayout.minTouchTarget,
                    child: Divider(height: 1, color: colors.outlineVariant),
                  ),
                  actions,
                ],
              );
            },
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
          width: AppSpacing.md,
          height: AppSpacing.md,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        _clearSelection();
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

  Future<void> _copySelection() async {
    final text = _selectedText;
    if (text == null) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(
        ClipboardData(text: attributedQuote(text, widget.book)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.copied),
          duration: const Duration(seconds: 1),
        ),
      );
      if (_selectedText != text) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _clearSelection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.annotationsToolsCopyError('$error'))),
      );
    }
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
        book: widget.book,
        onNavigate: (location) {
          _engine?.goToLocation(BookLocation(locator: location));
          Navigator.pop(ctx);
          if (_showUi) _toggleUi();
        },
      ),
    );
  }

  Drawer _buildTocDrawer(List<TOCItem> toc) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Drawer(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: Theme(
        data: theme.copyWith(
          iconButtonTheme: _readerIconButtons(
            theme,
            context,
            colors.onSurfaceVariant,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.compact,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.tableOfContents,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: toc.isEmpty
                    ? AppScrollableState(
                        child: AppEmptyState(
                          icon: Icons.format_list_bulleted,
                          title: l10n.tableOfContentsUnavailable,
                        ),
                      )
                    : ValueListenableBuilder<TOCItem?>(
                        valueListenable: _currentChapter,
                        builder: (context, active, _) => _ReaderTocList(
                          key: ObjectKey(active),
                          items: toc,
                          active: active,
                          onNavigate: _navigateFromToc,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateFromToc(String fileName) {
    _engine?.goToLocation(BookLocation(locator: fileName));
    _scaffoldKey.currentState?.closeDrawer();
    if (_showUi) _toggleUi();
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

class _SelectionBarLayout extends SingleChildLayoutDelegate {
  const _SelectionBarLayout(this.anchor, this.insets);

  final Rect anchor;
  final EdgeInsets insets;

  Rect _available(Size size) => (Offset.zero & size)
      .deflate(AppSpacing.sm)
      .intersect(insets.deflateRect(Offset.zero & size));

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final bounds = _available(constraints.biggest);
    return BoxConstraints(
      maxWidth: bounds.width.clamp(0.0, double.infinity),
      maxHeight: bounds.height.clamp(0.0, double.infinity),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bounds = _available(size);
    final above = anchor.top - AppSpacing.sm - childSize.height;
    // Flutter selection handles extend below the line.
    final below = anchor.bottom + AppSpacing.lg;
    final y =
        above >= bounds.top ||
            below + childSize.height > bounds.bottom &&
                anchor.top - bounds.top > bounds.bottom - anchor.bottom
        ? above
        : below;
    return Offset(
      (anchor.center.dx - childSize.width / 2).clamp(
        bounds.left,
        bounds.right - childSize.width,
      ),
      y.clamp(bounds.top, bounds.bottom - childSize.height),
    );
  }

  @override
  bool shouldRelayout(_SelectionBarLayout oldDelegate) =>
      anchor != oldDelegate.anchor || insets != oldDelegate.insets;
}

ThemeData _readerChromeTheme(
  ThemeData theme,
  ReaderSettings settings,
  BuildContext context,
) {
  final paper = Color.alphaBlend(
    ReaderPageDimming.shadeFor(settings.brightness),
    Color(settings.backgroundColor),
  );
  final paperLuminance = paper.computeLuminance();
  bool isReadable(Color color) {
    final luminance = color.computeLuminance();
    return (luminance > paperLuminance
            ? (luminance + 0.05) / (paperLuminance + 0.05)
            : (paperLuminance + 0.05) / (luminance + 0.05)) >=
        4.5;
  }

  // The book may deliberately be low-contrast; controls still need to be legible.
  final pageInk = Color.alphaBlend(settings.resolvedTextColor, paper);
  final ink = isReadable(pageInk)
      ? pageInk
      : paperLuminance > 0.179
      ? Colors.black
      : Colors.white;
  final softenedInk = Color.lerp(paper, ink, 0.72)!;
  final muted = isReadable(softenedInk) ? softenedInk : ink;
  final link = Color.alphaBlend(settings.resolvedLinkColor, paper);
  final accent = isReadable(link) ? link : ink;
  final disabled = muted.withValues(alpha: 0.38);
  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: muted,
      primary: accent,
    ),
    iconButtonTheme: _readerIconButtons(theme, context, muted),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: muted,
        disabledForegroundColor: disabled,
      ).merge(theme.textButtonTheme.style),
    ),
  );
}

IconButtonThemeData _readerIconButtons(
  ThemeData theme,
  BuildContext context,
  Color ink,
) => IconButtonThemeData(
  style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
      ),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size.square(AppLayout.minTouchTarget),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    visualDensity: VisualDensity.standard,
    iconSize: const WidgetStatePropertyAll(20),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? ink.withValues(alpha: 0.38)
          : ink,
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => _readerInteractionInk(states, ink),
    ),
    splashFactory: NoSplash.splashFactory,
    animationDuration: AppMotion.duration(context, AppMotion.fast),
  ),
);

Color _readerInteractionInk(Set<WidgetState> states, Color ink) {
  final alpha = switch (states) {
    _ when states.contains(WidgetState.pressed) => 0.12,
    _ when states.contains(WidgetState.focused) => 0.18,
    _ when states.contains(WidgetState.hovered) => 0.07,
    _ => 0.0,
  };
  return ink.withValues(alpha: alpha);
}

enum _ReaderPageSlot { book, chapter, topBar, bottomBar }

class _ReaderPageLayout extends MultiChildLayoutDelegate {
  _ReaderPageLayout({required this.reserveChrome, required this.chapterTop});

  final bool reserveChrome;
  final double chapterTop;

  @override
  void performLayout(Size size) {
    final fullWidth = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: size.height,
    );
    final top = layoutChild(_ReaderPageSlot.topBar, fullWidth).height;
    final bottom = layoutChild(_ReaderPageSlot.bottomBar, fullWidth).height;
    positionChild(_ReaderPageSlot.topBar, Offset.zero);
    positionChild(_ReaderPageSlot.bottomBar, Offset(0, size.height - bottom));

    final bookTop = reserveChrome ? top : 0.0;
    final bookBottom = reserveChrome ? size.height - bottom : size.height;
    layoutChild(
      _ReaderPageSlot.book,
      BoxConstraints.tightFor(
        width: size.width,
        height: math.max(0.0, bookBottom - bookTop),
      ),
    );
    positionChild(_ReaderPageSlot.book, Offset(0, bookTop));

    if (hasChild(_ReaderPageSlot.chapter)) {
      final label = layoutChild(
        _ReaderPageSlot.chapter,
        reserveChrome
            ? fullWidth.copyWith(maxHeight: math.max(0.0, top - chapterTop))
            : fullWidth,
      );
      // The chapter label shares the top margin with the toolbar, not the book.
      positionChild(
        _ReaderPageSlot.chapter,
        Offset(0, reserveChrome ? top - label.height : chapterTop),
      );
    }
  }

  @override
  bool shouldRelayout(_ReaderPageLayout oldDelegate) =>
      reserveChrome != oldDelegate.reserveChrome ||
      chapterTop != oldDelegate.chapterTop;
}

class _ReaderChromeBar extends StatelessWidget {
  const _ReaderChromeBar({
    required this.surfaceKey,
    required this.visible,
    required this.top,
    required this.theme,
    this.stableInsets,
    required this.child,
  });

  static const rowExtent = AppLayout.minTouchTarget + 2 * AppSpacing.xs;

  final Key surfaceKey;
  final bool visible;
  final bool top;
  final ThemeData theme;
  final EdgeInsets? stableInsets;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: AppMotion.duration(context),
      curve: visible ? AppMotion.curve : Curves.easeInCubic,
      offset: visible ? Offset.zero : Offset(0, top ? -1 : 1),
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeFocus(
          excluding: !visible,
          child: Theme(
            data: theme,
            child: Material(
              key: surfaceKey,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: top,
                bottom: !top,
                minimum: top
                    ? EdgeInsets.only(top: stableInsets?.top ?? 0)
                    : EdgeInsets.only(bottom: stableInsets?.bottom ?? 0),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.contentMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: top
                          ? SizedBox(
                              height: AppLayout.minTouchTarget,
                              child: child,
                            )
                          : child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderChromeProgress extends StatelessWidget {
  const _ReaderChromeProgress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: SizedBox(
            width: 56,
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: fraction,
                color: colors.primary,
                backgroundColor: colors.onSurface.withValues(alpha: 0.18),
                minHeight: 2,
                borderRadius: const BorderRadius.all(Radius.circular(1)),
                stopIndicatorRadius: 0,
                trackGap: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          flex: 2,
          child: Text(
            formatReadingPercentage(fraction * 100, l10n.localeName),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ReaderProgressState {
  final double fraction;
  final BookLocation? location;

  const _ReaderProgressState({required this.fraction, this.location});
}

class _ReaderChapterLabel extends StatelessWidget {
  const _ReaderChapterLabel({
    required this.chapter,
    required this.style,
    required this.paper,
  });

  final ValueListenable<TOCItem?> chapter;
  final TextStyle style;
  final Color paper;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.7,
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ValueListenableBuilder<TOCItem?>(
                  valueListenable: chapter,
                  builder: (context, item, _) {
                    if (item == null) return const SizedBox.shrink();
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: paper,
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Text(
                          item.title,
                          key: const ValueKey('reader-current-chapter'),
                          textAlign: TextAlign.right,
                          style: style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
