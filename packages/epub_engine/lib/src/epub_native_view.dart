import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show MatrixUtils, RenderObject, RenderParagraph, RenderRepaintBoundary, Selectable, SelectionRegistrar, SelectedContent, SelectedContentRange, SelectionEdgeUpdateEvent, SelectionEvent, SelectionEventType, SelectionResult, ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

import 'epub_parser.dart';
import 'epub_paths.dart';
import 'models/reader_settings.dart';
import 'models/epub_location.dart';
import 'page_curl.dart';
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

  int get charStart => elements.first.charStart;
  int get charEnd => elements.last.charEnd;
}

class _TableLayout {
  final double width;
  final double imageExtent;
  final List<double> rowOffsets;

  const _TableLayout(this.width, this.imageExtent, this.rowOffsets);

  double get height => rowOffsets.last;
}

/// Positioned cells still copy/select in XHTML order, not geometric order.
class _SourceOrderSelectionDelegate extends StaticSelectionContainerDelegate {
  final Map<Selectable, (int, int)> _order = {};
  int _nextOrder = 0;
  final Set<Selectable> _receivedStart = {};
  final Set<Selectable> _receivedEnd = {};
  Offset? _startPosition;
  Offset? _endPosition;
  Selectable? _startTarget;
  Selectable? _endTarget;

  void addAt(Selectable selectable, int offset) {
    _order[selectable] = (offset, _nextOrder++);
    super.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
    super.remove(selectable);
    _order.remove(selectable);
    if (identical(_startTarget, selectable)) _startTarget = null;
    if (identical(_endTarget, selectable)) _endTarget = null;
  }

  @override
  Comparator<Selectable> get compareOrder => (a, b) {
    final first = _order[a]!;
    final second = _order[b]!;
    final offsetOrder = first.$1.compareTo(second.$1);
    return offsetOrder != 0 ? offsetOrder : first.$2.compareTo(second.$2);
  };

  Selectable? _targetAt(Offset position) {
    for (final selectable in selectables) {
      final transform = selectable.getTransformTo(null);
      if (selectable.boundingBoxes.any(
        (box) => MatrixUtils.transformRect(transform, box).contains(position),
      )) {
        return selectable;
      }
    }
    return null;
  }

  @override
  void updateLastSelectionEdgeLocation({
    required Offset globalSelectionEdgeLocation,
    required bool forEnd,
  }) {
    super.updateLastSelectionEdgeLocation(
      globalSelectionEdgeLocation: globalSelectionEdgeLocation,
      forEnd: forEnd,
    );
    if (forEnd) {
      _endPosition = globalSelectionEdgeLocation;
      _endTarget = _targetAt(globalSelectionEdgeLocation);
    } else {
      _startPosition = globalSelectionEdgeLocation;
      _startTarget = _targetAt(globalSelectionEdgeLocation);
    }
  }

  SelectionEdgeUpdateEvent _eventForChild(
    Selectable selectable,
    SelectionEdgeUpdateEvent event,
  ) {
    final forEnd = event.type == SelectionEventType.endEdgeUpdate;
    final target = forEnd ? _endTarget : _startTarget;
    if (target == null || identical(target, selectable)) return event;
    final boxes = selectable.boundingBoxes;
    if (boxes.isEmpty) return event;
    final bounds = boxes.reduce((a, b) => a.expandToInclude(b));
    // Routing is geometric, but every other fragment's edge is before/after
    // it in XHTML order. Its screen y coordinate need not have that order.
    final local = compareOrder(selectable, target) < 0
        ? bounds.bottomRight + const Offset(1, 1)
        : bounds.topLeft - const Offset(1, 1);
    final global = MatrixUtils.transformPoint(
      selectable.getTransformTo(null),
      local,
    );
    return forEnd
        ? SelectionEdgeUpdateEvent.forEnd(
            globalPosition: global,
            granularity: event.granularity,
          )
        : SelectionEdgeUpdateEvent.forStart(
            globalPosition: global,
            granularity: event.granularity,
          );
  }

  @override
  void didReceiveSelectionEventFor({
    required Selectable selectable,
    bool? forEnd,
  }) {
    super.didReceiveSelectionEventFor(selectable: selectable, forEnd: forEnd);
    if (forEnd != true) _receivedStart.add(selectable);
    if (forEnd != false) _receivedEnd.add(selectable);
  }

  @override
  void clearInternalSelectionStateForSelectable(Selectable selectable) {
    super.clearInternalSelectionStateForSelectable(selectable);
    _receivedStart.remove(selectable);
    _receivedEnd.remove(selectable);
  }

  @override
  void clearInternalSelectionState() {
    super.clearInternalSelectionState();
    _startPosition = _endPosition = null;
    _startTarget = _endTarget = null;
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    if (_endPosition case final position?) {
      if (_receivedEnd.add(selectable)) {
        final event = SelectionEdgeUpdateEvent.forEnd(globalPosition: position);
        if (currentSelectionEndIndex == -1) handleSelectionEdgeUpdate(event);
        selectable.dispatchSelectionEvent(_eventForChild(selectable, event));
      }
    }
    if (_startPosition case final position?) {
      if (_receivedStart.add(selectable)) {
        final event = SelectionEdgeUpdateEvent.forStart(
          globalPosition: position,
        );
        if (currentSelectionStartIndex == -1) handleSelectionEdgeUpdate(event);
        selectable.dispatchSelectionEvent(_eventForChild(selectable, event));
      }
    }
  }

  @override
  SelectionResult dispatchSelectionEventToChild(
    Selectable selectable,
    SelectionEvent event,
  ) {
    final result = super.dispatchSelectionEventToChild(
      selectable,
      event is SelectionEdgeUpdateEvent
          ? _eventForChild(selectable, event)
          : event,
    );
    if (event is SelectionEdgeUpdateEvent) {
      final target = event.type == SelectionEventType.endEdgeUpdate
          ? _endTarget
          : _startTarget;
      // A caret at the first/last glyph can report previous/next. Geometry
      // already identified its cell; don't route that edge into a neighbor.
      if (identical(target, selectable) && result != SelectionResult.pending) {
        return SelectionResult.end;
      }
    }
    return result;
  }
}

class _SourceOrderRegistrar implements SelectionRegistrar {
  final _SourceOrderSelectionDelegate delegate;
  final int offset;

  const _SourceOrderRegistrar(this.delegate, this.offset);

  @override
  void add(Selectable selectable) => delegate.addAt(selectable, offset);

  @override
  void remove(Selectable selectable) => delegate.remove(selectable);
}

class _SelectionScopeData {
  final SelectionListenerNotifier notifier;
  int chapterIndex;
  List<ContentElement> elements;
  final Map<int, GlobalKey> textKeys = {};
  final Map<int, GlobalKey> imageKeys = {};
  final Map<int, GlobalKey> elementKeys = {};
  final Map<int, int> textEnds = {};
  final selectionDelegate = _SourceOrderSelectionDelegate();
  ScrollController? pageScrollController;
  GlobalKey? pageScrollKey;

  _SelectionScopeData({
    required this.notifier,
    required this.chapterIndex,
    required this.elements,
  });
}

/// Render keys and selection notifiers belong to each mounted chapter/page,
/// independently of other copies in the lazy list or page-turn destination.
class _MountedContentScope extends StatefulWidget {
  final int chapterIndex;
  final List<ContentElement> elements;
  final ValueChanged<_SelectionScopeData> onMount;
  final ValueChanged<_SelectionScopeData> onUnmount;
  final Widget Function(_SelectionScopeData) builder;

  const _MountedContentScope({
    required this.chapterIndex,
    required this.elements,
    required this.onMount,
    required this.onUnmount,
    required this.builder,
  });

  @override
  State<_MountedContentScope> createState() => _MountedContentScopeState();
}

class _MountedContentScopeState extends State<_MountedContentScope> {
  late final _SelectionScopeData scope;

  @override
  void initState() {
    super.initState();
    scope = _SelectionScopeData(
      notifier: SelectionListenerNotifier(),
      chapterIndex: widget.chapterIndex,
      elements: widget.elements,
    );
    widget.onMount(scope);
  }

  @override
  void didUpdateWidget(covariant _MountedContentScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterIndex != widget.chapterIndex ||
        !identical(oldWidget.elements, widget.elements)) {
      scope.textKeys.clear();
      scope.elementKeys.clear();
      scope.imageKeys.clear();
      scope.textEnds.clear();
    }
    scope.chapterIndex = widget.chapterIndex;
    scope.elements = widget.elements;
  }

  @override
  void dispose() {
    widget.onUnmount(scope);
    scope.notifier.dispose();
    scope.selectionDelegate.dispose();
    scope.pageScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(scope);
}

