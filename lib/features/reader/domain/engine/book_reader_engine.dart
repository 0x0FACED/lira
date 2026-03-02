import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models/book_location.dart';

/// A common interface for book rendering engines (EPUB, PDF, etc.)
abstract class BookReaderEngine {
  /// The specific format this engine handles (e.g., 'epub', 'pdf')
  String get supportedFormat;

  /// Initializes the engine with the book file data
  Future<void> loadBook(Uint8List bookData);

  /// Returns the widget that renders the book content
  Widget buildReaderWidget({
    required BuildContext context,
    required BookLocation initialLocation,
    required void Function(BookLocation location, double percentage)
    onProgressChanged,
    required void Function(String text, BookLocation location) onTextSelected,
  });

  /// Navigates to a specific location in the book
  Future<void> goToLocation(BookLocation location);

  /// Cleans up resources
  void dispose();
}
