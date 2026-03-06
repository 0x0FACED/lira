import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:epub_engine/epub_engine.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';

class PdfBookReaderEngine implements BookReaderEngine {
  Uint8List? _bookData;

  @override
  String get supportedFormat => 'pdf';

  @override
  Future<void> loadBook(Uint8List bookData) async {
    _bookData = bookData;
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
  }) {
    int initialPage = 1;
    if (initialLocation.locator.isNotEmpty) {
      initialPage = int.tryParse(initialLocation.locator) ?? 1;
    }

    return PdfViewerWidget(
      data: _bookData!,
      initialPage: initialPage,
      onPageChanged: (page, total) {
        final percentage = total > 0 ? (page / total) * 100 : 0.0;
        onProgressChanged(BookLocation(locator: page.toString()), percentage);
      },
    );
  }

  @override
  Future<void> goToLocation(BookLocation location) async {
    // The pdfrx controller handles this internally
  }

  @override
  List<TOCItem> getToc() {
    return [];
  }

  @override
  void dispose() {
    // PdfViewerWidget manages its own lifecycle
  }
}