class _RasterImageData {
  final MemoryImage provider;
  ImageStream? stream;
  ImageStreamListener? listener;
  double? aspectRatio;
  bool layoutPending = false;

  _RasterImageData(Uint8List bytes) : provider = MemoryImage(bytes);

  void stopListening() {
    final listener = this.listener;
    if (listener != null) stream?.removeListener(listener);
    this.listener = null;
    stream = null;
  }
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

class EpubNativeViewState extends State<EpubNativeView>
    with SingleTickerProviderStateMixin {
  static const double _leftTapZoneFraction = 0.15;
  static const double _rightTapZoneStart = 0.85;
  static const double _trackpadPageThreshold = 280;
  static const Duration _trackpadIdleReset = Duration(milliseconds: 300);
  static const Duration _trackpadLockDuration = Duration(milliseconds: 400);
  static const Duration _doubleTapWindow = Duration(milliseconds: 280);
  static const double _doubleTapDistance = 24;

  // Parsed content per chapter (lazy, cached)
  final Map<int, List<ContentElement>> _parsedChapters = {};
  final Map<TableBlock, _TableLayout> _tableLayouts = {};
  final Map<Uint8List, _RasterImageData> _rasterImages = Map.identity();
  bool _imageLayoutScheduled = false;

  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, List<HighlightRange>> _highlightsByChapter = {};
  List<int>? _bookOffsets;
  final Map<int, Map<String, int>> _chapterAnchors = {};
  final Map<int, List<ContentLink>> _chapterLinks = {};
  final Set<_SelectionScopeData> _selectionScopes = {};

  // Horizontal mode pagination state
  List<_PageInfo> _paginatedPages = [];
  int _currentPageIndex = 0;
  bool _isDualPage = false;
  (Size, EdgeInsets)? _lastPaginationGeometry;
  final GlobalKey _pageBoundaryKey = GlobalKey();
  final GlobalKey _destinationBoundaryKey = GlobalKey();
  late final AnimationController _pageTurnController;
  ui.Image? _pageTurnImage;
  ui.Image? _pageTurnDestinationImage;
  int? _pageTurnTargetIndex;
  bool _pageTurnForward = true;
  bool _pageTurnDragging = false;
  bool _acceptPageDrag = false;
  double _pageTurnVerticalBias = 0.65;
  Size? _lastViewportSize;
  EpubLocation? _logicalLocation;
  EpubLocation? _pendingRestore;
  bool _restoreScheduled = false;
  bool _scrollReportScheduled = false;
  bool _verticalUserScroll = false;
  ContentLink? _pointerDownLink;
  int? _pointerDownLinkChapter;

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

  int _layoutGeneration = 0;
  bool _hasActiveSelection = false;

  @override
  void initState() {
    super.initState();
    _pageTurnController = AnimationController(vsync: this);
    _pendingRestore =
        widget.initialLocation ??
        EpubLocation.fromPosition(chapterIndex: 0, hasExactCharOffset: true);
    _readHighlights();

    if (widget.epub.chapters.isNotEmpty) {
      _parseChapter(0);
    }
  }

  @override
  void didUpdateWidget(covariant EpubNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.highlights, widget.highlights)) _readHighlights();
    final needsReparse =
        oldWidget.epub != widget.epub ||
        oldWidget.settings.fontFamily != widget.settings.fontFamily ||
        oldWidget.settings.fontSize != widget.settings.fontSize ||
        oldWidget.settings.lineHeight != widget.settings.lineHeight ||
        oldWidget.settings.backgroundColor != widget.settings.backgroundColor;
    final needsRepagination =
        needsReparse ||
        oldWidget.epub != widget.epub ||
        oldWidget.settings.horizontalPadding !=
            widget.settings.horizontalPadding ||
        oldWidget.settings.readingMode != widget.settings.readingMode ||
        oldWidget.settings.enableDualPageSpread !=
            widget.settings.enableDualPageSpread;

