import 'dart:typed_data';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';

class EpubBookReaderEngine implements BookReaderEngine {
  ParsedEpub? _epub;
  final GlobalKey<EpubNativeViewState> _readerKey =
      GlobalKey<EpubNativeViewState>();

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
        toc: [],
        images: {},
      );
    }
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
    // Parse location from string to EpubLocation
    EpubLocation? parsedLocation;
    if (initialLocation.locator.isNotEmpty) {
      parsedLocation = EpubLocation.fromJson(initialLocation.locator);
    }

    return EpubNativeView(
      key: _readerKey,
      epub: _epub!,
      initialLocation: parsedLocation,
      settings: settings,
      theme: theme,
      highlights: highlights,
      onLocationChanged: (epubLocation, percentage) {
        onProgressChanged(
          BookLocation(locator: epubLocation.toJson()),
          percentage,
        );
      },
      onTextSelected: (text, locator) {
        onTextSelected(text, BookLocation(locator: locator));
      },
      onCenterTapped: onCenterTapped,
    );
  }

  @override
  Future<void> goToLocation(BookLocation location) async {
    final parsedLocation = EpubLocation.fromJson(location.locator);
    if (parsedLocation != null) {
      _readerKey.currentState?.goToLocation(parsedLocation);
      return;
    }

    _readerKey.currentState?.scrollToChapter(location.locator);
  }

  @override
  List<TOCItem> getToc() {
    return _epub?.toc ?? [];
  }

  @override
  void dispose() {}
}
