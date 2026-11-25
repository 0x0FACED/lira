import 'dart:convert';
import 'dart:typed_data';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';

import 'book_reader_engine.dart';
import '../models/book_location.dart';
import '../models/book_search.dart';

class EpubBookReaderEngine implements BookReaderEngine {
  EpubBookReaderEngine({
    this.onPositionBeforeProgress,
    this.paginatedTopPadding,
  });

  final ValueChanged<BookLocation>? onPositionBeforeProgress;
  final double? paginatedTopPadding;

  ParsedEpub? _epub;
  int _loadGeneration = 0;
  final Map<int, _EpubSearchChapter> _searchChapters = {};
  Map<String, List<({String title, String? anchor})>>? _searchToc;
  final Map<int, Map<String, int>> _chapterAnchorOffsets = {};
  final Map<int, List<_EpubTocEntry>> _tocByChapter = {};
  final Map<int, List<_EpubTocSection>> _tocSections = {};
  final Map<String, int> _chapterIndices = {};
  final List<int> _tocChapters = [];
  final GlobalKey<EpubNativeViewState> _readerKey =
      GlobalKey<EpubNativeViewState>();

  @override
  String get supportedFormat => 'epub';

  @override
  Future<void> loadBook(Uint8List bookData) =>
      _load(() => EpubParser.parse(bookData));

  /// Open a native EPUB without reading or parsing its ZIP on the UI isolate.
  Future<void> loadBookFile(String path) =>
      _load(() => EpubParser.parseFile(path));

  Future<void> _load(Future<ParsedEpub> Function() parse) async {
    final generation = ++_loadGeneration;
    _epub = null;
    _searchChapters.clear();
    _searchToc = null;
    _clearTocIndex();
    final epub = await parse();
    if (generation == _loadGeneration) {
      _epub = epub;
      _indexToc(epub);
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
    ValueChanged<Rect?>? onSelectionAnchorChanged,
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
      paginatedTopPadding: paginatedTopPadding,
      theme: theme,
      highlights: highlights,
      onPositionBeforeProgress: onPositionBeforeProgress == null
          ? null
          : (location) => onPositionBeforeProgress!(
              BookLocation(locator: location.toJson()),
            ),
      onLocationChanged: (epubLocation, percentage) {
        onProgressChanged(
          BookLocation(locator: epubLocation.toJson()),
          percentage,
        );
      },
      onTextSelected: (text, locator) {
        onTextSelected(text, BookLocation(locator: locator));
      },
      onSelectionAnchorChanged: onSelectionAnchorChanged,
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
    _chapterAnchorOffsets[index] = parser.anchors;
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
  TOCItem? tocItemAt(BookLocation location) {
    final epub = _epub;
    if (epub == null || _tocChapters.isEmpty) return null;
    final position = _tocPosition(location.locator);
    if (position == null) return null;
    var low = 0;
    var high = _tocChapters.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_tocChapters[middle] <= position.chapter) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    for (var index = low - 1; index >= 0; index--) {
      final chapter = _tocChapters[index];
      final sections = _sectionsFor(epub, chapter);
      final limit = chapter == position.chapter ? position.offset : null;
      for (var section = sections.length - 1; section >= 0; section--) {
        if (limit == null || sections[section].offset <= limit) {
          return sections[section].entry.item;
        }
      }
    }
    return null;
  }

  void _indexToc(ParsedEpub epub) {
    for (var index = 0; index < epub.chapters.length; index++) {
      _chapterIndices[epub.chapters[index].fileName] = index;
    }
    var order = 0;
    void visit(List<TOCItem> items, int depth) {
      for (final item in items) {
        final destination = _tocDestination(item.fileName);
        if (destination != null && item.title.trim().isNotEmpty) {
          (_tocByChapter[destination.chapter] ??= []).add(
            _EpubTocEntry(item, destination.anchor, depth, order++),
          );
        }
        visit(item.subItems, depth + 1);
      }
    }

    visit(epub.toc, 0);
    _tocChapters.addAll(_tocByChapter.keys);
    _tocChapters.sort();
  }

  ({int chapter, String? anchor})? _tocDestination(String locator) {
    final uri = Uri.tryParse(locator);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.path.isEmpty) {
      return null;
    }
    try {
      final chapter =
          _chapterIndices[uri.normalizePath().pathSegments.join('/')];
      if (chapter == null) return null;
      final anchor = uri.hasFragment && uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : null;
      return (chapter: chapter, anchor: anchor);
    } on FormatException {
      return null;
    }
  }

