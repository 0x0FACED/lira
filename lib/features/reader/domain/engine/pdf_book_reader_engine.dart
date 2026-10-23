import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:epub_engine/epub_engine.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';

class PdfBookReaderEngine implements BookReaderEngine {
  Uint8List? _bookData;
  PdfViewerController? _controller;
  List<TOCItem> _toc = [];
  int _pageCount = 0;
  PdfReaderLocation? _pendingLocation;
  bool _viewerReady = false;

  @override
  String get supportedFormat => 'pdf';

  @override
  Future<void> loadBook(Uint8List bookData) async {
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
    try {
      if (document.pages.isEmpty) {
        throw const FormatException('PDF has no pages');
      }
      _pageCount = document.pages.length;
      _toc = _convertOutline(await document.loadOutline());
    } finally {
      await document.dispose();
    }
    // Do not turn an invalid PDF/open/outline failure into a successful load.
    _bookData = bookData;
    _controller = PdfViewerController();
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
    _controller = null;
    _bookData = null;
    _toc = [];
    _pageCount = 0;
    _pendingLocation = null;
    _viewerReady = false;
  }
}