    if (oldWidget.epub != widget.epub) {
      for (final image in _rasterImages.values) {
        image.stopListening();
      }
      _rasterImages.clear();
      _bookOffsets = null;
      _logicalLocation = null;
      _pendingRestore =
          widget.initialLocation ??
          EpubLocation.fromPosition(chapterIndex: 0, hasExactCharOffset: true);
      _chapterAnchors.clear();
      _chapterLinks.clear();
    } else if (needsRepagination) {
      _pendingRestore ??= _captureLocation(oldWidget.settings.readingMode);
    }
    if (needsReparse) {
      _parsedChapters.clear();
      _chapterAnchors.clear();
      _chapterLinks.clear();
    }
    if (needsRepagination) {
      _clearPageTurn();
      _hasActiveSelection = false;
      _tableLayouts.clear();
      _paginatedPages.clear();
      _lastPaginationGeometry = null;
      _layoutGeneration++;
    }
  }

  @override
  void dispose() {
    _pageTurnController.dispose();
    _pageTurnImage?.dispose();
    _pageTurnDestinationImage?.dispose();
    for (final image in _rasterImages.values) {
      image.stopListening();
    }
    super.dispose();
  }

  void _readHighlights() {
    _highlightsByChapter.clear();
    for (final highlight in widget.highlights) {
      final chapter = highlight['chapterIndex'] as int;
      (_highlightsByChapter[chapter] ??= []).add(
        HighlightRange(
          startOffset: highlight['startOffset'] as int,
          endOffset: highlight['endOffset'] as int,
          color: highlight['color'] as String,
        ),
      );
    }
  }

  RenderParagraph? _paragraphForKey(GlobalKey? key) {
    final root = key?.currentContext?.findRenderObject();
    RenderParagraph? paragraph;
    void visit(RenderObject render) {
      if (paragraph != null) return;
      if (render is RenderParagraph) {
        paragraph = render;
      } else {
        render.visitChildren(visit);
      }
    }

    if (root != null) visit(root);
    return paragraph;
  }

  // ---------------------------------------------------------------------------
  // Raw pointer detection (taps + swipes — bypasses gesture arena)
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    if (_pageTurnImage != null) return;
    _pointerDownPos = e.localPosition;
    _pointerDownTime = DateTime.now();
    _pointerDownKind = e.kind;
    _pointerDownLink = null;
    _pointerDownLinkChapter = null;
    for (final scope in _selectionScopes) {
      for (final entry in scope.textKeys.entries) {
        final render = _paragraphForKey(entry.value);
        if (render == null || !render.hasSize || !render.attached) continue;
        final local = render.globalToLocal(e.position);
        if (!(Offset.zero & render.size).contains(local)) continue;
        final blockStart = entry.key;
        final blockEnd = scope.textEnds[blockStart]!;
        for (final link
            in _chapterLinks[scope.chapterIndex] ?? const <ContentLink>[]) {
          final start = math.max(link.startOffset, blockStart);
          final end = math.min(link.endOffset, blockEnd);
          if (start >= end) continue;
          final boxes = render.getBoxesForSelection(
            TextSelection(
              baseOffset: start - blockStart,
              extentOffset: end - blockStart,
            ),
          );
          if (boxes.any((box) => box.toRect().contains(local))) {
            _pointerDownLink = link;
            _pointerDownLinkChapter = scope.chapterIndex;
            return;
          }
        }
      }
      for (final leaf in contentLeaves(
        scope.elements,
      ).whereType<ImageBlock>()) {
        final render = scope.imageKeys[leaf.charStart]?.currentContext
            ?.findRenderObject();
        if (render is! RenderBox || !render.hasSize || !render.attached) {
          continue;
        }
        final ratio = _imageAspectRatio(leaf, painted: true);
        final fitted = ratio == null
            ? render.size
            : applyBoxFit(
                BoxFit.contain,
                Size(ratio, 1),
                render.size,
              ).destination;
        final painted = Alignment.center.inscribe(
          fitted,
          Offset.zero & render.size,
        );
        if (!painted.contains(render.globalToLocal(e.position))) continue;
        for (final link
            in _chapterLinks[scope.chapterIndex] ?? const <ContentLink>[]) {
          if (link.startOffset < leaf.charEnd &&
              link.endOffset > leaf.charStart) {
            _pointerDownLink = link;
            _pointerDownLinkChapter = scope.chapterIndex;
            return;
          }
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_pointerDownPos == null || _pointerDownTime == null) return;
    final link = _pointerDownLink;
    if (link != null) {
      final chapterIndex = _pointerDownLinkChapter!;
      final isTap =
          (e.localPosition - _pointerDownPos!).distance < 20 &&
          DateTime.now().difference(_pointerDownTime!).inMilliseconds < 300;
      _pointerDownPos = null;
      _pointerDownTime = null;
      _pointerDownKind = null;
      _pointerDownLink = null;
      _pointerDownLinkChapter = null;
      if (isTap && !_hasActiveSelection) _openLink(link.href, chapterIndex);
      return;
    }

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
      if (event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs() &&
          _scrollablePageAt(event.position)) {
        return;
      }
      final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      _consumeTrackpadDelta(delta);
    }
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (widget.settings.readingMode != ReadingMode.horizontal) return;
    if (event.panDelta.dy.abs() >= event.panDelta.dx.abs() &&
        _scrollablePageAt(event.position)) {
      return;
    }
    final delta = event.panDelta.dx.abs() > event.panDelta.dy.abs()
        ? event.panDelta.dx
        : event.panDelta.dy;
    _consumeTrackpadDelta(delta);
  }

  bool _scrollablePageAt(Offset position) {
    for (final scope in _selectionScopes) {
      final controller = scope.pageScrollController;
      final render = scope.pageScrollKey?.currentContext?.findRenderObject();
      if (controller == null ||
          !controller.hasClients ||
          controller.position.maxScrollExtent <= 0 ||
          render is! RenderBox) {
        continue;
      }
      if ((Offset.zero & render.size).contains(
        render.globalToLocal(position),
      )) {
        return true;
      }
    }
    return false;
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
    _acceptPageDrag =
        _pageTurnImage == null &&
        !_hasActiveSelection &&
        _pendingRestore == null;
    _pageTurnDragging = _acceptPageDrag;
  }

  void _onTouchHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_acceptPageDrag) return;
    _touchHorizontalDragDx += details.delta.dx;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final forward = _touchHorizontalDragDx < 0;
    if (_pageTurnImage == null && !_beginPageTurn(forward)) return;
    if (forward != _pageTurnForward) {
      final target = _adjacentPageIndex(forward);
      if (target != _currentPageIndex) {
        final oldDestination = _pageTurnDestinationImage;
        setState(() {
          _pageTurnForward = forward;
          _pageTurnTargetIndex = target;
          _pageTurnDestinationImage = null;
        });
        if (oldDestination != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => oldDestination.dispose(),
          );
        }
        if (_isDualPage) _captureTurnDestination();
      }
    }
    final directedDx = _pageTurnForward
        ? -_touchHorizontalDragDx
        : _touchHorizontalDragDx;
    final width = _lastViewportSize?.width ?? 1;
    _pageTurnController.value = (directedDx / width).clamp(0.0, 1.0);
  }

  void _onTouchHorizontalDragEnd(DragEndDetails details) {
    if (!_acceptPageDrag) return;
    _acceptPageDrag = false;
    _pageTurnDragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final totalDx = _touchHorizontalDragDx;
    _touchHorizontalDragDx = 0;
    if (_pageTurnImage == null) {
      final width = _lastViewportSize?.width ?? 1;
      if (totalDx.abs() >= width * 0.28 || velocity.abs() >= 600) {
        _requestPageTurn(velocity.abs() >= 600 ? velocity < 0 : totalDx < 0);
      }
      return;
    }
    final directedVelocity = _pageTurnForward ? -velocity : velocity;
    final complete = directedVelocity.abs() >= 600
        ? directedVelocity > 0
        : _pageTurnController.value >= 0.28;
    _settlePageTurn(complete);
  }

  void _onTouchHorizontalDragCancel() {
    _acceptPageDrag = false;
    _touchHorizontalDragDx = 0;
    if (!_pageTurnDragging) return;
    _pageTurnDragging = false;
    if (_pageTurnImage != null) _settlePageTurn(false);
  }

  bool _isTouchPointer(PointerDeviceKind? kind) {
    return kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  // ---------------------------------------------------------------------------
  // Scroll & progress
  // ---------------------------------------------------------------------------

  bool _onVerticalScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _verticalUserScroll = true;
    } else if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _verticalUserScroll = true;
    } else if (notification is ScrollEndNotification) {
      _verticalUserScroll = false;
    }
    // A remounted short book can spring back to its physical scroll bounds.
    // That layout correction must not replace an explicit navigation target.
    if (notification is ScrollUpdateNotification && _verticalUserScroll) {
      _onScroll();
    }
    return false;
  }

  void _onScroll() {
    if (widget.settings.readingMode != ReadingMode.vertical ||
        _pendingRestore != null ||
        _scrollReportScheduled) {
      return;
    }
    // ScrollPosition dispatches updates as soon as pixels change, before the
    // viewport lays out its new offset. Read glyph positions after that layout,
    // coalescing all drag/ballistic updates in the same frame.
    final generation = _layoutGeneration;
    _scrollReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollReportScheduled = false;
      if (!mounted ||
          generation != _layoutGeneration ||
          widget.settings.readingMode != ReadingMode.vertical ||
          _pendingRestore != null) {
        return;
      }
      _logicalLocation = _captureVerticalLocation() ?? _logicalLocation;
      _reportProgress();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onHorizontalPageScroll(_SelectionScopeData scope) {
    if (widget.settings.readingMode != ReadingMode.horizontal ||
        _pageTurnImage != null ||
        _pendingRestore != null ||
        _scrollReportScheduled) {
      return;
    }
    final generation = _layoutGeneration;
    _scrollReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollReportScheduled = false;
      if (!mounted ||
          generation != _layoutGeneration ||
          !_selectionScopes.contains(scope) ||
          widget.settings.readingMode != ReadingMode.horizontal ||
          _pageTurnImage != null ||
          _pendingRestore != null) {
        return;
      }
      final viewport = scope.pageScrollKey?.currentContext?.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final top = viewport.localToGlobal(Offset.zero).dy;
      _logicalLocation =
          _captureVisibleLocation([scope], top, top + viewport.size.height) ??
          _logicalLocation;
      _reportProgress();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  EpubLocation _captureLocation(ReadingMode mode) {
    if (_logicalLocation != null) return _logicalLocation!;
    if (mode == ReadingMode.vertical) {
      return _captureVerticalLocation() ??
          EpubLocation.fromPosition(chapterIndex: 0, hasExactCharOffset: true);
    }
    if (_paginatedPages.isEmpty) {
      return widget.initialLocation ??
          EpubLocation.fromPosition(chapterIndex: 0, hasExactCharOffset: true);
    }
    final page =
        _paginatedPages[_currentPageIndex.clamp(0, _paginatedPages.length - 1)];
    return EpubLocation.fromPosition(
      hasExactCharOffset: true,
      chapterIndex: page.chapterIndex,
      charOffset: page.charStart,
    );
  }

  EpubLocation? _captureVerticalLocation() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final top = viewport.localToGlobal(Offset.zero).dy + _contentInsets().top;
    final bottom =
        viewport.localToGlobal(Offset.zero).dy + viewport.size.height;
    return _captureVisibleLocation(_selectionScopes, top, bottom);
  }

  EpubLocation? _captureVisibleLocation(
    Iterable<_SelectionScopeData> scopes,
    double top,
    double bottom,
  ) {
    _SelectionScopeData? firstScope;
    int? firstStart;
    var firstTop = double.infinity;
    for (final scope in scopes) {
      for (final entry in scope.elementKeys.entries) {
        final render = entry.value.currentContext?.findRenderObject();
        if (render is! RenderBox || !render.hasSize || !render.attached)
          continue;
        final y = render.localToGlobal(Offset.zero).dy;
        if (y + render.size.height <= top || y >= bottom || y >= firstTop) {
          continue;
        }
        firstScope = scope;
        firstStart = entry.key;
        firstTop = y;
      }
    }
    if (firstScope == null || firstStart == null) return null;
    final paragraph = _paragraphForKey(firstScope.textKeys[firstStart]);
    final position = paragraph != null
        ? paragraph
              .getPositionForOffset(
                Offset(
                  0,
                  math.max(0.0, top - paragraph.localToGlobal(Offset.zero).dy),
                ),
              )
              .offset
        : 0;
    return EpubLocation.fromPosition(
      hasExactCharOffset: true,
      chapterIndex: firstScope.chapterIndex,
      charOffset: firstStart + position,
    );
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
      hasExactCharOffset: true,
      chapterIndex: chapterIndex,
      charOffset: startOffset,
      scrollFraction: scrollFraction,
      bookScrollOffset: null,
      bookScrollFraction: null,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    widget.onTextSelected?.call(selectedText, location.toJson());
  }

  void _reportProgress() {
    final location = _logicalLocation;
    if (location == null) return;
    final weight = _chapterWeight(location.chapterIndex);
    final fraction = weight > 0
        ? (location.charOffset / weight).clamp(0.0, 1.0)
        : 0.0;
    widget.onLocationChanged?.call(
      location.copyWith(scrollFraction: fraction),
      _computeBookFraction(location.chapterIndex, fraction) * 100,
    );
  }

  int _chapterWeight(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= widget.epub.chapters.length) {
      return 0;
    }
    _parseChapter(chapterIndex);
    final elements = _parsedChapters[chapterIndex]!;
    return elements.isEmpty ? 0 : elements.last.charEnd;
  }

  int _locationCharOffset(EpubLocation location) {
    _parseChapter(location.chapterIndex);
    final anchorOffset =
        _chapterAnchors[location.chapterIndex]?[location.anchor];
    if (anchorOffset != null) return anchorOffset;
    final length = _chapterWeight(location.chapterIndex);
    if (location.hasExactCharOffset) {
      return location.charOffset.clamp(0, length);
    }
    if (location.startOffset != null && location.endOffset != null) {
      return location.startOffset!.clamp(0, length);
    }
    if (location.scrollFraction > 0) {
      return (location.scrollFraction.clamp(0.0, 1.0) * length).round();
    }
    final htmlLength =
        widget.epub.chapters[location.chapterIndex].htmlContent.length;
    return htmlLength > 0
        ? ((location.charOffset / htmlLength).clamp(0.0, 1.0) * length).round()
        : 0;
  }

  List<int> get _contentBookOffsets {
    if (_bookOffsets case final offsets?) return offsets;
    final offsets = <int>[0];
    for (var chapter = 0; chapter < widget.epub.chapters.length; chapter++) {
      offsets.add(offsets.last + _chapterWeight(chapter));
    }
    return _bookOffsets = offsets;
  }

  double _computeBookFraction(int chapterIndex, double chapterFraction) {
    final offsets = _contentBookOffsets;
    if (offsets.last == 0 ||
        chapterIndex < 0 ||
        chapterIndex + 1 >= offsets.length)
      return 0;
    final weight = offsets[chapterIndex + 1] - offsets[chapterIndex];
    return ((offsets[chapterIndex] + weight * chapterFraction.clamp(0.0, 1.0)) /
            offsets.last)
        .clamp(0.0, 1.0);
  }

  EpubLocation _resolveLegacyFraction(EpubLocation location) {
    if (location.hasExactCharOffset || location.cfi.hasRange) return location;
    if (location.chapterIndex != 0 ||
        location.anchor != null ||
        location.charOffset != 0 ||
        location.scrollFraction != 0 ||
        location.bookScrollOffset != null ||
        (location.bookScrollFraction ?? 0) <= 0)
      return location;
    final offsets = _contentBookOffsets;
    final absolute =
        (offsets.last * location.bookScrollFraction!.clamp(0.0, 1.0)).round();
    for (var chapter = 0; chapter + 1 < offsets.length; chapter++) {
      if (absolute < offsets[chapter + 1] || chapter + 2 == offsets.length) {
        return EpubLocation.fromPosition(
          hasExactCharOffset: true,
          chapterIndex: chapter,
          charOffset: absolute - offsets[chapter],
        );
      }
    }
    return location;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  TextStyle get _baseTextStyle => TextStyle(
    inherit: false,
    fontFamily: widget.settings.fontFamily,
    fontSize: widget.settings.fontSize,
    height: widget.settings.lineHeight,
    color: _computeTextColor(widget.settings.backgroundColor),
  );

  void _parseChapter(int index) {
    if (_parsedChapters.containsKey(index)) return;
    if (index < 0 || index >= widget.epub.chapters.length) return;

    final chapter = widget.epub.chapters[index];

    final baseStyle = _baseTextStyle;

    final parser = XhtmlParser(
      html: chapter.htmlContent,
      images: widget.epub.images,
      documentPath: chapter.fileName,
      stylesheets: widget.epub.stylesheets,
      highlights: const [],
      baseStyle: baseStyle,
    );

    _parsedChapters[index] = parser.parse();
    _chapterAnchors[index] = Map.of(parser.anchors);
    _chapterLinks[index] = List.of(parser.links);
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
    final location = _locationFromLocator(fileName);
    if (location == null) return;
    _jumpToLocation(location);
  }

  void goToLocation(EpubLocation location) {
    _jumpToLocation(location);
  }

  void _jumpToLocation(EpubLocation location) {
    _clearPageTurn();
    _pendingRestore = location;
    setState(() {
      _layoutGeneration++;
    });
    _scheduleRestore();
  }

  int? _pageIndexForLocation(EpubLocation location) {
    final offset = _locationCharOffset(location);
    int? last;
    for (var index = 0; index < _paginatedPages.length; index++) {
      final page = _paginatedPages[index];
      if (page.chapterIndex != location.chapterIndex) continue;
      last = index;
      if (offset < page.charEnd || offset <= page.charStart) return index;
    }
    if (last != null) return last;
    final following = _paginatedPages.indexWhere(
      (page) => page.chapterIndex > location.chapterIndex,
    );
    if (following >= 0) return following;
    return _paginatedPages.isEmpty ? null : _paginatedPages.length - 1;
  }

  EpubLocation _restoreTarget(EpubLocation location) {
    final resolved = _resolveLegacyFraction(location);
    final chapter = resolved.chapterIndex.clamp(
      0,
      widget.epub.chapters.length - 1,
    );
    return EpubLocation.fromPosition(
      hasExactCharOffset: true,
      chapterIndex: chapter,
      anchor: resolved.anchor,
      charOffset: _locationCharOffset(resolved.copyWith(chapterIndex: chapter)),
    );
  }

  double? _legacyPixelOffset(EpubLocation location) {
    if (!location.hasExactCharOffset &&
        !location.cfi.hasRange &&
        location.chapterIndex == 0 &&
        location.anchor == null &&
        location.charOffset == 0 &&
        location.scrollFraction == 0 &&
        (location.bookScrollOffset ?? 0) > 0) {
      return location.bookScrollOffset;
    }
    return null;
  }

  void _scheduleRestore() {
    if (_pendingRestore == null || _restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted || _pendingRestore == null) return;
      final location = _pendingRestore!;
      if (widget.epub.chapters.isEmpty) {
        _pendingRestore = null;
        return;
      }
      final target = _restoreTarget(location);
      if (widget.settings.readingMode == ReadingMode.horizontal) {
        final page = _pageIndexForLocation(target);
        if (page == null) {
          _pendingRestore = null;
          _logicalLocation = target;
          _reportProgress();
          return;
        }
        final displayed = _paginatedPages[page];
        final resolvedTarget = displayed.chapterIndex == target.chapterIndex
            ? target
            : EpubLocation.fromPosition(
                chapterIndex: displayed.chapterIndex,
                charOffset: displayed.charStart,
                hasExactCharOffset: true,
              );
        _pendingRestore = null;
        _logicalLocation = resolvedTarget;
        _reportProgress();
        return;
      }
      // Vertical layout starts at this exact measured chapter/caret in its
      // first frame. There is no visible chapter-zero -> chapter -> pixel
      // scroll sequence, and no intermediate position is published.
      _pendingRestore = null;
      _logicalLocation = _legacyPixelOffset(location) != null
          ? (_captureVerticalLocation() ?? target)
          : target;
      _reportProgress();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  EpubLocation? _locationFromLocator(String locator, {int? fromChapter}) {
    if (widget.epub.chapters.isEmpty) return null;
    final uri = Uri.tryParse(locator);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final source = (fromChapter ?? _logicalLocation?.chapterIndex ?? 0).clamp(
      0,
      widget.epub.chapters.length - 1,
    );
    final path = uri.path;
    int? chapterIndex;
    if (path.isEmpty) {
      chapterIndex = source;
    } else {
      final current = widget.epub.chapters[source].fileName;
      final relative = resolveEpubPath(current, locator);
      final packaged = resolveEpubPath('', locator);
      final candidates = {
        if (fromChapter != null && relative != null) relative,
        if (packaged != null) packaged,
        if (fromChapter == null && relative != null) relative,
      };
      for (final candidate in candidates) {
        final index = widget.epub.chapters.indexWhere(
          (chapter) => normalizeEpubArchivePath(chapter.fileName) == candidate,
        );
        if (index >= 0) {
          chapterIndex = index;
          break;
        }
      }
    }
    if (chapterIndex == null || chapterIndex >= widget.epub.chapters.length) {
      return null;
    }
    _parseChapter(chapterIndex);
    final anchor = uri.hasFragment ? Uri.decodeComponent(uri.fragment) : null;
    return EpubLocation.fromPosition(
      hasExactCharOffset: true,
      chapterIndex: chapterIndex,
      anchor: anchor,
      charOffset: _chapterAnchors[chapterIndex]?[anchor] ?? 0,
    );
  }

  Future<void> _openLink(String href, int chapterIndex) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final location = _locationFromLocator(href, fromChapter: chapterIndex);
    if (location != null && mounted) _jumpToLocation(location);
  }

  // ---------------------------------------------------------------------------
  // Horizontal mode: page navigation
  // ---------------------------------------------------------------------------

  int _adjacentPageIndex(bool forward) {
    if (_paginatedPages.isEmpty) return _currentPageIndex;
    final step = _isDualPage ? 2 : 1;
    final index = (_currentPageIndex + (forward ? step : -step)).clamp(
      0,
      _paginatedPages.length - 1,
    );
    return _isDualPage ? (index ~/ 2) * 2 : index;
  }

  void _nextPage() => _requestPageTurn(true);

  void _prevPage() => _requestPageTurn(false);

  void _commitPageIndex(int index) {
    _currentPageIndex = index;
    final page = _paginatedPages[index];
    _logicalLocation = EpubLocation.fromPosition(
      hasExactCharOffset: true,
      chapterIndex: page.chapterIndex,
      charOffset: page.charStart,
    );
    _hasActiveSelection = false;
  }

  void _requestPageTurn(bool forward) {
    if (widget.settings.readingMode != ReadingMode.horizontal ||
        _pageTurnImage != null ||
        _pendingRestore != null) {
      return;
    }
    final target = _adjacentPageIndex(forward);
    if (target == _currentPageIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _commitPageIndex(target));
      _reportProgress();
    } else if (_beginPageTurn(forward)) {
      _settlePageTurn(true);
    }
  }

  bool _beginPageTurn(bool forward) {
    final target = _adjacentPageIndex(forward);
    if (target == _currentPageIndex || _pendingRestore != null) return false;
    // debugNeedsPaint throws in profile/release; keep it debug-only.
    final boundary = _pageBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.hasSize ||
        (kDebugMode && boundary.debugNeedsPaint)) {
      return false;
    }
    // Snapshot once per turn, never per frame. A spread also captures the
    // destination so its left/right page can be printed on the leaf's back.
    final image = boundary.toImageSync(
      pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 2.0),
    );
    final height = _lastViewportSize?.height ?? 1;
    setState(() {
      _pageTurnImage = image;
      _pageTurnTargetIndex = target;
      _pageTurnForward = forward;
      _pageTurnVerticalBias = ((_pointerDownPos?.dy ?? height * 0.65) / height)
          .clamp(0.0, 1.0);
    });
    _pageTurnController.value = 0;
    if (_isDualPage) _captureTurnDestination();
    return true;
  }

  void _captureTurnDestination() {
    final image = _pageTurnImage;
    final target = _pageTurnTargetIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(image, _pageTurnImage) ||
          target != _pageTurnTargetIndex ||
          _pageTurnDestinationImage != null) {
        return;
      }
      final boundary = _destinationBoundaryKey.currentContext
          ?.findRenderObject();
      if (boundary is! RenderRepaintBoundary ||
          !boundary.hasSize ||
          (kDebugMode && boundary.debugNeedsPaint)) {
        return;
      }
      setState(() {
        _pageTurnDestinationImage = boundary.toImageSync(
          pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 2.0),
        );
      });
    });
  }

  Future<void> _settlePageTurn(bool complete) async {
    final image = _pageTurnImage;
    if (image == null) return;
    final distance = complete
        ? 1 - _pageTurnController.value
        : _pageTurnController.value;
    try {
      await _pageTurnController
          .animateTo(
            complete ? 1 : 0,
            duration: Duration(
              milliseconds: (420 * distance).round().clamp(100, 420),
            ),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || !identical(image, _pageTurnImage)) return;
    final target = _pageTurnTargetIndex!;
    setState(() {
      _clearPageTurn();
      if (complete) _commitPageIndex(target);
    });
    if (complete) _reportProgress();
  }

  // Also called by reflow/navigation: an interrupted preview never saves a
  // destination that the reader has not actually reached.
  void _clearPageTurn() {
    _pageTurnController.stop(canceled: true);
    final image = _pageTurnImage;
    final destination = _pageTurnDestinationImage;
    _pageTurnImage = null;
    _pageTurnDestinationImage = null;
    _pageTurnTargetIndex = null;
    _pageTurnDragging = false;
    _acceptPageDrag = false;
    if (image != null) {
      // The previous painter can remain in the tree until this frame rebuilds.
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
    if (destination != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => destination.dispose(),
      );
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
    if (!pageWidth.isFinite ||
        !pageHeight.isFinite ||
        pageWidth <= 0 ||
        pageHeight <= 0) {
      _lastPaginationGeometry = null;
      return;
    }

    final contentInsets = _contentInsets();
    final geometry = (
      Size(pageWidth, pageHeight),
      EdgeInsets.fromLTRB(
        paddingH,
        contentInsets.top,
        paddingH,
        contentInsets.bottom,
      ),
    );
    if (_lastPaginationGeometry == geometry && _paginatedPages.isNotEmpty) {
      return;
    }

    _pendingRestore ??= _captureLocation(ReadingMode.horizontal);
    _hasActiveSelection = false;

    _paginatedPages = [];
    _tableLayouts.clear();
    final contentWidth = pageWidth - paddingH * 2;
    final contentHeight = pageHeight - contentInsets.vertical;

    if (!contentWidth.isFinite ||
        !contentHeight.isFinite ||
        contentWidth <= 0 ||
        contentHeight <= 0) {
      _lastPaginationGeometry = null;
      return;
    }

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
          final h = _measureElementHeight(element, contentWidth, contentHeight);

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

    _lastPaginationGeometry = geometry;
  }

  double _measureElementHeight(
    ContentElement element,
    double contentWidth,
    double pageHeight, {
    bool inTable = false,
  }) {
    if (element is TextBlock) {
      return _measureTextBlockHeight(element, contentWidth);
    } else if (element is TableBlock) {
      return _layoutTable(element, contentWidth).height;
    } else if (element is ImageBlock) {
      return inTable
          ? _tableImageHeight(element, contentWidth, pageHeight)
          : pageHeight;
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
    if (element is TableBlock) {
      return _splitTableForPagination(element, contentWidth, contentHeight);
    }
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

    final boundaries = <int>[0];
    for (final grapheme in plainText.characters) {
      boundaries.add(boundaries.last + grapheme.length);
    }
    final chunks = <TextBlock>[];
    var boundaryStart = 0;
    while (boundaryStart + 1 < boundaries.length) {
      final localStart = boundaries[boundaryStart];
      var low = boundaryStart + 1;
      var high = boundaries.length - 1;
      var bestBoundary = low;

      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final candidateSpan = _sliceInlineSpan(
          block.span,
          localStart,
          boundaries[mid],
        );
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
          bestBoundary = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      if (bestBoundary < boundaries.length - 1) {
        final minBoundary =
            boundaryStart +
            math.max(1, ((bestBoundary - boundaryStart) * 0.6).round());
        for (var index = bestBoundary; index > minBoundary; index--) {
          if (_isChunkBoundaryChar(plainText[boundaries[index] - 1])) {
            bestBoundary = index;
            break;
          }
        }
      }
      final bestEnd = boundaries[bestBoundary];

      final chunkSpan = _sliceInlineSpan(block.span, localStart, bestEnd)!;
      chunks.add(
        TextBlock(
          span: chunkSpan,
          type: block.type,
          listIndex: block.listIndex,
          indent: block.indent,
          textAlign: block.textAlign,
          margin: block.margin,
          charStart: block.charStart + localStart,
          charEnd: block.charStart + bestEnd,
        ),
      );
      boundaryStart = bestBoundary;
    }

    return chunks.isEmpty ? [block] : chunks;
  }

  bool _isChunkBoundaryChar(String char) {
    return RegExp(r'[\s\.\,\!\?\:\;\)\]\}]').hasMatch(char);
  }

  TextPainter _layoutTextBlock(
    TextBlock block,
    double contentWidth, {
    InlineSpan? overrideSpan,
  }) {
    return TextPainter(
      text: TextSpan(
        style: _baseTextStyle,
        children: [overrideSpan ?? block.span],
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      textHeightBehavior: const TextHeightBehavior(),
      textAlign: block.textAlign,
    )..layout(
      maxWidth: math.max(
        1.0,
        contentWidth - _textBlockInsets(block).horizontal,
      ),
    );
  }

  double _measureTextBlockHeight(
    TextBlock block,
    double contentWidth, {
    InlineSpan? overrideSpan,
  }) {
    final painter = _layoutTextBlock(
      block,
      contentWidth,
      overrideSpan: overrideSpan,
    );
    final height = painter.height + _textBlockInsets(block).vertical;
    painter.dispose();
    return height;
  }

  double _contentOffsetForPosition(
    List<ContentElement> elements,
    int charOffset,
    double contentWidth, {
    double? imageExtent,
  }) {
    var offset = 0.0;
    for (final element in elements) {
      if (charOffset < element.charEnd || identical(element, elements.last)) {
        if (element is TextBlock) {
          final painter = _layoutTextBlock(element, contentWidth);
          final caret = painter.getOffsetForCaret(
            TextPosition(
              offset: (charOffset - element.charStart).clamp(
                0,
                element.charEnd - element.charStart,
              ),
            ),
            Rect.zero,
          );
          painter.dispose();
          return offset + _textBlockInsets(element).top + caret.dy;
        }
        if (element is TableBlock) {
          final layout = _layoutTable(element, contentWidth);
          final columnWidth = layout.width / math.max(1, element.columnCount);
          for (final cell in element.cells) {
            if (cell.elements.isEmpty) continue;
            if (charOffset < cell.elements.last.charEnd ||
                identical(cell, element.cells.last)) {
              return offset +
                  layout.rowOffsets[cell.row] +
                  _tableCellInsets.top +
                  _contentOffsetForPosition(
                    cell.elements,
                    charOffset,
                    math.max(
                      1.0,
                      columnWidth * cell.columnSpan -
                          _tableCellInsets.horizontal,
                    ),
                    imageExtent: layout.imageExtent,
                  );
            }
          }
        }
        return offset;
      }
      if (element is ImageBlock && imageExtent == null) {
        final ratio = _imageAspectRatio(element, forLayout: true);
        // An unresolved raster has no intrinsic extent yet. Its decoded size
        // schedules a fresh anchored layout, just as it does inside tables.
        offset +=
            24 +
            (ratio == null
                ? 0
                : math.max(0.0, contentWidth - element.indent) / ratio);
      } else {
        offset += _measureElementHeight(
          element,
          contentWidth,
          imageExtent ?? 0,
          inTable: imageExtent != null,
        );
      }
    }
    return offset;
  }

  EdgeInsets _textBlockInsets(TextBlock block) {
    final margin =
        block.margin ??
        EdgeInsets.only(
          top: block.type == TextBlockType.h1 ? 24 : 4,
          bottom: block.type == TextBlockType.paragraph ? 12 : 8,
        );
    return margin + EdgeInsets.only(left: block.indent);
  }

  static const _tableCellInsets = EdgeInsets.all(8);

  _TableLayout _layoutTable(TableBlock table, double contentWidth) {
    final width = math.max(1.0, contentWidth - table.indent);
    final imageExtent = widget.settings.readingMode == ReadingMode.horizontal
        ? math.max(24.0, _currentPageHeight - _contentInsets().vertical)
        : width;
    final cached = _tableLayouts[table];
    if (cached != null &&
        cached.width == width &&
        cached.imageExtent == imageExtent) {
      return cached;
    }
    final heights = List<double>.filled(
      table.rowCount,
      _tableCellInsets.vertical,
    );
    final columnWidth = width / math.max(1, table.columnCount);
    final cellHeights = <double>[];
    for (final cell in table.cells) {
      final innerWidth = math.max(
        1.0,
        columnWidth * cell.columnSpan - _tableCellInsets.horizontal,
      );
      var height = _tableCellInsets.vertical;
      for (final element in cell.elements) {
        height += _measureElementHeight(
          element,
          innerWidth,
          imageExtent,
          inTable: true,
        );
      }
      cellHeights.add(height);
      if (cell.rowSpan == 1) {
        heights[cell.row] = math.max(heights[cell.row], height);
      }
    }
    for (var index = 0; index < table.cells.length; index++) {
      final cell = table.cells[index];
      if (cell.rowSpan == 1) continue;
      var available = 0.0;
      for (var row = cell.row; row < cell.row + cell.rowSpan; row++) {
        available += heights[row];
      }
      final extra = (cellHeights[index] - available) / cell.rowSpan;
      if (extra > 0) {
        for (var row = cell.row; row < cell.row + cell.rowSpan; row++) {
          heights[row] += extra;
        }
      }
    }
    final offsets = <double>[0];
    for (final height in heights) {
      offsets.add(offsets.last + height);
    }
    final layout = _TableLayout(width, imageExtent, offsets);
    _tableLayouts[table] = layout;
    return layout;
  }

  List<ContentElement> _splitTableForPagination(
    TableBlock table,
    double contentWidth,
    double contentHeight,
  ) {
    final layout = _layoutTable(table, contentWidth);
    if (layout.height <= contentHeight || table.rowCount == 0) return [table];
    final chunks = <ContentElement>[];
    final rowEnds = List<int>.generate(table.rowCount, (row) => row + 1);
    for (final cell in table.cells) {
      rowEnds[cell.row] = math.max(rowEnds[cell.row], cell.row + cell.rowSpan);
    }
    final cellStarts = List<int>.filled(table.rowCount + 1, 0);
    var nextCell = 0;
    for (var row = 0; row <= table.rowCount; row++) {
      while (nextCell < table.cells.length && table.cells[nextCell].row < row) {
        nextCell++;
      }
      cellStarts[row] = nextCell;
    }
    var chunkStart = 0;
    var groupStart = 0;
    while (groupStart < table.rowCount) {
      var groupEnd = groupStart + 1;
      // Extending the boundary can encounter another spanning cell.
      for (var row = groupStart; row < groupEnd; row++) {
        groupEnd = math.max(groupEnd, rowEnds[row]);
      }
      if (groupStart > chunkStart &&
          layout.rowOffsets[groupEnd] - layout.rowOffsets[chunkStart] >
              contentHeight) {
        chunks.add(
          _tableRowSlice(table, chunkStart, groupStart, layout, cellStarts),
        );
        chunkStart = groupStart;
      }
      groupStart = groupEnd;
    }
    chunks.add(
      _tableRowSlice(table, chunkStart, table.rowCount, layout, cellStarts),
    );
    return chunks;
  }

  TableBlock _tableRowSlice(
    TableBlock table,
    int start,
    int end,
    _TableLayout layout,
    List<int> cellStarts,
  ) {
    final cells = <TableCellContent>[
      for (final cell in table.cells.getRange(
        cellStarts[start],
        cellStarts[end],
      ))
        TableCellContent(
          row: cell.row - start,
          column: cell.column,
          rowSpan: cell.rowSpan,
          columnSpan: cell.columnSpan,
          elements: cell.elements,
        ),
    ];
    ContentElement? first;
    ContentElement? last;
    for (final cell in cells) {
      for (final element in cell.elements) {
        first ??= element;
        last = element;
      }
    }
    final chunk = TableBlock(
      rowCount: end - start,
      columnCount: table.columnCount,
      cells: cells,
      indent: table.indent,
      charStart: first?.charStart ?? table.charStart,
      charEnd: last?.charEnd ?? table.charStart,
    );
    _tableLayouts[chunk] = _TableLayout(layout.width, layout.imageExtent, [
      for (var row = start; row <= end; row++)
        layout.rowOffsets[row] - layout.rowOffsets[start],
    ]);
    return chunk;
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
        final viewportSize = constraints.biggest;
        if (_lastViewportSize != null && _lastViewportSize != viewportSize) {
          _pendingRestore ??= _captureLocation(widget.settings.readingMode);
          _clearPageTurn();
          _hasActiveSelection = false;
          _layoutGeneration++;
        }
        _lastViewportSize = viewportSize;
        if (MediaQuery.disableAnimationsOf(context) && _pageTurnImage != null) {
          _clearPageTurn();
        }
        if (widget.settings.readingMode == ReadingMode.horizontal) {
          for (int i = 0; i < widget.epub.chapters.length; i++) {
            _parseChapter(i);
          }
        }

        final paddingH = widget.settings.horizontalPadding;
        final content = Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) {
            _pointerDownPos = null;
            _pointerDownTime = null;
            _pointerDownKind = null;
            _onTouchHorizontalDragCancel();
          },
          onPointerSignal: _onPointerSignal,
          onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
          child: Container(
            key: _viewportKey,
            color: Color(widget.settings.backgroundColor),
            child: widget.settings.readingMode == ReadingMode.vertical
                ? _buildVerticalMode(paddingH, constraints)
                : _buildHorizontalMode(paddingH, constraints),
          ),
        );

        return content;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Vertical mode
  // ---------------------------------------------------------------------------

  double _effectivePadding(double pageWidth, double requested) {
    final readableWidth = math.min(160.0, pageWidth);
    return requested.clamp(0.0, math.max(0.0, (pageWidth - readableWidth) / 2));
  }

  Widget _buildVerticalMode(double paddingH, BoxConstraints constraints) {
    _scheduleRestore();

    final availableWidth = constraints.maxWidth;
    final contentInsets = _contentInsets();

    // Cap the page, not its content: the margin control still applies inside.
    final maxContentWidth = math.min(availableWidth, 800.0);
    paddingH = _effectivePadding(maxContentWidth, paddingH);
    final pending = _pendingRestore;
    if (pending != null) _verticalUserScroll = false;
    final target = pending == null || widget.epub.chapters.isEmpty
        ? null
        : _restoreTarget(pending);
    final chapter = target?.chapterIndex ?? 0;
    final targetOffset = target == null
        ? 0.0
        : _legacyPixelOffset(pending!) ??
              _contentOffsetForPosition(
                _parsedChapters[chapter]!,
                target.charOffset,
                maxContentWidth - paddingH * 2,
              );
    // PositionedList uses an unbounded anchor, so even a caret several
    // viewports into a chapter can be correct before its first paint.
    final alignment = target == null || constraints.maxHeight <= 0
        ? 0.0
        : (contentInsets.top -
                  targetOffset -
                  (chapter == 0 ? contentInsets.top : 0)) /
              constraints.maxHeight;

    return Center(
      child: SizedBox(
        width: maxContentWidth,
        child: _buildSelectionArea(
          onSelectionChanged: _handleSelectionChanged,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onVerticalScrollNotification,
            child: ScrollablePositionedList.builder(
              // The list prefers PageStorage over initialScrollIndex. Isolate
              // reflow/navigation seeds from the previous mounted position.
              key: PageStorageKey(('vertical', _layoutGeneration)),
              initialScrollIndex: chapter,
              initialAlignment: alignment,
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
                  chapterIndex: index,
                  elements: elements,
                  builder: (scope) =>
                      _buildChapterContent(elements, index, scope),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Horizontal mode: paginated with optional dual-page spread
  // ---------------------------------------------------------------------------

  Widget _buildHorizontalMode(double paddingH, BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight ||
        !constraints.maxWidth.isFinite ||
        !constraints.maxHeight.isFinite ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;
    _currentPageHeight = availableHeight;
    final mediaQuery = MediaQuery.maybeOf(context);
    final shortestSide =
        mediaQuery?.size.shortestSide ??
        math.min(availableWidth, availableHeight);
    final isMobilePhone =
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        shortestSide < 600;

    final minPageWidth = 400.0;
    final gapFraction = 0.04;
    final gapWidth = availableWidth * gapFraction;
    _isDualPage =
        !isMobilePhone &&
        widget.settings.enableDualPageSpread &&
        (availableWidth - gapWidth) / 2 >= minPageWidth;

    double pageWidth;
    if (_isDualPage) {
      pageWidth = (availableWidth - gapWidth) / 2;
    } else {
      pageWidth = math.min(availableWidth, 800.0);
    }

    paddingH = _effectivePadding(pageWidth, paddingH);

    _paginate(pageWidth, availableHeight, paddingH);
    _scheduleRestore();

    if (_paginatedPages.isEmpty) return const SizedBox.shrink();
    final restore = _pendingRestore;
    if (restore != null) {
      final page = _pageIndexForLocation(_restoreTarget(restore));
      if (page != null) {
        _currentPageIndex = _isDualPage ? (page ~/ 2) * 2 : page;
      }
    }

    _currentPageIndex = _currentPageIndex.clamp(0, _paginatedPages.length - 1);
    if (_isDualPage) {
      _currentPageIndex = (_currentPageIndex ~/ 2) * 2;
    }

    final background = Color(widget.settings.backgroundColor);
    final image = _pageTurnImage;
    final target = _pageTurnTargetIndex;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: image != null,
              child: IgnorePointer(
                ignoring: image != null,
                child: RepaintBoundary(
                  key: _pageBoundaryKey,
                  child: ColoredBox(
                    color: background,
                    child: _buildHorizontalPages(
                      _currentPageIndex,
                      paddingH,
                      availableWidth,
                      availableHeight,
                      pageWidth,
                      gapWidth,
                    ),
                  ),
                ),
              ),
            ),
            if (image != null && target != null)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        foregroundPainter: PageCurlPainter(
                          page: image,
                          destinationPage: _pageTurnDestinationImage,
                          progress: _pageTurnController,
                          forward: _pageTurnForward,
                          paperColor: background,
                          dualPage: _isDualPage,
                          verticalBias: _pageTurnVerticalBias,
                        ),
                        child: RepaintBoundary(
                          key: _destinationBoundaryKey,
                          child: ColoredBox(
                            color: background,
                            child: _buildHorizontalPages(
                              target,
                              paddingH,
                              availableWidth,
                              availableHeight,
                              pageWidth,
                              gapWidth,
                            ),
                          ),
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
  }

  Widget _buildHorizontalPages(
    int index,
    double paddingH,
    double availableWidth,
    double availableHeight,
    double pageWidth,
    double gapWidth,
  ) {
    if (_isDualPage) {
      final leftIdx = index;
      final rightIdx = leftIdx + 1;

      final dividerColor = _computeTextColor(
        widget.settings.backgroundColor,
      ).withAlpha(30);

      return SizedBox(
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
      return Align(
        key: ValueKey('sel_page_$index'),
        alignment: Alignment.center,
        child: SizedBox(
          width: pageWidth,
          height: availableHeight,
          child: _buildPageWidget(_paginatedPages[index], paddingH),
        ),
      );
    }
  }

  Widget _buildPageWidget(_PageInfo page, double paddingH) {
    final contentInsets = _contentInsets();
    return ClipRect(
      key: ValueKey((
        _layoutGeneration,
        page.pageIndex,
        _lastPaginationGeometry,
      )),
      child: _buildSelectableScope(
        chapterIndex: page.chapterIndex,
        elements: page.elements,
        ownSelectionArea: true,
        builder: (scope) {
          if (scope.pageScrollController == null) {
            var initialOffset = 0.0;
            final restore = _pendingRestore;
            if (restore != null) {
              final target = _restoreTarget(restore);
              if (target.chapterIndex == page.chapterIndex &&
                  target.charOffset >= page.charStart &&
                  (target.charOffset < page.charEnd ||
                      target.charOffset == _chapterWeight(page.chapterIndex))) {
                final contentHeight =
                    _currentPageHeight - contentInsets.vertical;
                final targetY = _contentOffsetForPosition(
                  page.elements,
                  target.charOffset,
                  _lastPaginationGeometry!.$1.width - paddingH * 2,
                  imageExtent: contentHeight,
                );
                if (targetY >= contentHeight) initialOffset = targetY;
              }
            }
            scope.pageScrollController = ScrollController(
              initialScrollOffset: initialOffset,
            )..addListener(() => _onHorizontalPageScroll(scope));
          }
          scope.pageScrollKey ??= GlobalKey();
          return Padding(
            padding: EdgeInsets.fromLTRB(
              paddingH,
              contentInsets.top,
              paddingH,
              contentInsets.bottom,
            ),
            child: SingleChildScrollView(
              key: scope.pageScrollKey,
              controller: scope.pageScrollController,
              primary: false,
              child: _buildChapterContent(
                page.elements,
                page.chapterIndex,
                scope,
              ),
            ),
          );
        },
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
      // Inside SelectionArea so its touch-drag selection recognizer cannot
      // claim horizontal swipes first. Long press and mouse selection keep
      // their native recognizers; the inner vertical scroll view still wins
      // vertical drags on oversized content.
      child: widget.settings.readingMode == ReadingMode.horizontal
          ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              dragStartBehavior: DragStartBehavior.down,
              supportedDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
              },
              onHorizontalDragStart: _onTouchHorizontalDragStart,
              onHorizontalDragUpdate: _onTouchHorizontalDragUpdate,
              onHorizontalDragEnd: _onTouchHorizontalDragEnd,
              onHorizontalDragCancel: _onTouchHorizontalDragCancel,
              child: child,
            )
          : child,
    );
  }

  Widget _buildSelectableScope({
    required int chapterIndex,
    required List<ContentElement> elements,
    required Widget Function(_SelectionScopeData) builder,
    bool ownSelectionArea = false,
  }) {
    return _MountedContentScope(
      chapterIndex: chapterIndex,
      elements: elements,
      onMount: (scope) {
        _selectionScopes.add(scope);
      },
      onUnmount: (scope) {
        _selectionScopes.remove(scope);
      },
      builder: (scope) {
        final child = SelectionListener(
          selectionNotifier: scope.notifier,
          child: builder(scope),
        );
        return ownSelectionArea
            ? _buildSelectionArea(
                onSelectionChanged: (content) => _handleScopedSelectionChanged(
                  scope: scope,
                  chapterIndex: chapterIndex,
                  elements: elements,
                  content: content,
                ),
                child: child,
              )
            : child;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Content rendering
  // ---------------------------------------------------------------------------

  Widget _buildChapterContent(
    List<ContentElement> elements,
    int chapterIndex,
    _SelectionScopeData scope,
  ) {
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

    return SelectionContainer(
      delegate: scope.selectionDelegate,
      child: _buildElements(elements, chapterIndex, scope),
    );
  }

  Widget _buildElements(
    List<ContentElement> elements,
    int chapterIndex,
    _SelectionScopeData scope, {
    double? imageExtent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final element in elements)
          _buildElement(element, chapterIndex, scope, imageExtent: imageExtent),
      ],
    );
  }

  Widget _buildElement(
    ContentElement element,
    int chapterIndex,
    _SelectionScopeData scope, {
    double? imageExtent,
  }) {
    // A table and its first cell share an offset; only leaves own render keys.
    if (element is TableBlock) {
      return _buildTable(element, chapterIndex, scope);
    }
    final Widget child;
    if (element is TextBlock) {
      child = _buildTextBlock(element, chapterIndex, scope);
    } else if (element is ImageBlock) {
      child = _buildImageBlock(element, scope, imageExtent: imageExtent);
    } else {
      child = _buildDividerBlock();
    }
    return KeyedSubtree(
      key: scope.elementKeys.putIfAbsent(element.charStart, () => GlobalKey()),
      child: child,
    );
  }

  Widget _buildTable(
    TableBlock table,
    int chapterIndex,
    _SelectionScopeData scope,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _layoutTable(table, constraints.maxWidth);
        final columnWidth = layout.width / math.max(1, table.columnCount);
        final borderColor = _computeTextColor(
          widget.settings.backgroundColor,
        ).withAlpha(100);
        return Padding(
          padding: EdgeInsets.only(left: table.indent),
          child: SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final cell in table.cells)
                  Positioned(
                    left: cell.column * columnWidth,
                    top: layout.rowOffsets[cell.row],
                    width: cell.columnSpan * columnWidth,
                    height:
                        layout.rowOffsets[cell.row + cell.rowSpan] -
                        layout.rowOffsets[cell.row],
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 0.5),
                      ),
                      child: Padding(
                        padding: _tableCellInsets,
                        child: _buildElements(
                          cell.elements,
                          chapterIndex,
                          scope,
                          imageExtent: layout.imageExtent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextBlock(
    TextBlock block,
    int chapterIndex,
    _SelectionScopeData scope,
  ) {
    scope.textEnds[block.charStart] = block.charEnd;
    final highlightedSpan = applyHighlightRanges(
      block.span,
      block.charStart,
      _highlightsByChapter[chapterIndex] ?? const [],
    );

    // Use Text.rich instead of RichText — Text.rich automatically registers
    // with SelectionArea via its build context, enabling text selection.
    // RichText created directly doesn't look up the SelectionRegistrar.
    return SelectionRegistrarScope(
      registrar: _SourceOrderRegistrar(
        scope.selectionDelegate,
        block.charStart,
      ),
      child: Padding(
        padding: _textBlockInsets(block),
        child: Text.rich(
          highlightedSpan is TextSpan ? highlightedSpan : const TextSpan(),
          key: scope.textKeys.putIfAbsent(block.charStart, () => GlobalKey()),
          style: _baseTextStyle,
          textDirection: TextDirection.ltr,
          textHeightBehavior: const TextHeightBehavior(),
          textAlign: block.textAlign,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }

  _RasterImageData _rasterImage(ImageBlock block) {
    final cached = _rasterImages[block.bytes];
    if (cached != null) return cached;
    final data = _RasterImageData(block.bytes);
    _rasterImages[block.bytes] = data;
    data.stream = data.provider.resolve(createLocalImageConfiguration(context));
    data.listener = ImageStreamListener(
      (info, synchronousCall) {
        data.aspectRatio = info.image.width / info.image.height;
        info.dispose();
        data.stopListening();
        if (data.layoutPending) _scheduleImageLayout();
      },
      onError: (Object error, StackTrace? stack) {
        data.stopListening();
      },
    );
    data.stream!.addListener(data.listener!);
    return data;
  }

  double? _imageAspectRatio(
    ImageBlock block, {
    bool forLayout = false,
    bool painted = false,
  }) {
    if (block.isSvg || (!painted && block.aspectRatio != null)) {
      return block.aspectRatio;
    }
    final data = _rasterImage(block);
    if (forLayout && data.aspectRatio == null) data.layoutPending = true;
    return data.aspectRatio;
  }

  void _scheduleImageLayout() {
    if (_imageLayoutScheduled || !mounted) return;
    _imageLayoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _imageLayoutScheduled = false;
      if (!mounted) return;
      _pendingRestore ??= _captureLocation(widget.settings.readingMode);
      _clearPageTurn();
      setState(() {
        _tableLayouts.clear();
        _paginatedPages.clear();
        _lastPaginationGeometry = null;
        _hasActiveSelection = false;
        _layoutGeneration++;
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  double _tableImageHeight(
    ImageBlock block,
    double contentWidth,
    double imageExtent,
  ) {
    final ratio = _imageAspectRatio(block, forLayout: true);
    final maxHeight = math.max(0.0, imageExtent - 24);
    return 24 +
        (ratio == null
            ? maxHeight
            : math.min(
                math.max(0.0, contentWidth - block.indent) / ratio,
                maxHeight,
              ));
  }

  Widget _buildImageBlock(
    ImageBlock block,
    _SelectionScopeData scope, {
    double? imageExtent,
  }) {
    final availableHeight =
        imageExtent ??
        (widget.settings.readingMode == ReadingMode.horizontal
            ? _currentPageHeight - _contentInsets().vertical
            : null);
    final maxImgHeight = availableHeight == null
        ? double.infinity
        : math.max(0.0, availableHeight - 24);
    final ratio = _imageAspectRatio(block);
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: 12, left: block.indent),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            key: scope.imageKeys.putIfAbsent(
              block.charStart,
              () => GlobalKey(),
            ),
            height: ratio == null
                ? null
                : math.min(constraints.maxWidth / ratio, maxImgHeight),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxImgHeight),
              child: block.isSvg
                  ? SvgPicture.memory(block.bytes, fit: BoxFit.contain)
                  : Image(
                      image: _rasterImage(block).provider,
                      fit: BoxFit.contain,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDividerBlock() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        color: _computeTextColor(widget.settings.backgroundColor).withAlpha(60),
        thickness: 1,
        height: 1,
      ),
    );
  }

  void _handleScopedSelectionChanged({
    required _SelectionScopeData scope,
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

    final range = scope.notifier.registered
        ? scope.notifier.selection.range
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
      hasExactCharOffset: true,
      chapterIndex: chapterIndex,
      charOffset: startOffset,
      scrollFraction: scrollFraction,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    widget.onTextSelected?.call(selectedText, location.toJson());
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
    for (final scope in _selectionScopes) {
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
    final textBlocks = contentLeaves(
      elements,
    ).whereType<TextBlock>().toList(growable: false);
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