  ({int chapter, int offset})? _tocPosition(String locator) {
    final parsed = EpubLocation.fromJson(locator);
    if (parsed == null) {
      final destination = _tocDestination(locator);
      if (destination == null) return null;
      final offset = destination.anchor == null
          ? 0
          : _anchorsFor(_epub!, destination.chapter)[destination.anchor];
      return offset == null
          ? null
          : (chapter: destination.chapter, offset: offset);
    }
    // The legacy decoder supplies chapter zero for arbitrary JSON objects.
    // Those are not known book locations; neither are future wire versions.
    final data = jsonDecode(locator) as Map<String, dynamic>;
    if (data['s'] is! int ||
        (data['v'] != null && data['v'] != 2) ||
        parsed.chapterIndex < 0 ||
        parsed.chapterIndex >= _epub!.chapters.length) {
      return null;
    }
    final int? offset;
    if (parsed.anchor != null) {
      offset = _anchorsFor(_epub!, parsed.chapterIndex)[parsed.anchor];
    } else if (parsed.hasExactCharOffset) {
      offset = parsed.charOffset;
    } else if (parsed.startOffset != null && parsed.endOffset != null) {
      offset = parsed.startOffset;
    } else if (parsed.charOffset == 0 &&
        parsed.scrollFraction == 0 &&
        parsed.bookScrollOffset == null &&
        parsed.bookScrollFraction == null) {
      offset = 0;
    } else {
      // Legacy HTML/pixel/fraction coordinates cannot order exact anchors.
      // The reader emits a v2 content location after restoring them.
      return null;
    }
    return offset == null || offset < 0
        ? null
        : (chapter: parsed.chapterIndex, offset: offset);
  }

  Map<String, int> _anchorsFor(ParsedEpub epub, int index) {
    final cached = _chapterAnchorOffsets[index];
    if (cached != null) return cached;
    final state = _readerKey.currentState;
    final native = state != null && identical(state.widget.epub, epub)
        ? state.parsedChapterAnchors(index)
        : null;
    if (native != null) return _chapterAnchorOffsets[index] = native;
    // Pre-mount lookups or a preceding TOC chapter may not be in the view's
    // cache. Parse only that requested chapter, never an eager book index.
    final chapter = epub.chapters[index];
    final parser = XhtmlParser(
      html: chapter.htmlContent,
      images: epub.images,
      documentPath: chapter.fileName,
      stylesheets: epub.stylesheets,
      baseStyle: const TextStyle(fontSize: 16),
      language: epub.language,
    );
    parser.parse();
    return _chapterAnchorOffsets[index] = parser.anchors;
  }

  List<_EpubTocSection> _sectionsFor(ParsedEpub epub, int chapter) =>
      _tocSections.putIfAbsent(chapter, () {
        final result = <_EpubTocSection>[];
        for (final entry in _tocByChapter[chapter]!) {
          final offset = entry.anchor == null
              ? 0
              : _anchorsFor(epub, chapter)[entry.anchor];
          if (offset != null) result.add(_EpubTocSection(entry, offset));
        }
        result.sort((a, b) {
          final offset = a.offset.compareTo(b.offset);
          if (offset != 0) return offset;
          final depth = a.entry.depth.compareTo(b.entry.depth);
          return depth != 0 ? depth : a.entry.order.compareTo(b.entry.order);
        });
        return result;
      });

  void _clearTocIndex() {
    _chapterAnchorOffsets.clear();
    _tocByChapter.clear();
    _tocSections.clear();
    _chapterIndices.clear();
    _tocChapters.clear();
  }

  @override
  void dispose() {
    ++_loadGeneration;
    _epub = null;
    _searchChapters.clear();
    _searchToc = null;
    _clearTocIndex();
  }
}

class _EpubTocEntry {
  const _EpubTocEntry(this.item, this.anchor, this.depth, this.order);

  final TOCItem item;
  final String? anchor;
  final int depth;
  final int order;
}

class _EpubTocSection {
  const _EpubTocSection(this.entry, this.offset);

  final _EpubTocEntry entry;
  final int offset;
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
