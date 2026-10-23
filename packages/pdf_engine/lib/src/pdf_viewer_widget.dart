import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_reader_location.dart';

/// Native PDF viewer with durable text-selection locations and highlights.
class PdfViewerWidget extends StatefulWidget {
  final Uint8List data;
  final PdfReaderLocation? initialLocation;
  final Color backgroundColor;
  final PdfViewerController? controller;
  final void Function(int page, int totalPages)? onPageChanged;
  final void Function(PdfDocument document)? onDocumentLoaded;
  final void Function(String text, String location)? onTextSelected;
  final VoidCallback? onCenterTapped;
  final List<Map<String, dynamic>> highlights;

  const PdfViewerWidget({
    super.key,
    required this.data,
    this.initialLocation,
    this.backgroundColor = Colors.white,
    this.controller,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onTextSelected,
    this.onCenterTapped,
    this.highlights = const [],
  });

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  late PdfViewerController _controller;
  late PdfDocumentRefData _documentRef;
  late Object _viewerIdentity;
  int _totalPages = 0;
  bool _initialLocationApplied = false;
  String? _lastSelection;
  Map<int, List<_PageHighlight>> _highlightsByPage = const {};
  final _selectionDelegate = _PdfTextSelectionDelegate();
  final _pressedPointers = <int>{};
  PointerDownEvent? _tapStart;
  Duration? _previousTapUpTime;
  Offset? _previousTapPosition;
  bool _multiTap = false;
  Timer? _pendingTap;
  int _tapGeneration = 0;

  @override
  void initState() {
    super.initState();
    _resetViewer();
    _readHighlights();
  }

