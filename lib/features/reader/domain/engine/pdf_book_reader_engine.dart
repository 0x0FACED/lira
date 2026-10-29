import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:epub_engine/epub_engine.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';
import '../models/book_search.dart';

class PdfBookReaderEngine implements BookReaderEngine {
  Uint8List? _bookData;
  PdfViewerController? _controller;
  List<TOCItem> _toc = [];
  int _pageCount = 0;
  PdfReaderLocation? _pendingLocation;
  bool _viewerReady = false;
  int _documentGeneration = 0;
  _PdfSearchDocument? _searchDocument;
  Future<_PdfSearchDocument?>? _openingSearchDocument;

  static const _emptySearchResults = BookSearchResults(
    matches: [],
    hasText: false,
  );

  @override
  String get supportedFormat => 'pdf';

  @override
  Future<void> loadBook(Uint8List bookData) async {
    final generation = ++_documentGeneration;
    _retireSearchDocument();
    _openingSearchDocument = null;
    _bookData = null;
    _controller = null;
    _toc = [];
    _pageCount = 0;
    _pendingLocation = null;
    _viewerReady = false;
    final document = await PdfDocument.openData(
      bookData,
      useProgressiveLoading: false,
    );
    var retained = false;
    try {
      if (generation != _documentGeneration) return;
      if (document.pages.isEmpty) {
        throw const FormatException('PDF has no pages');
      }
      final outline = await document.loadOutline();
      if (generation != _documentGeneration) return;
      _pageCount = document.pages.length;
      _toc = _convertOutline(outline);
      // Reuse the validated document for searches before the viewer mounts.
      // The mounted viewer owns a separate document and replaces this one.
      _searchDocument = _PdfSearchDocument(document);
      retained = true;
      _bookData = bookData;
      _controller = PdfViewerController();
    } finally {
      if (!retained) await document.dispose();
    }
  }

  /// Recursively converts pdfrx PdfOutlineNode tree to TOCItem tree.
  List<TOCItem> _convertOutline(List<PdfOutlineNode> nodes) {
    return nodes.map((node) {
      // Use the destination page number as the fileName locator
      final pageNumber = (node.dest?.pageNumber ?? 1).clamp(
        1,
        _pageCount > 0 ? _pageCount : 1,
      );
      return TOCItem(
        title: node.title,
        fileName: pageNumber.toString(),
        subItems: node.children.isNotEmpty
            ? _convertOutline(node.children)
            : [],
      );
    }).toList();
  }

  @override
  Widget buildReaderWidget({
    required BuildContext context,
    required BookLocation initialLocation,
    required ReaderSettings settings,
    required ThemeData theme,
    required void Function(BookLocation location, double percentage)
    onProgressChanged,
    required void Function(String text, BookLocation location) onTextSelected,
    VoidCallback? onCenterTapped,
    List<Map<String, dynamic>> highlights = const [],
  }) {
    final data = _bookData;
    if (data == null) throw StateError('Load a PDF before building its reader');
    final generation = _documentGeneration;
    final location = PdfReaderLocation.tryParse(initialLocation.locator);
    final initialPage = location?.pageFor(_pageCount) ?? 1;
    final initialPdfLocation =
        location != null && location.pageNumber == initialPage
        ? location
        : PdfReaderLocation.page(initialPage);

    // Background color from reader settings
    final bgColor = Color(settings.backgroundColor);

    return PdfViewerWidget(
      key: ObjectKey(data),
      data: data,
      initialLocation: initialPdfLocation,
      backgroundColor: bgColor,
      controller: _controller,
      highlights: highlights,
      onCenterTapped: onCenterTapped,
      onTextSelected: (text, location) {
        onTextSelected(text, BookLocation(locator: location));
      },
      onDocumentLoaded: (_) {
        if (generation != _documentGeneration) return;
        _retireSearchDocument();
        _viewerReady = true;
        final pending = _pendingLocation;
        if (pending != null) unawaited(_navigate(pending));
      },
      onPageChanged: (page, total) {
        final percentage = ((page / total) * 100).clamp(0.0, 100.0).toDouble();
        onProgressChanged(BookLocation(locator: page.toString()), percentage);
      },
    );
  }

  @override
  Future<BookSearchResults> search(BookSearchRequest request) async {
    final generation = _documentGeneration;
    final data = _bookData;
    bool isCurrent() =>
        generation == _documentGeneration && !request.isCancelled;
    if (data == null || request.query.isEmpty || !isCurrent()) {
      return _emptySearchResults;
    }

    while (isCurrent()) {
      final controller = _controller;
      if (controller != null && controller.isReady) {
        // useDocument pins the viewer's document until this search finishes,
        // even if the widget unmounts while native extraction is in flight.
        final results = await controller.useDocument(
          (document) => _searchText(document, request, isCurrent),
          ensureLoaded: false,
        );
        if (!isCurrent()) return _emptySearchResults;
        if (results != null) return results;
        // The viewer may have detached before its document was acquired.
      }

      final owned = await _getSearchDocument(data, generation);
      if (!isCurrent()) return _emptySearchResults;
      if (owned == null) return _emptySearchResults;
      if (!identical(owned, _searchDocument)) continue;
      try {
        final results = await owned.use(
          (document) => _searchText(document, request, isCurrent),
        );
        return isCurrent() ? results : _emptySearchResults;
      } finally {
        if (generation == _documentGeneration && _controller?.isReady == true) {
          _retireSearchDocument();
        }
      }
    }
    return _emptySearchResults;
  }

