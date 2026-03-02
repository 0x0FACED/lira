import 'dart:typed_data';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/widgets.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';

class EpubBookReaderEngine implements BookReaderEngine {
  ParsedEpub? _epub;

  @override
  String get supportedFormat => 'epub';

  @override
  Future<void> loadBook(Uint8List bookData) async {
    try {
      _epub = await EpubParser.parse(bookData);
    } catch (e) {
      _epub = ParsedEpub(
        title: 'Error',
        author: 'Unknown',
        chapters: [
          EpubChapter(
            title: 'Error loading EPUB',
            htmlContent: '<p>Failed to parse this EPUB file: $e</p>',
            fileName: 'error',
          ),
        ],
        images: {},
      );
    }
  }

  @override
  Widget buildReaderWidget({
    required BuildContext context,
    required BookLocation initialLocation,
    required void Function(BookLocation location, double percentage)
    onProgressChanged,
    required void Function(String text, BookLocation location) onTextSelected,
  }) {
    // Locator stores scroll offset as a double string
    double initialOffset = 0.0;
    if (initialLocation.locator.isNotEmpty) {
      initialOffset = double.tryParse(initialLocation.locator) ?? 0.0;
    }

    return EpubReaderView(
      epub: _epub!,
      initialScrollOffset: initialOffset,
      onScrollProgress: (scrollOffset, percentage) {
        onProgressChanged(
          BookLocation(locator: scrollOffset.toStringAsFixed(1)),
          percentage,
        );
      },
    );
  }

  @override
  Future<void> goToLocation(BookLocation location) async {}

  @override
  void dispose() {}
}