  @override
  void didUpdateWidget(covariant PdfViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data) ||
        oldWidget.controller != widget.controller) {
      _resetViewer();
    }
    if (!identical(oldWidget.highlights, widget.highlights)) _readHighlights();
  }

  void _resetViewer() {
    _cancelObservedTap();
    _selectionDelegate.resetEdges();
    _pressedPointers.clear();
    _controller = widget.controller ?? PdfViewerController();
    _viewerIdentity = Object();
    _totalPages = 0;
    _initialLocationApplied = false;
    _lastSelection = null;
    // pdfrx caches document references by sourceName, not by their byte data.
    // Keep this reference stable on rebuild and unique to this viewer/book.
    _documentRef = PdfDocumentRefData(
      widget.data,
      sourceName: 'lira-pdf-${identityHashCode(_viewerIdentity)}',
    );
  }

  void _readHighlights() {
    final byPage = <int, List<_PageHighlight>>{};
    for (final raw in widget.highlights) {
      final locationValue = raw['location'];
      final colorValue = raw['color'];
      if (locationValue is! String || colorValue is! String) continue;
      final location = PdfReaderLocation.tryParse(locationValue);
      final hex = colorValue.replaceFirst('#', '');
      if (location == null ||
          !location.isSelection ||
          (hex.length != 6 && hex.length != 8)) {
        continue;
      }
      final colorNumber = int.tryParse(hex, radix: 16);
      if (colorNumber == null) continue;
      final color = Color(
        hex.length == 6 ? 0xFF000000 | colorNumber : colorNumber,
      ).withAlpha(90);
      for (final selection in location.selections) {
        (byPage[selection.pageNumber] ??= []).add(
          _PageHighlight(selection.rects, color),
        );
      }
    }
    _highlightsByPage = byPage;
  }

  void _onTextSelectionChanged(List<PdfTextRanges> selections) {
    final selection = PdfReaderSelection.fromTextSelections(selections);
    if (selection == null) {
      if (_lastSelection == null) return;
      _lastSelection = null;
      final page = (_controller.isReady ? _controller.pageNumber : null) ?? 1;
      widget.onTextSelected?.call(
        '',
        (_totalPages > 0 ? page.clamp(1, _totalPages) : 1).toString(),
      );
      return;
    }
    final encoded = selection.location.encode();
    if (_lastSelection == encoded) return;
    _lastSelection = encoded;
    _pendingTap?.cancel();
    _pendingTap = null;
    _tapGeneration++;
    widget.onTextSelected?.call(selection.text, encoded);
  }

  void _cancelObservedTap() {
    _tapGeneration++;
    _pendingTap?.cancel();
    _pendingTap = null;
    _tapStart = null;
    _previousTapUpTime = null;
    _previousTapPosition = null;
    _multiTap = false;
  }

  void _observePointerDown(PointerDownEvent event) {
    if (_pressedPointers.isEmpty) _selectionDelegate.resetEdges();
    _tapGeneration++;
    _pressedPointers.add(event.pointer);
    _pendingTap?.cancel();
    _pendingTap = null;
    if (_pressedPointers.length != 1 || event.buttons != kPrimaryButton) {
      _tapStart = null;
      _previousTapUpTime = null;
      return;
    }
    final previousTime = _previousTapUpTime;
    final previousPosition = _previousTapPosition;
    _multiTap =
        previousTime != null &&
        previousPosition != null &&
        event.timeStamp - previousTime <= kDoubleTapTimeout &&
        (event.localPosition - previousPosition).distance <= kDoubleTapSlop;
    _tapStart = event;
  }

  void _observePointerMove(PointerMoveEvent event) {
    final start = _tapStart;
    if (start != null &&
        start.pointer == event.pointer &&
        (event.localPosition - start.localPosition).distance >
            computeHitSlop(event.kind, null)) {
      _tapGeneration++;
      _tapStart = null;
      _previousTapUpTime = null;
    }
  }

  void _observePointerUp(
    PointerUpEvent event,
    PdfViewerHandleLinkTap handleLinkTap,
  ) {
    _pressedPointers.remove(event.pointer);
    final start = _tapStart;
    _tapStart = null;
    if (start == null ||
        start.pointer != event.pointer ||
        _pressedPointers.isNotEmpty ||
        event.timeStamp - start.timeStamp >= kLongPressTimeout) {
      _previousTapUpTime = null;
      return;
    }
    _previousTapUpTime = event.timeStamp;
    _previousTapPosition = event.localPosition;
    if (_multiTap) return;
    // Observe pointer taps without entering SelectionArea's gesture arena.
    // handleLinkTap also clears selection on non-links, so it must not run
    // before we know this is not native double/triple-click selection.
    final generation = _tapGeneration;
    final identity = _viewerIdentity;
    _pendingTap = Timer(kDoubleTapTimeout, () {
      _pendingTap = null;
      unawaited(
        _handleSingleTap(
          event.localPosition,
          handleLinkTap,
          generation,
          identity,
        ),
      );
    });
  }

  bool _isCurrentTap(
    int generation,
    Object identity,
    PdfViewerController controller,
  ) =>
      mounted &&
      generation == _tapGeneration &&
      identical(identity, _viewerIdentity) &&
      identical(controller, _controller) &&
      controller.isReady;

  Future<void> _handleSingleTap(
    Offset position,
    PdfViewerHandleLinkTap clearSelection,
    int generation,
    Object identity,
  ) async {
    final controller = _controller;
    if (!_isCurrentTap(generation, identity, controller)) return;
    final hit = controller.getPdfPageHitTestResult(
      position,
      useDocumentLayoutCoordinates: false,
    );
    PdfLink? tappedLink;
    if (hit != null) {
      final links = await controller.useDocument(
        (document) => document.pages[hit.page.pageNumber - 1].loadLinks(),
      );
      if (!_isCurrentTap(generation, identity, controller)) return;
      for (final link in links ?? const <PdfLink>[]) {
        if (link.rects.any((rect) => rect.containsPoint(hit.offset))) {
          tappedLink = link;
          break;
        }
      }
    }
    if (!_isCurrentTap(generation, identity, controller)) return;
    // Leave pdfrx's full-view link GestureDetector disabled. Its raw callback
    // still provides native deselection for this confirmed single tap.
    clearSelection(position);
    _selectionDelegate.resetEdges();
    if (tappedLink == null) {
      widget.onCenterTapped?.call();
      return;
    }
    final destination = tappedLink.dest;
    if (destination != null) {
      if (destination.pageNumber >= 1 &&
          destination.pageNumber <= controller.pageCount) {
        await controller.goToDest(destination);
      }
      return;
    }
    final url = tappedLink.url;
    if (url != null &&
        (url.scheme == 'http' || url.scheme == 'https') &&
        url.host.isNotEmpty) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _observePointerCancel(PointerCancelEvent event) {
    _pressedPointers.remove(event.pointer);
    _cancelObservedTap();
  }

  @override
  void dispose() {
    _cancelObservedTap();
    _selectionDelegate.dispose();
    super.dispose();
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final highlights = _highlightsByPage[page.pageNumber];
    if (highlights == null) return;
    canvas.save();
    canvas.clipRect(pageRect);
    for (final highlight in highlights) {
      for (final rect in highlight.rects) {
        canvas.drawRect(
          rect.toRectInPageRect(page: page, pageRect: pageRect),
          highlight.paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewer(
      _documentRef,
      // pdfrx itself retains the first controller. A different book/controller
      // must get a new viewer State, unlike progress/settings/highlight updates.
      key: ObjectKey(_viewerIdentity),
      controller: _controller,
      initialPageNumber: widget.initialLocation?.pageNumber ?? 1,
      params: PdfViewerParams(
        calculateInitialPageNumber: (document, controller) =>
            (widget.initialLocation?.pageNumber ?? 1)
                .clamp(1, document.pages.length)
                .toInt(),
        backgroundColor: widget.backgroundColor,
        enableTextSelection: true,
        // Lira owns the selection action bar; retain native selection handles,
        // but do not put Flutter's Copy toolbar on top of the application UI.
        selectableRegionInjector: (context, child) => SelectionArea(
          contextMenuBuilder: (context, state) => const SizedBox.shrink(),
          child: SelectionContainer(delegate: _selectionDelegate, child: child),
        ),
        onTextSelectionChange: _onTextSelectionChanged,
        pagePaintCallbacks: [_paintHighlights],
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _observePointerDown,
            onPointerMove: _observePointerMove,
            onPointerUp: (event) => _observePointerUp(event, handleLinkTap),
            onPointerCancel: _observePointerCancel,
            onPointerSignal: (_) => _cancelObservedTap(),
            onPointerPanZoomStart: (_) => _cancelObservedTap(),
            child: IgnorePointer(child: SizedBox.fromSize(size: size)),
          ),
        ],
        onViewerReady: (document, controller) {
          _totalPages = document.pages.length;
          final location = widget.initialLocation;
          if (!_initialLocationApplied &&
              location != null &&
              location.isSelection &&
              location.pageNumber <= _totalPages) {
            unawaited(
              controller.goTo(
                controller.calcMatrixForRect(
                  controller.calcRectForRectInsidePage(
                    pageNumber: location.pageNumber,
                    rect: location.targetRect!,
                  ),
                  zoomMax: controller.currentZoom,
                  margin: 24,
                ),
              ),
            );
          }
          _initialLocationApplied = true;
          widget.onDocumentLoaded?.call(document);
          if (_totalPages > 0) {
            widget.onPageChanged?.call(controller.pageNumber ?? 1, _totalPages);
          }
        },
        onPageChanged: (pageNumber) {
          if (pageNumber != null && _totalPages > 0) {
            widget.onPageChanged?.call(pageNumber, _totalPages);
          }
        },
      ),
    );
  }

  // PdfViewer detaches its controller and releases the auto-disposed document
  // reference on unmount. PdfViewerController has no dispose API in pdfrx.
}

/// pdfrx 1.3.5 rejects a zero-area edge rectangle before collecting its text.
/// A non-collapsed horizontal/vertical drag therefore needs subpixel thickness.
/// Keep native gestures, text ranges, fragment rectangles and callbacks intact;
/// only adapt the degenerate edge geometry sent to the native selectable.
class _PdfTextSelectionDelegate extends StaticSelectionContainerDelegate {
  Offset? _start;
  Offset? _end;

  void resetEdges() {
    _start = null;
    _end = null;
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    if (event is! SelectionEdgeUpdateEvent) {
      resetEdges();
      return super.dispatchSelectionEvent(event);
    }
    final isStart = event.type == SelectionEventType.startEdgeUpdate;
    final position = event.globalPosition;
    if (isStart) {
      _start = position;
    } else {
      _end = position;
    }
    final start = _start;
    final end = _end;
    if (start != null && end != null && start != end) {
      final thickness = isStart ? -0.001 : 0.001;
      final dx = start.dx == end.dx ? thickness : 0.0;
      final dy = start.dy == end.dy ? thickness : 0.0;
      if (dx != 0 || dy != 0) {
        final adjusted = position.translate(dx, dy);
        event = isStart
            ? SelectionEdgeUpdateEvent.forStart(
                globalPosition: adjusted,
                granularity: event.granularity,
              )
            : SelectionEdgeUpdateEvent.forEnd(
                globalPosition: adjusted,
                granularity: event.granularity,
              );
      }
    }
    return super.dispatchSelectionEvent(event);
  }
}

class _PageHighlight {
  _PageHighlight(this.rects, Color color) : paint = (Paint()..color = color);

  final List<PdfRect> rects;
  final Paint paint;
}
