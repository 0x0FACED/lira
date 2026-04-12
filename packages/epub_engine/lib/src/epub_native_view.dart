import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show SelectedContent, SelectedContentRange;
import 'package:flutter/services.dart';

import 'epub_parser.dart';
import 'models/reader_settings.dart';
import 'models/epub_location.dart';
import 'xhtml_parser.dart';

/// A single page of content in horizontal pagination mode.
class _PageInfo {
  final int chapterIndex;
  final int pageIndex;
  final List<ContentElement> elements;
  final bool isChapterStart;

  const _PageInfo({
    required this.chapterIndex,
    required this.pageIndex,
    required this.elements,
    required this.isChapterStart,
  });
}

class _SelectionScopeData {
  final SelectionListenerNotifier notifier;
  int chapterIndex;
  List<ContentElement> elements;

  _SelectionScopeData({
    required this.notifier,
    required this.chapterIndex,
    required this.elements,
  });
}

/// Native Flutter EPUB reader view — no WebView.
///
/// Renders chapters as Flutter widgets using [XhtmlParser].
/// Supports vertical scroll and horizontal pagination modes.
class EpubNativeView extends StatefulWidget {
  final ParsedEpub epub;
  final EpubLocation? initialLocation;
  final ReaderSettings settings;
  final ThemeData theme;
  final void Function(EpubLocation location, double percentage)?
  onLocationChanged;
  final void Function(String text, String location)? onTextSelected;
  final VoidCallback? onCenterTapped;
  final List<Map<String, dynamic>> highlights;

  const EpubNativeView({
    super.key,
    required this.epub,
    this.initialLocation,
    required this.settings,
    required this.theme,
    this.onLocationChanged,
    this.onTextSelected,
    this.onCenterTapped,
    this.highlights = const [],
  });

  @override
  State<EpubNativeView> createState() => EpubNativeViewState();
}

class EpubNativeViewState extends State<EpubNativeView> {
  static const double _leftTapZoneFraction = 0.15;
  static const double _rightTapZoneStart = 0.85;
  static const double _trackpadPageThreshold = 280;
  static const Duration _trackpadIdleReset = Duration(milliseconds: 300);
  static const Duration _trackpadLockDuration = Duration(milliseconds: 400);
  static const Duration _doubleTapWindow = Duration(milliseconds: 280);
  static const double _doubleTapDistance = 24;

  // Parsed content per chapter (lazy, cached)
  final Map<int, List<ContentElement>> _parsedChapters = {};

  // Scroll controller for vertical mode
  final ScrollController _scrollController = ScrollController();
  final Map<String, _SelectionScopeData> _selectionScopes = {};

  // Horizontal mode pagination state
  List<_PageInfo> _paginatedPages = [];
  int _currentPageIndex = 0;
  bool _isDualPage = false;
  Size? _lastPaginationSize;

  // Available page height for constraining images in horizontal mode
  double _currentPageHeight = 0;

  // Tap/swipe detection via raw pointer events (bypasses gesture arena)
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  Offset? _lastTapPos;
  DateTime? _lastTapTime;
  PointerDeviceKind? _pointerDownKind;
  double _touchHorizontalDragDx = 0;

  // Trackpad two-finger scroll accumulator for page turns
  double _scrollAccumulator = 0;
  DateTime? _lastScrollTime;
  DateTime? _lastTrackpadPageTurnTime;

