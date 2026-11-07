import 'package:epub_engine/epub_engine.dart';
import 'package:pdf_engine/pdf_engine.dart';

import '../../books/domain/models/book_dto.dart';
import '../../highlights/domain/models/highlight_dto.dart';

/// Filters intersect; a blank/whitespace-only note is not a saved note.
class AnnotationFilter {
  const AnnotationFilter({this.query = '', this.color, this.hasNote = false});

  final String query;
  final String? color;
  final bool hasNote;

  bool get isActive => query.trim().isNotEmpty || color != null || hasNote;

  List<HighlightDto> apply(Iterable<HighlightDto> annotations) {
    final needle = query.trim().toLowerCase();
    final selectedColor = color?.toLowerCase();
    return annotations.where((annotation) {
      if (selectedColor != null &&
          annotation.color.toLowerCase() != selectedColor)
        return false;
      if (hasNote && (annotation.note?.trim().isEmpty ?? true)) return false;
      return needle.isEmpty ||
          annotation.text.toLowerCase().contains(needle) ||
          (annotation.note?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }
}

enum AnnotationExportFormat { markdown, text }

/// Human-readable source position, resolved using the engines' own codecs.
/// EPUB spine positions have no stable print pagination.
class AnnotationSourcePosition {
  const AnnotationSourcePosition({this.chapter, this.firstPage, this.lastPage});

  final int? chapter;
  final int? firstPage;
  final int? lastPage;

  static AnnotationSourcePosition resolve(BookDto book, String locator) {
    if (book.format.toLowerCase() == 'pdf') {
      final position = PdfReaderLocation.tryParse(locator);
      if (position == null ||
          (book.pageCount > 0 && position.pageNumber > book.pageCount)) {
        return const AnnotationSourcePosition();
      }
      final last = position.selections.isEmpty
          ? position.pageNumber
          : position.selections.last.pageNumber;
      return AnnotationSourcePosition(
        firstPage: position.pageNumber,
        lastPage: book.pageCount > 0 && last > book.pageCount
            ? position.pageNumber
            : last,
      );
    }
    if (book.format.toLowerCase() == 'epub') {
      final position = EpubLocation.fromJson(locator);
      if (position != null && position.chapterIndex >= 0) {
        return AnnotationSourcePosition(chapter: position.chapterIndex + 1);
      }
    }
    return const AnnotationSourcePosition();
  }
}

/// Labels come from the active locale, keeping exported documents localized.
class AnnotationExportLabels {
  const AnnotationExportLabels({
    required this.title,
    required this.author,
    required this.format,
    required this.bookId,
    required this.sourceAdded,
    required this.exported,
    required this.annotations,
    required this.note,
    required this.color,
    required this.created,
    required this.chapter,
    required this.page,
  });

  final String title;
  final String author;
  final String format;
  final String bookId;
  final String sourceAdded;
  final String exported;
  final String annotations;
  final String note;
  final String color;
  final String created;
  final String chapter;
  final String page;
}

bool _hasAuthor(BookDto book) =>
    book.author.trim().isNotEmpty &&
    book.author.trim().toLowerCase() != 'unknown author';

String attributedQuote(String text, BookDto book) =>
    '$text\n\n— ${book.title}${_hasAuthor(book) ? ' — ${book.author}' : ''}';

String exportAnnotations({
  required BookDto book,
  required Iterable<HighlightDto> annotations,
  required AnnotationExportFormat format,
  required AnnotationExportLabels labels,
  required DateTime exportedAt,
}) {
  final markdown = format == AnnotationExportFormat.markdown;
  final items = annotations.toList();
  final output = StringBuffer();
  String escape(String value) =>
      markdown ? _escapeMarkdown(value).replaceAll('\n', '  \n') : value;
  void metadata(String label, String value) {
    output.writeln('${escape(label)}: ${escape(value)}');
    if (markdown) output.writeln();
  }

  if (markdown) output.writeln('# ${escape(book.title)}\n');
  metadata(labels.title, book.title);
  if (_hasAuthor(book)) metadata(labels.author, book.author);
  metadata(labels.format, book.format.toUpperCase());
  metadata(labels.bookId, book.id);
  metadata(labels.sourceAdded, book.createdAt.toUtc().toIso8601String());
  metadata(labels.exported, exportedAt.toUtc().toIso8601String());
  metadata(labels.annotations, '${items.length}');

  for (var index = 0; index < items.length; index++) {
    final item = items[index];
    output.writeln(markdown ? '## ${index + 1}\n' : '\n${index + 1}.');
    if (markdown) {
      // Prefix every line, including empty ones: quotes cannot break out of
      // their block or inject headings, HTML, links or fenced code.
      for (final line in item.text.split('\n')) {
        output.writeln('> ${escape(line)}  ');
      }
      output.writeln();
    } else {
      output.writeln(item.text);
      output.writeln();
    }
    if (item.note != null && item.note!.isNotEmpty) {
      metadata(labels.note, item.note!);
    }
    final position = AnnotationSourcePosition.resolve(book, item.location);
    if (position.chapter != null) {
      metadata(labels.chapter, '${position.chapter}');
    }
    if (position.firstPage != null) {
      final pages = position.firstPage == position.lastPage
          ? '${position.firstPage}'
          : '${position.firstPage}–${position.lastPage}';
      metadata(labels.page, pages);
    }
    metadata(labels.color, item.color);
    metadata(labels.created, item.createdAt.toUtc().toIso8601String());
  }
  return output.toString();
}

String _escapeMarkdown(String value) => value.replaceAllMapped(
  RegExp(r'[\\`*_{}\[\]()<>#+=.!|~&\-]'),
  (match) => '\\${match[0]}',
);
