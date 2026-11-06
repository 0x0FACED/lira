import 'package:epub_engine/epub_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/highlights/domain/models/highlight_dto.dart';
import 'package:lira/features/reader/domain/annotation_tools.dart';

final _book = BookDto(
  id: 'source-id',
  title: 'A [book] <title>',
  author: 'An *author*',
  format: 'epub',
  createdAt: DateTime.utc(2026, 1, 2),
);

const _labels = AnnotationExportLabels(
  title: 'Title',
  author: 'Author',
  format: 'Format',
  bookId: 'Book ID',
  sourceAdded: 'Added',
  exported: 'Exported',
  annotations: 'Annotations',
  note: 'Note',
  color: 'Color',
  created: 'Created',
  chapter: 'Chapter',
  page: 'Page',
);

HighlightDto _highlight({
  String id = 'one',
  String text = 'Quoted passage',
  String? note,
  String color = '#4CAF50',
  String location = 'opaque-location',
}) => HighlightDto(
  id: id,
  bookId: _book.id,
  text: text,
  color: color,
  location: location,
  note: note,
  createdAt: DateTime.utc(2026, 2, 3),
);

String _export(
  List<HighlightDto> items,
  AnnotationExportFormat format, {
  BookDto? book,
}) => exportAnnotations(
  book: book ?? _book,
  annotations: items,
  format: format,
  labels: _labels,
  exportedAt: DateTime.utc(2026, 3, 4),
);

void main() {
  group('annotation filters', () {
    final quoted = _highlight(id: 'quote', text: 'Mixed CASE цитата');
    final noted = _highlight(id: 'note', note: 'A SEARCHABLE заметка');
    final blank = _highlight(id: 'blank', note: ' \n\t', color: '#42A5F5');
    final all = [quoted, noted, blank];

    test('empty and whitespace query preserve order and annotations', () {
      expect(const AnnotationFilter().apply(all), all);
      expect(const AnnotationFilter(query: ' \n ').apply(all), all);
      expect(const AnnotationFilter(query: ' \n ').isActive, isFalse);
      expect(const AnnotationFilter().apply([]), isEmpty);
    });

    test('matches quote or note case insensitively, including Cyrillic', () {
      expect(const AnnotationFilter(query: ' cAsE ').apply(all), [quoted]);
      expect(const AnnotationFilter(query: 'searchable').apply(all), [noted]);
      expect(const AnnotationFilter(query: 'ЗАМЕТКА').apply(all), [noted]);
      expect(const AnnotationFilter(query: 'missing').apply(all), isEmpty);
    });

    test('all filters intersect and blank notes do not count', () {
      expect(const AnnotationFilter(hasNote: true).apply(all), [noted]);
      expect(
        const AnnotationFilter(
          query: 'заметка',
          color: '#4caf50',
          hasNote: true,
        ).apply(all),
        [noted],
      );
      expect(
        const AnnotationFilter(
          query: 'заметка',
          color: '#42A5F5',
          hasNote: true,
        ).apply(all),
        isEmpty,
      );
      expect(const AnnotationFilter(color: '#000000').apply(all), isEmpty);
    });
  });

  group('source-attributed export', () {
    test(
      'plain text preserves multiline quote and note plus source metadata',
      () {
        final quote = _highlight(
          text: '  first line\n\nlast line  ',
          note: 'note one\nnote two',
          location: EpubLocation.fromPosition(chapterIndex: 2).toJson(),
        );
        final output = _export([quote], AnnotationExportFormat.text);
        expect(output, contains(quote.text));
        expect(output, contains('Note: note one\nnote two'));
        expect(output, contains('Title: ${_book.title}'));
        expect(output, contains('Author: ${_book.author}'));
        expect(output, contains('Book ID: source-id'));
        expect(output, contains('Format: EPUB'));
        expect(output, contains('Chapter: 3'));
        expect(output, contains('Color: #4CAF50'));
        expect(output, contains('Created: 2026-02-03T00:00:00.000Z'));
        expect(output, contains('Exported: 2026-03-04T00:00:00.000Z'));
        expect(output, isNot(contains(quote.location)));
      },
    );

    test(
      'Markdown cannot inject headings, links, HTML, code or block quotes',
      () {
        final quote = _highlight(
          text:
              '# title\n\n[x](https://example.org)\n<script>bad</script>\n```\n> quote',
          note: 'note\n---\n![image](url)',
        );
        final output = _export([quote], AnnotationExportFormat.markdown);
        expect(output, contains(r'# A \[book\] \<title\>'));
        expect(output, contains(r'Author: An \*author\*'));
        expect(output, contains(r'> \# title'));
        expect(output, contains(r'> \[x\]\(https://example\.org\)'));
        expect(output, contains(r'> \<script\>bad\</script\>'));
        expect(output, contains(r'> \`\`\`'));
        expect(output, contains(r'> \> quote'));
        expect(output, isNot(contains('\n<script>')));
        expect(output, isNot(contains('\n---')));
      },
    );

    test(
      'only explicitly supplied selection is exported, in supplied order',
      () {
        final first = _highlight(text: 'first');
        final second = _highlight(
          id: 'two',
          text: 'second',
          note: 'Saved note',
        );
        final output = _export([second], AnnotationExportFormat.text);
        expect(output, contains('Annotations: 1'));
        expect(output, contains(second.text));
        expect(output, isNot(contains(first.text)));
        expect(
          _export([], AnnotationExportFormat.text),
          contains('Annotations: 0'),
        );
      },
    );

    test(
      'unknown locators are omitted, never presented as chapters or pages',
      () {
        final output = _export([_highlight()], AnnotationExportFormat.text);
        expect(output, isNot(contains('opaque-location')));
        expect(output, isNot(contains('Chapter:')));
        expect(output, isNot(contains('Page:')));
      },
    );

    test('PDF supports page locators and multi-page selected ranges', () {
      final pdf = _book.copyWith(format: 'pdf', pageCount: 20);
      final page = _export(
        [_highlight(location: '17')],
        AnnotationExportFormat.text,
        book: pdf,
      );
      expect(page, contains('Page: 17'));
      const range =
          '{"pdf":1,"p":2,"s":['
          '{"p":2,"r":[[0,4]],"q":[[0,10,10,0]]},'
          '{"p":3,"r":[[0,6]],"q":[[0,10,10,0]]}]}';
      expect(
        _export(
          [_highlight(location: range)],
          AnnotationExportFormat.text,
          book: pdf,
        ),
        contains('Page: 2–3'),
      );
      expect(
        _export(
          [_highlight(location: '21')],
          AnnotationExportFormat.text,
          book: pdf,
        ),
        isNot(contains('Page:')),
      );
      expect(
        _export(
          [_highlight(location: '{"pdf":2}')],
          AnnotationExportFormat.text,
          book: pdf,
        ),
        isNot(contains('Page:')),
      );
    });

    test('clipboard attribution preserves the original quote verbatim', () {
      const text = ' first\n\nlast ';
      expect(
        attributedQuote(text, _book),
        '$text\n\n— ${_book.title} — ${_book.author}',
      );
    });
  });
}