  Future<_PdfSearchDocument?> _getSearchDocument(
    Uint8List data,
    int generation,
  ) async {
    final existing = _searchDocument;
    if (existing != null) return existing;
    final opening = _openingSearchDocument ??= _openSearchDocument(
      data,
      generation,
    );
    try {
      return await opening;
    } finally {
      if (identical(_openingSearchDocument, opening)) {
        _openingSearchDocument = null;
      }
    }
  }

  Future<_PdfSearchDocument?> _openSearchDocument(
    Uint8List data,
    int generation,
  ) async {
    if (generation != _documentGeneration) return null;
    final document = await PdfDocument.openData(
      data,
      useProgressiveLoading: false,
    );
    if (generation != _documentGeneration) {
      await document.dispose();
      return null;
    }
    return _searchDocument = _PdfSearchDocument(document);
  }

  Future<BookSearchResults> _searchText(
    PdfDocument document,
    BookSearchRequest request,
    bool Function() isCurrent,
  ) async {
    final matches = <BookSearchMatch>[];
    var hasText = false;
    for (final page in document.pages) {
      if (!isCurrent()) return _emptySearchResults;
      // Native extraction and a page with many matches must not starve input
      // events (including cancellation) on the Flutter isolate.
      await Future<void>.delayed(Duration.zero);
      if (!isCurrent()) return _emptySearchResults;
      final pageText = await page.loadText();
      if (!isCurrent()) return _emptySearchResults;
      hasText = hasText || pageText.fullText.trim().isNotEmpty;
      for (final excerpt in request.matches(pageText.fullText)) {
        if (!isCurrent()) return _emptySearchResults;
        final selection = PdfReaderSelection.fromTextSelections([
          PdfTextRanges(
            pageText: pageText,
            ranges: [PdfTextRange(start: excerpt.start, end: excerpt.end)],
          ),
        ]);
        if (selection == null) {
          throw FormatException(
            'PDF text match has no selectable geometry on page '
            '${page.pageNumber}',
          );
        }
        matches.add(
          BookSearchMatch(
            location: BookLocation(locator: selection.location.encode()),
            excerpt: excerpt,
            sectionIndex: page.pageNumber - 1,
            pageNumber: page.pageNumber,
          ),
        );
        if (matches.length % 64 == 0) {
          await Future<void>.delayed(Duration.zero);
          if (!isCurrent()) return _emptySearchResults;
        }
      }
    }
    return BookSearchResults(
      matches: List.unmodifiable(matches),
      hasText: hasText,
    );
  }

  void _retireSearchDocument() {
    final owned = _searchDocument;
    _searchDocument = null;
    owned?.retire();
  }

  @override
  Future<void> goToLocation(BookLocation location) async {
    final parsed = PdfReaderLocation.tryParse(location.locator);
    if (parsed == null) return;
    if (!_viewerReady || _controller?.isReady != true) {
      _pendingLocation = parsed;
      return;
    }
    await _navigate(parsed);
  }

  Future<void> _navigate(PdfReaderLocation location) async {
    final controller = _controller;
    if (!_viewerReady || controller == null || !controller.isReady) return;
    _pendingLocation = null;
    final page = location.pageFor(controller.pageCount);
    if (location.targetRect != null && page == location.pageNumber) {
      await controller.goTo(
        controller.calcMatrixForRect(
          controller.calcRectForRectInsidePage(
            pageNumber: page,
            rect: location.targetRect!,
          ),
          zoomMax: controller.currentZoom,
          margin: 24,
        ),
      );
    } else {
      await controller.goToPage(pageNumber: page);
    }
  }

  @override
  List<TOCItem> getToc() {
    return _toc;
  }

  @override
  void dispose() {
    _documentGeneration++;
    _retireSearchDocument();
    _openingSearchDocument = null;
    _controller = null;
    _bookData = null;
    _toc = [];
    _pageCount = 0;
    _pendingLocation = null;
    _viewerReady = false;
  }
}

/// Owns only a pre-mount/fallback document, never the viewer's document.
/// Retirement waits for outstanding native text loads before closing it.
class _PdfSearchDocument {
  _PdfSearchDocument(this.document);

  final PdfDocument document;
  int _users = 0;
  bool _retired = false;

  Future<T> use<T>(Future<T> Function(PdfDocument) action) async {
    _users++;
    try {
      return await action(document);
    } finally {
      _users--;
      if (_retired && _users == 0) await document.dispose();
    }
  }

  void retire() {
    if (_retired) return;
    _retired = true;
    if (_users == 0) unawaited(document.dispose());
  }
}