  bool _didRestoreInitialLocation = false;
  bool _hasActiveSelection = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    if (widget.epub.chapters.isNotEmpty) {
      _parseChapter(0);
    }
  }

  @override
  void didUpdateWidget(covariant EpubNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings ||
        oldWidget.epub != widget.epub) {
      _parsedChapters.clear();
      _paginatedPages.clear();
      _lastPaginationSize = null;
      for (final scope in _selectionScopes.values) {
        scope.notifier.dispose();
      }
      _selectionScopes.clear();
    }
    if (oldWidget.epub != widget.epub ||
        oldWidget.initialLocation?.toJson() !=
            widget.initialLocation?.toJson()) {
      _didRestoreInitialLocation = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final scope in _selectionScopes.values) {
      scope.notifier.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Raw pointer detection (taps + swipes — bypasses gesture arena)
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    _pointerDownPos = e.localPosition;
    _pointerDownTime = DateTime.now();
    _pointerDownKind = e.kind;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_pointerDownPos == null || _pointerDownTime == null) return;

    if (widget.settings.readingMode == ReadingMode.horizontal &&
        _isTouchPointer(_pointerDownKind)) {
      final delta = e.localPosition - _pointerDownPos!;
      final dist = delta.distance;
      final dur = DateTime.now().difference(_pointerDownTime!);

      if (dist < 20 && dur.inMilliseconds < 300) {
        final isRepeatedTap = _isRepeatedTap(e.localPosition);
        _lastTapPos = e.localPosition;
        _lastTapTime = DateTime.now();

        if (!isRepeatedTap && !_hasActiveSelection) {
          _handleTap(e.localPosition);
        }
      }

      _pointerDownPos = null;
      _pointerDownTime = null;
      _pointerDownKind = null;
      return;
    }

    final delta = e.localPosition - _pointerDownPos!;
    final dist = delta.distance;
    final dur = DateTime.now().difference(_pointerDownTime!);

    if (dist < 20 && dur.inMilliseconds < 300) {
      final isRepeatedTap = _isRepeatedTap(e.localPosition);
      _lastTapPos = e.localPosition;
      _lastTapTime = DateTime.now();

      if (!isRepeatedTap && !_hasActiveSelection) {
        _handleTap(e.localPosition);
      }
    } else if (widget.settings.readingMode == ReadingMode.horizontal &&
        delta.dx.abs() > 50 &&
        delta.dx.abs() > delta.dy.abs() * 1.5 &&
        dur.inMilliseconds < 700) {
      // Horizontal swipe (> 50px, mostly horizontal, < 700ms)
      if (delta.dx < 0) {
        _prevPage();
      } else {
        _nextPage();
      }
    }

    _pointerDownPos = null;
    _pointerDownTime = null;
    _pointerDownKind = null;
  }

  bool _isRepeatedTap(Offset currentTapPos) {
    if (_lastTapPos == null || _lastTapTime == null) {
      return false;
    }

    final tapDistance = (currentTapPos - _lastTapPos!).distance;
    final tapAge = DateTime.now().difference(_lastTapTime!);
    return tapDistance <= _doubleTapDistance && tapAge <= _doubleTapWindow;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (widget.settings.readingMode != ReadingMode.horizontal) return;
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      _consumeTrackpadDelta(delta);
    }
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (widget.settings.readingMode != ReadingMode.horizontal) return;
    final delta = event.panDelta.dx.abs() > event.panDelta.dy.abs()
        ? event.panDelta.dx
        : event.panDelta.dy;
    _consumeTrackpadDelta(delta);
  }

  void _consumeTrackpadDelta(double delta) {
    final now = DateTime.now();
    if (_lastScrollTime != null &&
        now.difference(_lastScrollTime!) > _trackpadIdleReset) {
      _scrollAccumulator = 0;
    }
    _lastScrollTime = now;

    if (_lastTrackpadPageTurnTime != null &&
        now.difference(_lastTrackpadPageTurnTime!) < _trackpadLockDuration) {
      return;
    }

    _scrollAccumulator += delta;
    if (_scrollAccumulator.abs() < _trackpadPageThreshold) {
      return;
    }

    final direction = _scrollAccumulator > 0 ? 1 : -1;
    _scrollAccumulator = 0;
    _lastTrackpadPageTurnTime = now;
    if (direction > 0) {
      _prevPage();
    } else {
      _nextPage();
    }
  }

  void _handleTap(Offset localPos) {
    if (widget.settings.readingMode == ReadingMode.vertical) {
      widget.onCenterTapped?.call();
      return;
    }

    // Horizontal mode: left 15% → prev, center 70% → toggle UI, right 15% → next
    final width = context.size?.width ?? 1;
    final x = localPos.dx;

    if (x < width * _leftTapZoneFraction) {
      _prevPage();
    } else if (x > width * _rightTapZoneStart) {
      _nextPage();
    } else {
      widget.onCenterTapped?.call();
    }
  }

  void _onTouchHorizontalDragStart(DragStartDetails details) {
    _touchHorizontalDragDx = 0;
  }

  void _onTouchHorizontalDragUpdate(DragUpdateDetails details) {
    _touchHorizontalDragDx += details.delta.dx;
  }

  void _onTouchHorizontalDragEnd(DragEndDetails details) {
    final velocityDx = details.velocity.pixelsPerSecond.dx;
    final totalDx = _touchHorizontalDragDx;
    _touchHorizontalDragDx = 0;

    if (totalDx.abs() <= 50 && velocityDx.abs() <= 500) {
      return;
    }

    if (totalDx < 0 || velocityDx < -500) {
      _nextPage();
    } else {
      _prevPage();
    }
  }

  bool _isTouchPointer(PointerDeviceKind? kind) {
    return kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  // ---------------------------------------------------------------------------
  // Scroll & progress
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (widget.settings.readingMode != ReadingMode.vertical) return;
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    final bookFraction = max > 0 ? (offset / max).clamp(0.0, 1.0) : 0.0;
    final location = _locationFromBookFraction(
      bookFraction,
    ).copyWith(bookScrollOffset: offset, bookScrollFraction: bookFraction);
    widget.onLocationChanged?.call(location, bookFraction * 100);
  }

  void _handleSelectionChanged(SelectedContent? content) {
    final selectedText = content?.plainText.trim() ?? '';
    _hasActiveSelection = selectedText.isNotEmpty;
    if (selectedText.isEmpty) {
      widget.onTextSelected?.call('', '');
      return;
    }

    final resolvedSelection = _resolveSelectionRange();
    if (resolvedSelection == null) {
      _hasActiveSelection = false;
      widget.onTextSelected?.call('', '');
      return;
    }

    final chapterIndex = resolvedSelection.chapterIndex;
    final startOffset = resolvedSelection.startOffset;
    final endOffset = resolvedSelection.endOffset;
    final chapterWeight = _chapterWeight(chapterIndex);
    final scrollFraction = chapterWeight > 0
        ? (startOffset / chapterWeight).clamp(0.0, 1.0)
        : 0.0;

    final location = EpubLocation.fromPosition(
      chapterIndex: chapterIndex,
      charOffset: startOffset,
      scrollFraction: scrollFraction,
      bookScrollOffset:
          widget.settings.readingMode == ReadingMode.vertical &&
              _scrollController.hasClients
          ? _scrollController.offset
          : null,
      bookScrollFraction:
          widget.settings.readingMode == ReadingMode.vertical &&
              _scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > 0
          ? (_scrollController.offset /
                    _scrollController.position.maxScrollExtent)
                .clamp(0.0, 1.0)
          : null,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    widget.onTextSelected?.call(selectedText, location.toJson());
  }

  void _reportProgress() {
    if (widget.onLocationChanged == null) return;

    if (widget.settings.readingMode == ReadingMode.vertical) {
      _onScroll();
      return;
    }

    if (_paginatedPages.isEmpty) return;
    final idx = _currentPageIndex.clamp(0, _paginatedPages.length - 1);
    final page = _paginatedPages[idx];
    final chapterIndex = page.chapterIndex;
    final chapterPages = _chapterPageIndexes(chapterIndex);
    final pageInChapter = chapterPages.indexOf(idx);
    final chapterFraction = chapterPages.length > 1 && pageInChapter >= 0
        ? pageInChapter / (chapterPages.length - 1)
        : 0.0;
    final chapterWeight = _chapterWeight(chapterIndex);
    final location = EpubLocation.fromPosition(
      chapterIndex: chapterIndex,
      charOffset: (chapterWeight * chapterFraction).round(),
      scrollFraction: chapterFraction,
    );
    final percentage =
        (_computeBookFraction(chapterIndex, chapterFraction) * 100).clamp(
          0.0,
          100.0,
        );

    widget.onLocationChanged!(location, percentage);
  }

  int _chapterWeight(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= widget.epub.chapters.length) {
      return 0;
    }
    return widget.epub.chapters[chapterIndex].htmlContent.length;
  }

  double _extractChapterFraction(EpubLocation location) {
    if (location.scrollFraction > 0) {
      return location.scrollFraction.clamp(0.0, 1.0);
    }
    final chapterWeight = _chapterWeight(location.chapterIndex);
    if (chapterWeight <= 0) return 0.0;
    return (location.charOffset / chapterWeight).clamp(0.0, 1.0);
  }

  double _computeBookFraction(int chapterIndex, double chapterFraction) {
    final chapterWeights = widget.epub.chapters
        .map((chapter) => chapter.htmlContent.length)
        .toList();
    final totalWeight = chapterWeights.fold<int>(
      0,
      (sum, weight) => sum + weight,
    );
    if (totalWeight <= 0) return 0.0;

    var priorWeight = 0;
    for (
      int index = 0;
      index < chapterIndex && index < chapterWeights.length;
      index++
    ) {
      priorWeight += chapterWeights[index];
    }

    final currentWeight =
        chapterIndex >= 0 && chapterIndex < chapterWeights.length
        ? chapterWeights[chapterIndex]
        : 0;
    final absoluteWeight =
        priorWeight + currentWeight * chapterFraction.clamp(0.0, 1.0);
    return (absoluteWeight / totalWeight).clamp(0.0, 1.0);
  }

  EpubLocation _locationFromBookFraction(double bookFraction) {
    final clampedFraction = bookFraction.clamp(0.0, 1.0);
    final chapterWeights = widget.epub.chapters
        .map((chapter) => chapter.htmlContent.length)
        .toList();
    final totalWeight = chapterWeights.fold<int>(
      0,
      (sum, weight) => sum + weight,
    );

    if (chapterWeights.isEmpty || totalWeight <= 0) {
      return EpubLocation.fromPosition(chapterIndex: 0);
    }

    final absoluteWeight = totalWeight * clampedFraction;
    var accumulatedWeight = 0;

    for (int index = 0; index < chapterWeights.length; index++) {
      final chapterWeight = chapterWeights[index];
      final chapterEnd = accumulatedWeight + chapterWeight;
      final isLastChapter = index == chapterWeights.length - 1;

      if (absoluteWeight <= chapterEnd || isLastChapter) {
        final weightInsideChapter = (absoluteWeight - accumulatedWeight).clamp(
          0.0,
          chapterWeight.toDouble(),
        );
        final chapterFraction = chapterWeight > 0
            ? (weightInsideChapter / chapterWeight).clamp(0.0, 1.0)
            : 0.0;
        return EpubLocation.fromPosition(
          chapterIndex: index,
          charOffset: weightInsideChapter.round(),
          scrollFraction: chapterFraction,
        );
      }

      accumulatedWeight = chapterEnd;
    }

    final lastIndex = chapterWeights.length - 1;
    return EpubLocation.fromPosition(
      chapterIndex: lastIndex,
      charOffset: chapterWeights[lastIndex],
      scrollFraction: 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  void _parseChapter(int index) {
    if (_parsedChapters.containsKey(index)) return;
    if (index < 0 || index >= widget.epub.chapters.length) return;

    final chapter = widget.epub.chapters[index];

    final baseStyle = TextStyle(
      fontFamily: widget.settings.fontFamily,
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeight,
      color: _computeTextColor(widget.settings.backgroundColor),
    );

    final parser = XhtmlParser(
      html: chapter.htmlContent,
      images: widget.epub.images,
      highlights: const [],
      baseStyle: baseStyle,
      lineHeight: widget.settings.lineHeight,
    );

    _parsedChapters[index] = parser.parse();
  }

  Color _computeTextColor(int bgColor) {
    final color = Color(bgColor);
    return color.computeLuminance() > 0.5
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE0E0E0);
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void scrollToChapter(String fileName) {
    final index = _findChapterIndex(fileName);
    if (index == null) return;
    _jumpToLocation(EpubLocation.fromPosition(chapterIndex: index));
  }

  void goToLocation(EpubLocation location) {
    _jumpToLocation(location);
  }

  void _jumpToLocation(EpubLocation location) {
    if (widget.settings.readingMode == ReadingMode.vertical) {
      _jumpToVerticalLocation(location);
      return;
    }

    _jumpToHorizontalLocation(location);
  }

  void _jumpToVerticalLocation(EpubLocation location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScrollExtent = _scrollController.position.maxScrollExtent;

      double targetOffset;
      if (location.bookScrollOffset != null) {
        targetOffset = location.bookScrollOffset!;
      } else {
        final targetBookFraction =
            location.bookScrollFraction ??
            _computeBookFraction(
              location.chapterIndex,
              _extractChapterFraction(location),
            );
        targetOffset = maxScrollExtent * targetBookFraction.clamp(0.0, 1.0);
      }

      targetOffset = targetOffset.clamp(0.0, maxScrollExtent);
      _scrollController.jumpTo(targetOffset);
      _onScroll();
    });
  }

  void _jumpToHorizontalLocation(EpubLocation location) {
    if (_paginatedPages.isEmpty) return;

    final chapterIndexes = _chapterPageIndexes(location.chapterIndex);
    if (chapterIndexes.isEmpty) return;

    final chapterFraction = _extractChapterFraction(location);
    final pageOffset = chapterIndexes.length > 1
        ? (chapterFraction * (chapterIndexes.length - 1)).round()
        : 0;
    final targetPageIndex =
        chapterIndexes[pageOffset.clamp(0, chapterIndexes.length - 1)];
    final snappedPageIndex = _isDualPage
        ? (targetPageIndex ~/ 2) * 2
        : targetPageIndex;

    setState(() {
      _currentPageIndex = snappedPageIndex.clamp(0, _paginatedPages.length - 1);
    });
    _reportProgress();
  }

  List<int> _chapterPageIndexes(int chapterIndex) {
    final result = <int>[];
    for (int index = 0; index < _paginatedPages.length; index++) {
      if (_paginatedPages[index].chapterIndex == chapterIndex) {
        result.add(index);
      }
    }
    return result;
  }

  void _restoreInitialLocationIfNeeded() {
    if (_didRestoreInitialLocation) return;

    final initialLocation = widget.initialLocation;
    if (initialLocation == null) {
      _didRestoreInitialLocation = true;
      return;
    }

    if (widget.settings.readingMode == ReadingMode.vertical) {
      if (!_scrollController.hasClients) {
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final targetOffset = initialLocation.bookScrollOffset;
      final targetBookFraction =
          initialLocation.bookScrollFraction ??
          _computeBookFraction(
            initialLocation.chapterIndex,
            _extractChapterFraction(initialLocation),
          );
      if ((targetOffset != null && targetOffset > 0 && maxScrollExtent <= 0) ||
          (targetOffset == null &&
              targetBookFraction > 0 &&
              maxScrollExtent <= 0)) {
        return;
      }
    }

    if (widget.settings.readingMode == ReadingMode.horizontal &&
        _paginatedPages.isEmpty) {
      return;
    }

    _didRestoreInitialLocation = true;
    _jumpToLocation(initialLocation);
  }

  int? _findChapterIndex(String fileName) {
    var target = fileName;
    while (target.startsWith('.') || target.startsWith('/')) {
      target = target.substring(1);
    }
    target = target.split('#').first;

    for (int i = 0; i < widget.epub.chapters.length; i++) {
      var current = widget.epub.chapters[i].fileName;
      while (current.startsWith('.') || current.startsWith('/')) {
        current = current.substring(1);
      }
      if (current == target ||
          current.endsWith(target) ||
          target.endsWith(current)) {
        return i;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Horizontal mode: page navigation
  // ---------------------------------------------------------------------------

  void _nextPage() {
    final step = _isDualPage ? 2 : 1;
    final maxIdx = _paginatedPages.length - 1;
    if (maxIdx < 0) return;
    final newIdx = math.min(_currentPageIndex + step, maxIdx);
    final snapped = _isDualPage ? (newIdx ~/ 2) * 2 : newIdx;
    if (snapped != _currentPageIndex) {
      setState(() {
        _currentPageIndex = snapped;
      });
      _reportProgress();
    }
  }

  void _prevPage() {
    final step = _isDualPage ? 2 : 1;
    final newIdx = math.max(_currentPageIndex - step, 0);
    final snapped = _isDualPage ? (newIdx ~/ 2) * 2 : newIdx;
    if (snapped != _currentPageIndex) {
      setState(() {
        _currentPageIndex = snapped;
      });
      _reportProgress();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _nextPage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _prevPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------------

  void _paginate(double pageWidth, double pageHeight, double paddingH) {
    final size = Size(pageWidth, pageHeight);
    if (_lastPaginationSize == size && _paginatedPages.isNotEmpty) return;

    // Remember position to restore
    int? prevChapter;
    double prevFraction = 0;
    if (_paginatedPages.isNotEmpty &&
        _currentPageIndex < _paginatedPages.length) {
      final curPage = _paginatedPages[_currentPageIndex];
      prevChapter = curPage.chapterIndex;
      final chapterStartIdx = _paginatedPages.indexWhere(
        (p) => p.chapterIndex == prevChapter,
      );
      final chapterPageCount = _paginatedPages
          .where((p) => p.chapterIndex == prevChapter)
          .length;
      final pageInChapter = _currentPageIndex - chapterStartIdx;
      prevFraction = chapterPageCount > 1
          ? pageInChapter / (chapterPageCount - 1)
          : 0;
    }

    final stalePageScopeIds = _selectionScopes.keys
        .where((key) => key.startsWith('page_'))
        .toList(growable: false);
    for (final scopeId in stalePageScopeIds) {
      _selectionScopes.remove(scopeId)?.notifier.dispose();
    }

    _paginatedPages = [];
    final contentWidth = pageWidth - paddingH * 2;
    final contentInsets = _contentInsets();
    final contentHeight =
        (pageHeight - contentInsets.vertical) *
        0.92; // extra headroom for exact layout

    var pageIndexCounter = 0;
    for (int ci = 0; ci < widget.epub.chapters.length; ci++) {
      _parseChapter(ci);
      final elements = _parsedChapters[ci] ?? [];

      var currentElements = <ContentElement>[];
      var currentHeight = 0.0;
      var isFirst = true;

      for (final rawElement in elements) {
        final paginatedElements = _splitElementForPagination(
          rawElement,
          contentWidth,
          contentHeight,
        );

        for (final element in paginatedElements) {
          final h = _measureElementHeight(element, contentWidth, pageHeight);

          if (currentElements.isNotEmpty && currentHeight + h > contentHeight) {
            _paginatedPages.add(
              _PageInfo(
                chapterIndex: ci,
                pageIndex: pageIndexCounter++,
                elements: currentElements,
                isChapterStart: isFirst,
              ),
            );
            isFirst = false;
            currentElements = [element];
            currentHeight = h;
          } else {
            currentElements.add(element);
            currentHeight += h;
          }
        }
      }

      if (currentElements.isNotEmpty) {
        _paginatedPages.add(
          _PageInfo(
            chapterIndex: ci,
            pageIndex: pageIndexCounter++,
            elements: currentElements,
            isChapterStart: isFirst,
          ),
        );
      }
    }

    // Restore reading position
    if (prevChapter != null && _paginatedPages.isNotEmpty) {
      final chapterStartIdx = _paginatedPages.indexWhere(
        (p) => p.chapterIndex == prevChapter,
      );
      if (chapterStartIdx >= 0) {
        final chapterPageCount = _paginatedPages
            .where((p) => p.chapterIndex == prevChapter)
            .length;
        _currentPageIndex =
            chapterStartIdx + (prevFraction * (chapterPageCount - 1)).round();
        _currentPageIndex = _currentPageIndex.clamp(
          0,
          _paginatedPages.length - 1,
        );
      }
    }

    _lastPaginationSize = size;
  }

  double _measureElementHeight(
    ContentElement element,
    double contentWidth,
    double pageHeight,
  ) {
    if (element is TextBlock) {
      return _measureTextBlockHeight(element, contentWidth);
    } else if (element is ImageBlock) {
      return (pageHeight - 72) * 0.85 + 24;
    } else if (element is DividerBlock) {
      return 49.0;
    }
    return 0;
  }

  List<ContentElement> _splitElementForPagination(
    ContentElement element,
    double contentWidth,
    double contentHeight,
  ) {
    if (element is! TextBlock) {
      return [element];
    }

    if (_measureTextBlockHeight(element, contentWidth) <= contentHeight) {
      return [element];
    }

    return _splitTextBlockForPagination(element, contentWidth, contentHeight);
  }

  List<TextBlock> _splitTextBlockForPagination(
    TextBlock block,
    double contentWidth,
    double contentHeight,
  ) {
    if (block.span is! TextSpan) {
      return [block];
    }

    final plainText = block.span.toPlainText(includeSemanticsLabels: false);
    final totalLength = plainText.length;
    if (totalLength <= 1) {
      return [block];
    }

    final chunks = <TextBlock>[];
    var localStart = 0;

    while (localStart < totalLength) {
      var low = localStart + 1;
      var high = totalLength;
      var bestEnd = low;

      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final candidateSpan = _sliceInlineSpan(block.span, localStart, mid);
        if (candidateSpan == null) {
          high = mid - 1;
          continue;
        }

        final candidateHeight = _measureTextBlockHeight(
          block,
          contentWidth,
          overrideSpan: candidateSpan,
        );
        if (candidateHeight <= contentHeight) {
          bestEnd = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      if (bestEnd <= localStart) {
        bestEnd = math.min(localStart + 1, totalLength);
      }

      bestEnd = _snapChunkEndToWordBoundary(
        plainText: plainText,
        block: block,
        start: localStart,
        end: bestEnd,
        totalLength: totalLength,
        contentWidth: contentWidth,
        contentHeight: contentHeight,
      );

      final chunkSpan = _sliceInlineSpan(block.span, localStart, bestEnd);
      if (chunkSpan == null) {
        break;
      }

      chunks.add(
        TextBlock(
          span: chunkSpan,
          type: block.type,
          listIndex: block.listIndex,
          charStart: block.charStart + localStart,
          charEnd: block.charStart + bestEnd,
        ),
      );
      localStart = bestEnd;
    }

    return chunks.isEmpty ? [block] : chunks;
  }

  int _snapChunkEndToWordBoundary({
    required String plainText,
    required TextBlock block,
    required int start,
    required int end,
    required int totalLength,
    required double contentWidth,
    required double contentHeight,
  }) {
    if (end >= totalLength) {
      return totalLength;
    }

    final minEnd = start + math.max(1, ((end - start) * 0.6).round());
    for (int candidate = end; candidate > minEnd; candidate--) {
      if (!_isChunkBoundaryChar(plainText[candidate - 1])) {
        continue;
      }

      final candidateSpan = _sliceInlineSpan(block.span, start, candidate);
      if (candidateSpan == null) {
        continue;
      }

      if (_measureTextBlockHeight(
            block,
            contentWidth,
            overrideSpan: candidateSpan,
          ) <=
          contentHeight) {
        return candidate;
      }
    }

    return end;
  }

  bool _isChunkBoundaryChar(String char) {
    return RegExp(r'[\s\.\,\!\?\:\;\)\]\}]').hasMatch(char);
  }

  double _measureTextBlockHeight(
    TextBlock block,
    double contentWidth, {
    InlineSpan? overrideSpan,
  }) {
    final span = overrideSpan ?? block.span;
    if (span is! TextSpan) {
      return 24.0;
    }

    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: contentWidth);
    final textHeight = tp.height;
    tp.dispose();

    final topPad = block.type == TextBlockType.h1 ? 24.0 : 4.0;
    final bottomPad = block.type == TextBlockType.paragraph ? 12.0 : 8.0;
    return textHeight + topPad + bottomPad;
  }

  InlineSpan? _sliceInlineSpan(InlineSpan span, int start, int end) {
    if (start >= end || span is! TextSpan) {
      return null;
    }

    final text = span.text ?? '';
    final hasChildren = span.children != null && span.children!.isNotEmpty;

    if (!hasChildren) {
      final clampedStart = start.clamp(0, text.length).toInt();
      final clampedEnd = end.clamp(0, text.length).toInt();
      if (clampedStart >= clampedEnd) {
        return null;
      }

      return TextSpan(
        text: text.substring(clampedStart, clampedEnd),
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }

    final children = <InlineSpan>[];
    var offset = 0;

    if (text.isNotEmpty) {
      final textStart = start.clamp(0, text.length).toInt();
      final textEnd = end.clamp(0, text.length).toInt();
      if (textStart < textEnd) {
        children.add(
          TextSpan(
            text: text.substring(textStart, textEnd),
            style: span.style,
            recognizer: span.recognizer,
            mouseCursor: span.mouseCursor,
            onEnter: span.onEnter,
            onExit: span.onExit,
            locale: span.locale,
            spellOut: span.spellOut,
          ),
        );
      }
      offset = text.length;
    }

    for (final child in span.children!) {
      final childLength = _inlineSpanLength(child);
      final childStart = math.max(0, start - offset);
      final childEnd = math.min(childLength, end - offset);

      if (childStart < childEnd) {
        final slicedChild = _sliceInlineSpan(child, childStart, childEnd);
        if (slicedChild != null) {
          children.add(slicedChild);
        }
      }

      offset += childLength;
      if (offset >= end) {
        break;
      }
    }

    if (children.isEmpty) {
      return null;
    }

    return TextSpan(
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      locale: span.locale,
      spellOut: span.spellOut,
      children: children,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.settings.readingMode == ReadingMode.horizontal) {
          for (int i = 0; i < widget.epub.chapters.length; i++) {
            _parseChapter(i);
          }
        }

        final paddingH = widget.settings.horizontalPadding;
        final content = Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerSignal: _onPointerSignal,
          onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
          child: Container(
            color: Color(widget.settings.backgroundColor),
            child: widget.settings.readingMode == ReadingMode.vertical
                ? _buildVerticalMode(paddingH, constraints)
                : _buildHorizontalMode(paddingH, constraints),
          ),
        );

        if (widget.settings.readingMode == ReadingMode.horizontal) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
            onHorizontalDragStart: _onTouchHorizontalDragStart,
            onHorizontalDragUpdate: _onTouchHorizontalDragUpdate,
            onHorizontalDragEnd: _onTouchHorizontalDragEnd,
            child: content,
          );
        }

        return content;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Vertical mode
  // ---------------------------------------------------------------------------

  Widget _buildVerticalMode(double paddingH, BoxConstraints constraints) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreInitialLocationIfNeeded();
    });

    final availableWidth = constraints.maxWidth;
    final contentInsets = _contentInsets();

    // Cap at comfortable reading width — no jump, text simply stops expanding
    final maxContentWidth = math.min(availableWidth, 800.0);

    return Center(
      child: SizedBox(
        width: maxContentWidth,
        child: _buildSelectionArea(
          onSelectionChanged: _handleSelectionChanged,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              paddingH,
              contentInsets.top,
              paddingH,
              contentInsets.bottom,
            ),
            itemCount: widget.epub.chapters.length,
            itemBuilder: (context, index) {
              _parseChapter(index);
              final elements = _parsedChapters[index] ?? [];
              return _buildSelectableScope(
                scopeId: 'chapter_$index',
                chapterIndex: index,
                elements: elements,
                child: _buildChapterContent(elements, index),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Horizontal mode: paginated with optional dual-page spread
  // ---------------------------------------------------------------------------

  Widget _buildHorizontalMode(double paddingH, BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;
    _currentPageHeight = availableHeight;

    final minPageWidth = 400.0;
    final gapFraction = 0.04;
    final gapWidth = availableWidth * gapFraction;
    _isDualPage =
        widget.settings.enableDualPageSpread &&
        (availableWidth - gapWidth) / 2 >= minPageWidth;

    double pageWidth;
    if (_isDualPage) {
      pageWidth = (availableWidth - gapWidth) / 2;
    } else {
      pageWidth = math.min(availableWidth, 800.0);
    }

    _paginate(pageWidth, availableHeight, paddingH);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreInitialLocationIfNeeded();
    });

    if (_paginatedPages.isEmpty) return const SizedBox.shrink();

    _currentPageIndex = _currentPageIndex.clamp(0, _paginatedPages.length - 1);
    if (_isDualPage) {
      _currentPageIndex = (_currentPageIndex ~/ 2) * 2;
    }

    // Build page content wrapped in SelectionArea with unique key per page,
    // so selection state resets on page turn and doesn't conflict during animation.
    Widget pageContent;
    if (_isDualPage) {
      final leftIdx = _currentPageIndex;
      final rightIdx = leftIdx + 1;

      final dividerColor = _computeTextColor(
        widget.settings.backgroundColor,
      ).withAlpha(30);

      pageContent = SizedBox(
        key: ValueKey('sel_spread_$leftIdx'),
        width: availableWidth,
        height: availableHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildPageWidget(_paginatedPages[leftIdx], paddingH),
            ),
            SizedBox(
              width: gapWidth,
              child: Center(
                child: Container(
                  width: 1,
                  height: availableHeight * 0.8,
                  color: dividerColor,
                ),
              ),
            ),
            Expanded(
              child: rightIdx < _paginatedPages.length
                  ? _buildPageWidget(_paginatedPages[rightIdx], paddingH)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    } else {
      pageContent = Align(
        key: ValueKey('sel_page_$_currentPageIndex'),
        alignment: Alignment.center,
        child: SizedBox(
          width: pageWidth,
          height: availableHeight,
          child: _buildPageWidget(_paginatedPages[_currentPageIndex], paddingH),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: pageContent,
      ),
    );
  }

  Widget _buildPageWidget(_PageInfo page, double paddingH) {
    final scopeId = 'page_${page.pageIndex}';
    final contentInsets = _contentInsets();
    return ClipRect(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          paddingH,
          contentInsets.top,
          paddingH,
          contentInsets.bottom,
        ),
        child: _buildSelectionArea(
          onSelectionChanged: (content) {
            _handleScopedSelectionChanged(
              scopeId: scopeId,
              chapterIndex: page.chapterIndex,
              elements: page.elements,
              content: content,
            );
          },
          child: _buildSelectableScope(
            scopeId: scopeId,
            chapterIndex: page.chapterIndex,
            elements: page.elements,
            child: SingleChildScrollView(
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              child: _buildChapterContent(page.elements, page.chapterIndex),
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _contentInsets() {
    final safeTop = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    return EdgeInsets.only(top: 24 + math.min(safeTop, 12.0), bottom: 24);
  }

  Widget _buildSelectionArea({
    required ValueChanged<SelectedContent?> onSelectionChanged,
    required Widget child,
  }) {
    return SelectionArea(
      onSelectionChanged: onSelectionChanged,
      contextMenuBuilder: (context, selectableRegionState) {
        return const SizedBox.shrink();
      },
      child: child,
    );
  }

  Widget _buildSelectableScope({
    required String scopeId,
    required int chapterIndex,
    required List<ContentElement> elements,
    required Widget child,
  }) {
    final scope = _selectionScopes.putIfAbsent(
      scopeId,
      () => _SelectionScopeData(
        notifier: SelectionListenerNotifier(),
        chapterIndex: chapterIndex,
        elements: elements,
      ),
    );
    scope.chapterIndex = chapterIndex;
    scope.elements = elements;

    return SelectionListener(selectionNotifier: scope.notifier, child: child);
  }

  // ---------------------------------------------------------------------------
  // Content rendering
  // ---------------------------------------------------------------------------

  Widget _buildChapterContent(List<ContentElement> elements, int chapterIndex) {
    if (elements.isEmpty) {
      return Center(
        child: Text(
          'No content available.',
          style: TextStyle(
            color: _computeTextColor(widget.settings.backgroundColor),
          ),
        ),
      );
    }

    final children = <Widget>[];
    for (final element in elements) {
      if (element is TextBlock) {
        children.add(_buildTextBlock(element, chapterIndex));
      } else if (element is ImageBlock) {
        children.add(_buildImageBlock(element));
      } else if (element is DividerBlock) {
        children.add(_buildDividerBlock());
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildTextBlock(TextBlock block, int chapterIndex) {
    final highlightedSpan = _applyHighlightsToSpan(
      block.span,
      block.charStart,
      block.charEnd,
      chapterIndex,
    );

    // Use Text.rich instead of RichText — Text.rich automatically registers
    // with SelectionArea via its build context, enabling text selection.
    // RichText created directly doesn't look up the SelectionRegistrar.
    return Padding(
      padding: EdgeInsets.only(
        bottom: block.type == TextBlockType.paragraph ? 12 : 8,
        top: block.type == TextBlockType.h1 ? 24 : 4,
      ),
      child: Text.rich(
        highlightedSpan is TextSpan ? highlightedSpan : TextSpan(),
        textAlign: block.type == TextBlockType.blockquote
            ? TextAlign.justify
            : TextAlign.start,
        textScaler: TextScaler.noScaling,
      ),
    );
  }

  Widget _buildImageBlock(ImageBlock block) {
    final maxImgHeight = widget.settings.readingMode == ReadingMode.horizontal
        ? (_currentPageHeight - 72) * 0.85
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxImgHeight ?? double.infinity),
        child: Image.memory(block.bytes, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildDividerBlock() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        color: _computeTextColor(widget.settings.backgroundColor).withAlpha(60),
        thickness: 1,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Highlights
  // ---------------------------------------------------------------------------

  InlineSpan _applyHighlightsToSpan(
    InlineSpan span,
    int blockStart,
    int blockEnd,
    int chapterIndex,
  ) {
    final highlightRanges = <HighlightRange>[];
    for (final h in widget.highlights) {
      final hChapterIndex = h['chapterIndex'] as int;
      if (hChapterIndex != chapterIndex) continue;
      highlightRanges.add(
        HighlightRange(
          startOffset: h['startOffset'] as int,
          endOffset: h['endOffset'] as int,
          color: h['color'] as String,
        ),
      );
    }

    final relevant = highlightRanges
        .where((h) => h.startOffset < blockEnd && h.endOffset > blockStart)
        .toList();

    if (relevant.isEmpty) return span;

    if (span is! TextSpan) return span;

    return _highlightTextSpan(span, blockStart, relevant);
  }

  Color? _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    return null;
  }

  void _handleScopedSelectionChanged({
    required String scopeId,
    required int chapterIndex,
    required List<ContentElement> elements,
    required SelectedContent? content,
  }) {
    final selectedText = content?.plainText.trim() ?? '';
    _hasActiveSelection = selectedText.isNotEmpty;

    if (selectedText.isEmpty) {
      widget.onTextSelected?.call('', '');
      return;
    }

    final scope = _selectionScopes[scopeId];
    final range = scope?.notifier.registered == true
        ? scope!.notifier.selection.range
        : null;
    if (range == null) {
      widget.onTextSelected?.call('', '');
      return;
    }

    final offsets = _mapSelectionRangeToChapterOffsets(elements, range);
    if (offsets == null) {
      widget.onTextSelected?.call('', '');
      return;
    }

    final chapterWeight = _chapterWeight(chapterIndex);
    final startOffset = offsets.$1;
    final endOffset = offsets.$2;
    final scrollFraction = chapterWeight > 0
        ? (startOffset / chapterWeight).clamp(0.0, 1.0)
        : 0.0;

    final location = EpubLocation.fromPosition(
      chapterIndex: chapterIndex,
      charOffset: startOffset,
      scrollFraction: scrollFraction,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    widget.onTextSelected?.call(selectedText, location.toJson());
  }

  InlineSpan _highlightTextSpan(
    TextSpan span,
    int spanStartOffset,
    List<HighlightRange> highlightRanges,
  ) {
    final segmentChildren = <InlineSpan>[];
    var cursor = spanStartOffset;

    final spanText = span.text;
    if (spanText != null && spanText.isNotEmpty) {
      segmentChildren.addAll(
        _splitTextByHighlights(
          text: spanText,
          textStartOffset: cursor,
          style: span.style,
          highlightRanges: highlightRanges,
        ),
      );
      cursor += spanText.length;
    }

    if (span.children != null && span.children!.isNotEmpty) {
      for (final child in span.children!) {
        final childLength = _inlineSpanLength(child);
        if (childLength == 0) continue;

        if (child is TextSpan) {
          segmentChildren.add(
            _highlightTextSpan(child, cursor, highlightRanges),
          );
        } else {
          segmentChildren.add(child);
        }
        cursor += childLength;
      }
    }

    if (segmentChildren.isEmpty) {
      return span;
    }

    return TextSpan(
      style: span.style,
      locale: span.locale,
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
      spellOut: span.spellOut,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      children: segmentChildren,
    );
  }

  List<InlineSpan> _splitTextByHighlights({
    required String text,
    required int textStartOffset,
    required TextStyle? style,
    required List<HighlightRange> highlightRanges,
  }) {
    final textEndOffset = textStartOffset + text.length;
    final segments = <InlineSpan>[];
    final relevantRanges =
        highlightRanges
            .where(
              (range) =>
                  range.startOffset < textEndOffset &&
                  range.endOffset > textStartOffset,
            )
            .toList()
          ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    if (relevantRanges.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    var cursor = textStartOffset;
    for (final range in relevantRanges) {
      final segmentStart = math.max(range.startOffset, textStartOffset);
      final segmentEnd = math.min(range.endOffset, textEndOffset);
      if (segmentEnd <= segmentStart) continue;

      if (cursor < segmentStart) {
        segments.add(
          TextSpan(
            text: text.substring(
              cursor - textStartOffset,
              segmentStart - textStartOffset,
            ),
            style: style,
          ),
        );
      }

      final highlightColor = _parseColor(range.color)?.withAlpha(90);
      segments.add(
        TextSpan(
          text: text.substring(
            segmentStart - textStartOffset,
            segmentEnd - textStartOffset,
          ),
          style: highlightColor == null
              ? style
              : (style ?? const TextStyle()).copyWith(
                  backgroundColor: highlightColor,
                ),
        ),
      );
      cursor = segmentEnd;
    }

    if (cursor < textEndOffset) {
      segments.add(
        TextSpan(text: text.substring(cursor - textStartOffset), style: style),
      );
    }

    return segments;
  }

  int _inlineSpanLength(InlineSpan span) {
    if (span is TextSpan) {
      final ownLength = span.text?.length ?? 0;
      final childrenLength =
          span.children?.fold<int>(
            0,
            (sum, child) => sum + _inlineSpanLength(child),
          ) ??
          0;
      return ownLength + childrenLength;
    }
    return 1;
  }

  ({int chapterIndex, int startOffset, int endOffset})?
  _resolveSelectionRange() {
    for (final scope in _selectionScopes.values) {
      if (!scope.notifier.registered) continue;

      final range = scope.notifier.selection.range;
      if (range == null) continue;

      final offsets = _mapSelectionRangeToChapterOffsets(scope.elements, range);
      if (offsets == null) continue;

      return (
        chapterIndex: scope.chapterIndex,
        startOffset: offsets.$1,
        endOffset: offsets.$2,
      );
    }
    return null;
  }

  (int, int)? _mapSelectionRangeToChapterOffsets(
    List<ContentElement> elements,
    SelectedContentRange range,
  ) {
    final textBlocks = elements.whereType<TextBlock>().toList(growable: false);
    if (textBlocks.isEmpty) return null;

    final startOffset = _mapLocalOffsetToChapterOffset(
      range.startOffset,
      textBlocks,
    );
    final endOffset = _mapLocalOffsetToChapterOffset(
      range.endOffset,
      textBlocks,
    );

    return (math.min(startOffset, endOffset), math.max(startOffset, endOffset));
  }

  int _mapLocalOffsetToChapterOffset(
    int localOffset,
    List<TextBlock> textBlocks,
  ) {
    var accumulatedLength = 0;

    for (int index = 0; index < textBlocks.length; index++) {
      final block = textBlocks[index];
      final blockLength = math.max(0, block.charEnd - block.charStart);
      final blockEnd = accumulatedLength + blockLength;

      if (localOffset < blockEnd) {
        return block.charStart + (localOffset - accumulatedLength);
      }

      if (localOffset == blockEnd) {
        if (index == textBlocks.length - 1) {
          return block.charEnd;
        }
        return textBlocks[index + 1].charStart;
      }

      accumulatedLength = blockEnd;
    }

    return textBlocks.last.charEnd;
  }
}
