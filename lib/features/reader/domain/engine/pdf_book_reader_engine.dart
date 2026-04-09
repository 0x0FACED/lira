import 'dart:typed_data';

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

  @override
  String get supportedFormat => 'pdf';

  @override
  Future<void> loadBook(Uint8List bookData) async {
    _bookData = bookData;

    // Pre-load TOC from the document outline
    try {
      final doc = await PdfDocument.openData(bookData);
      final outline = await doc.loadOutline();
      if (outline.isNotEmpty) {
        _toc = _convertOutline(outline);
      }
      doc.dispose();
    } catch (e) {
      debugPrint('Error loading PDF outline: $e');
      _toc = [];
    }
  }

  /// Recursively converts pdfrx PdfOutlineNode tree to TOCItem tree.
  List<TOCItem> _convertOutline(List<PdfOutlineNode> nodes) {
    return nodes.map((node) {
      // Use the destination page number as the fileName locator
      final pageNumber = node.dest?.pageNumber ?? 1;
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
  }) {
    int initialPage = 1;
    if (initialLocation.locator.isNotEmpty) {
      initialPage = int.tryParse(initialLocation.locator) ?? 1;
    }

    _controller = PdfViewerController();

    // Background color from reader settings
    final bgColor = Color(settings.backgroundColor);

    return PdfViewerWidget(
      data: _bookData!,
      initialPage: initialPage,
      backgroundColor: bgColor,
      controller: _controller,
      onPageChanged: (page, total) {
        final percentage = total > 0 ? (page / total) * 100 : 0.0;
        onProgressChanged(BookLocation(locator: page.toString()), percentage);
      },
    );
  }

  @override
  Future<void> goToLocation(BookLocation location) async {
    final page = int.tryParse(location.locator);
    if (page != null && _controller != null) {
      _controller!.goToPage(pageNumber: page);
    }
  }

  @override
  List<TOCItem> getToc() {
    return _toc;
  }

  @override
  void dispose() {
    _controller = null;
  }
}
