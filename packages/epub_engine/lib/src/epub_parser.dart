import 'dart:typed_data';
import 'package:epubx/epubx.dart';

/// Parsed EPUB content ready for rendering
class ParsedEpub {
  final String title;
  final String author;
  final Uint8List? coverImage;
  final List<EpubChapter> chapters; // Flat list for rendering
  final List<TOCItem> toc; // Hierarchical Table of Contents
  final Map<String, Uint8List> images;

  ParsedEpub({
    required this.title,
    required this.author,
    this.coverImage,
    required this.chapters,
    required this.toc,
    required this.images,
  });
}

/// Chapter with HTML content
class EpubChapter {
  final String title;
  final String htmlContent;
  final String fileName;

  EpubChapter({
    required this.title,
    required this.htmlContent,
    required this.fileName,
  });
}

/// Item in the Table of Contents
class TOCItem {
  final String title;
  final String fileName;
  final List<TOCItem> subItems;

  TOCItem({
    required this.title,
    required this.fileName,
    this.subItems = const [],
  });
}

/// Files to skip (navigation, metadata, etc.)
const _skipPatterns = ['nav', 'toc', 'ncx', 'cover', 'titlepage', 'copyright'];

bool _isMetadataFile(String fileName) {
  if (fileName.isEmpty) return true;
  final lower = fileName.toLowerCase();
  for (final pattern in _skipPatterns) {
    if (lower.contains(pattern)) return true;
  }
  return false;
}

/// Parses EPUB bytes into structured content
class EpubParser {
  /// Parse EPUB from raw bytes
  static Future<ParsedEpub> parse(Uint8List data) async {
    final book = await EpubReader.readBook(data);

    final title = book.Title ?? 'Unknown Title';
    final author = book.Author ?? 'Unknown Author';

    // Extract cover image
    Uint8List? coverImage;
    if (book.CoverImage != null) {
      try {
        final bytes = book.CoverImage!.getBytes();
        if (bytes.isNotEmpty) {
          coverImage = Uint8List.fromList(bytes);
        }
      } catch (_) {}
    }

    if (coverImage == null && book.Content?.Images != null) {
      for (final entry in book.Content!.Images!.entries) {
        final key = entry.key.toLowerCase();
        if ((key.contains('cover') || key.contains('jacket')) &&
            entry.value.Content != null &&
            entry.value.Content!.isNotEmpty) {
          coverImage = Uint8List.fromList(entry.value.Content!);
          break;
        }
      }
    }

    // Extract all images
    final images = <String, Uint8List>{};
    if (book.Content?.Images != null) {
      for (final entry in book.Content!.Images!.entries) {
        if (entry.value.Content != null) {
          images[entry.key] = Uint8List.fromList(entry.value.Content!);
        }
      }
    }

    final flatChapters = <EpubChapter>[];
    final toc = <TOCItem>[];
    final seenFileNames = <String>{};

    if (book.Chapters != null && book.Chapters!.isNotEmpty) {
      for (final ch in book.Chapters!) {
        _processChapter(ch, flatChapters, toc, seenFileNames);
      }
    } else if (book.Content?.Html != null) {
      // Fallback
      for (final entry in book.Content!.Html!.entries) {
        if (_isMetadataFile(entry.key)) continue;
        final htmlContent = entry.value.Content ?? '';
        if (htmlContent.trim().isEmpty) continue;

        flatChapters.add(
          EpubChapter(
            title: entry.key,
            htmlContent: htmlContent,
            fileName: entry.key,
          ),
        );
        toc.add(TOCItem(title: entry.key, fileName: entry.key));
      }
    }

    return ParsedEpub(
      title: title,
      author: author,
      coverImage: coverImage,
      chapters: flatChapters,
      toc: toc,
      images: images,
    );
  }

  static void _processChapter(
    dynamic ch, // Use dynamic or EpubChapter from epubx
    List<EpubChapter> flatChapters,
    List<TOCItem> tocList,
    Set<String> seenFileNames,
  ) {
    final String fileName = ch.ContentFileName ?? '';
    final String title = ch.Title ?? '';

    // Create TOC Item
    final subTOC = <TOCItem>[];
    if (ch.SubChapters != null && ch.SubChapters.isNotEmpty) {
      for (final sub in ch.SubChapters) {
        _processChapter(sub, flatChapters, subTOC, seenFileNames);
      }
    }

    final tocItem = TOCItem(
      title: title,
      fileName: fileName,
      subItems: subTOC,
    );
    tocList.add(tocItem);

    // Add to flat list ONLY if not already present and not metadata
    if (fileName.isNotEmpty &&
        !_isMetadataFile(fileName) &&
        !seenFileNames.contains(fileName)) {
      final String htmlContent = ch.HtmlContent ?? '';
      if (htmlContent.trim().isNotEmpty) {
        flatChapters.add(
          EpubChapter(
            title: title,
            htmlContent: htmlContent,
            fileName: fileName,
          ),
        );
        seenFileNames.add(fileName);
      }
    }
  }
}
