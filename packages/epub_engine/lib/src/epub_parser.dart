import 'dart:typed_data';
import 'package:epubx/epubx.dart';

/// Parsed EPUB content ready for rendering
class ParsedEpub {
  final String title;
  final String author;
  final Uint8List? coverImage;
  final List<EpubChapter> chapters;
  final Map<String, Uint8List> images;

  ParsedEpub({
    required this.title,
    required this.author,
    this.coverImage,
    required this.chapters,
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

/// Files to skip (navigation, metadata, etc.)
const _skipPatterns = ['nav', 'toc', 'ncx', 'cover', 'titlepage', 'copyright'];

bool _isMetadataFile(String fileName) {
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
        coverImage = Uint8List.fromList(book.CoverImage!.getBytes());
      } catch (_) {
        // Some EPUBs may have invalid cover images
      }
    }

    // Extract all images from content
    final images = <String, Uint8List>{};
    if (book.Content?.Images != null) {
      for (final entry in book.Content!.Images!.entries) {
        if (entry.value.Content != null) {
          images[entry.key] = Uint8List.fromList(entry.value.Content!);
        }
      }
    }

    // Extract chapters - use book.Chapters for proper ordering if available
    final chapters = <EpubChapter>[];

    if (book.Chapters != null && book.Chapters!.isNotEmpty) {
      // Use structured chapters — these are the actual book content
      for (final ch in book.Chapters!) {
        final htmlContent = ch.HtmlContent ?? '';
        if (htmlContent.trim().isEmpty) continue;

        final fileName = ch.ContentFileName ?? '';
        // Skip navigation and metadata files
        if (_isMetadataFile(fileName)) continue;

        chapters.add(
          EpubChapter(
            title: ch.Title ?? '',
            htmlContent: htmlContent,
            fileName: fileName,
          ),
        );

        // Add sub-chapters
        if (ch.SubChapters != null) {
          for (final sub in ch.SubChapters!) {
            final subHtml = sub.HtmlContent ?? '';
            if (subHtml.trim().isEmpty) continue;
            final subFile = sub.ContentFileName ?? '';
            if (_isMetadataFile(subFile)) continue;

            chapters.add(
              EpubChapter(
                title: sub.Title ?? '',
                htmlContent: subHtml,
                fileName: subFile,
              ),
            );
          }
        }
      }
    } else if (book.Content?.Html != null) {
      // Fallback: use raw HTML content files
      for (final entry in book.Content!.Html!.entries) {
        final htmlContent = entry.value.Content ?? '';
        if (htmlContent.trim().isEmpty) continue;
        if (_isMetadataFile(entry.key)) continue;

        chapters.add(
          EpubChapter(
            title: entry.key,
            htmlContent: htmlContent,
            fileName: entry.key,
          ),
        );
      }
    }

    return ParsedEpub(
      title: title,
      author: author,
      coverImage: coverImage,
      chapters: chapters,
      images: images,
    );
  }
}
