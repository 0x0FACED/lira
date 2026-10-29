import 'dart:typed_data';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';
import '../models/book_search.dart';

class EpubBookReaderEngine implements BookReaderEngine {
  ParsedEpub? _epub;
  final Map<int, _EpubSearchChapter> _searchChapters = {};
  Map<String, List<({String title, String? anchor})>>? _searchToc;
  final GlobalKey<EpubNativeViewState> _readerKey =
      GlobalKey<EpubNativeViewState>();

  @override
  String get supportedFormat => 'epub';

  @override
  Future<void> loadBook(Uint8List bookData) async {
    _epub = null;
    _searchChapters.clear();
    _searchToc = null;
    _epub = await EpubParser.parse(bookData);
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
  Future<BookSearchResults> search(BookSearchRequest request) async {
    final epub = _epub;
    if (epub == null) throw StateError('No EPUB is loaded');
    final matches = <BookSearchMatch>[];
    var hasText = false;

    bool isCurrent() => !request.isCancelled && identical(_epub, epub);
    BookSearchResults cancelled() =>
        BookSearchResults(matches: const [], hasText: hasText);

    for (var index = 0; index < epub.chapters.length; index++) {
      // A query may be replaced while the keyboard is still producing events.
      // Yield even when the complete chapter index is already cached.
      await Future<void>.delayed(Duration.zero);
      if (!isCurrent()) return cancelled();
      final chapter = _searchChapters.putIfAbsent(
        index,
        () => _indexSearchChapter(epub, index),
      );
      hasText = hasText || chapter.hasText;
      var batchSize = 0;
      for (final excerpt in request.matches(chapter.text)) {
        final start = chapter.chapterOffset(excerpt.start);
        final end = chapter.chapterOffset(excerpt.end - 1) + 1;
        matches.add(
          BookSearchMatch(
            location: BookLocation(
              locator: EpubLocation.fromPosition(
                chapterIndex: index,
                hasExactCharOffset: true,
                charOffset: start,
                startOffset: start,
                endOffset: end,
              ).toJson(),
            ),
            excerpt: excerpt,
            sectionIndex: index,
            sectionTitle: chapter.titleAt(start),
          ),
        );
        if (++batchSize == 128) {
          batchSize = 0;
          await Future<void>.delayed(Duration.zero);
          if (!isCurrent()) return cancelled();
        }
      }
      if (!isCurrent()) return cancelled();
    }
    return BookSearchResults(matches: matches, hasText: hasText);
  }

  _EpubSearchChapter _indexSearchChapter(ParsedEpub epub, int index) {
    final chapter = epub.chapters[index];
    final parser = XhtmlParser(
      html: chapter.htmlContent,
      images: epub.images,
      documentPath: chapter.fileName,
      stylesheets: epub.stylesheets,
      baseStyle: const TextStyle(fontSize: 16),
    );
    final elements = parser.parse();
    final text = StringBuffer();
    final runs = <_EpubSearchRun>[];
    var hasText = false;
    for (final leaf in contentLeaves(elements)) {
      if (leaf is! TextBlock) continue;
      final value = leaf.span.toPlainText(includeSemanticsLabels: false);
      if (value.isEmpty) continue;
      // Blocks have no separator in native coordinates. Keep the searchable
      // boundary in a separate text space, then map the result back to its run.
      if (runs.isNotEmpty) text.write('\n');
      runs.add(
        _EpubSearchRun(
          textStart: text.length,
          textEnd: text.length + value.length,
          chapterStart: leaf.charStart,
        ),
      );
      text.write(value);
      hasText = hasText || value.trim().isNotEmpty;
    }

    final toc = _searchToc ??= _indexSearchToc(epub.toc);
    final titles = <int, String>{};
    if (chapter.title.trim().isNotEmpty) titles[0] = chapter.title;
    for (final item in toc[chapter.fileName] ?? const []) {
      final offset = item.anchor == null ? 0 : parser.anchors[item.anchor];
      if (offset != null) titles[offset] = item.title;
    }
    final sections = titles.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return _EpubSearchChapter(
      text: text.toString(),
      runs: runs,
      hasText: hasText,
      sections: sections,
    );
  }

  Map<String, List<({String title, String? anchor})>> _indexSearchToc(
    List<TOCItem> items,
  ) {
    final result = <String, List<({String title, String? anchor})>>{};
    void visit(List<TOCItem> items) {
      for (final item in items) {
        final uri = Uri.tryParse(item.fileName);
        if (uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            item.title.trim().isNotEmpty) {
          (result[uri.pathSegments.join('/')] ??= []).add((
            title: item.title,
            anchor: uri.hasFragment ? Uri.decodeComponent(uri.fragment) : null,
          ));
        }
        visit(item.subItems);
      }
    }

    visit(items);
    return result;
  }

  @override
  List<TOCItem> getToc() {
    return _epub?.toc ?? [];
  }

  @override
  void dispose() {
    _epub = null;
    _searchChapters.clear();
    _searchToc = null;
  }
}

class _EpubSearchRun {
  const _EpubSearchRun({
    required this.textStart,
    required this.textEnd,
    required this.chapterStart,
  });

  final int textStart;
  final int textEnd;
  final int chapterStart;
}

class _EpubSearchChapter {
  const _EpubSearchChapter({
    required this.text,
    required this.runs,
    required this.hasText,
    required this.sections,
  });

  final String text;
  final List<_EpubSearchRun> runs;
  final bool hasText;
  final List<MapEntry<int, String>> sections;

  int chapterOffset(int textOffset) {
    var low = 0;
    var high = runs.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (runs[middle].textEnd <= textOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final run = runs[low];
    return run.chapterStart + textOffset - run.textStart;
  }

  String? titleAt(int offset) {
    var low = 0;
    var high = sections.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (sections[middle].key <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low == 0 ? null : sections[low - 1].value;
  }
}
