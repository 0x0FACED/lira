import 'package:epub_engine/epub_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/bookmarks/domain/models/bookmark_dto.dart';
import 'package:lira/features/reader/domain/models/bookmark_region.dart';

String _epub(int offset, {int spine = 0, bool exact = true}) => EpubCfi(
  spineIndex: spine,
  charOffset: offset,
  hasExactCharOffset: exact,
).toJson();

BookmarkDto _bookmark(String id, String locator) => BookmarkDto(
  id: id,
  bookId: 'book',
  location: locator,
  percentage: 10,
  createdAt: DateTime(2026),
);

void main() {
  group('EPUB bookmark region', () {
    for (final delta in [-401, -400, -1, 0, 1, 400, 401]) {
      test('the inclusive 400-character boundary at delta $delta', () {
        final saved = _bookmark('saved', _epub(1000));
        expect(
          bookmarkNearLocation(
            bookmarks: [saved],
            format: 'epub',
            locator: _epub(1000 + delta),
          ),
          delta.abs() <= 400 ? same(saved) : isNull,
        );
      });
    }

    test('the same offset in another spine document does not match', () {
      expect(
        bookmarkNearLocation(
          bookmarks: [_bookmark('other-chapter', _epub(1000, spine: 1))],
          format: 'epub',
          locator: _epub(1000),
        ),
        isNull,
      );
    });

    test('an exact serialized location wins over nearby candidates', () {
      final locator = _epub(1000);
      final saved = _bookmark('exact', locator);
      expect(
        bookmarkNearLocation(
          bookmarks: [
            _bookmark('same-offset', '{"v":2,"s":0,"c":1000,"f":0.5}'),
            _bookmark('nearby', _epub(1001)),
            saved,
          ],
          format: 'epub',
          locator: locator,
        ),
        same(saved),
      );
    });

    test(
      'nearest offset wins and equal distances use a stable ID tie-break',
      () {
        final farther = _bookmark('0-farther', _epub(1200));
        final after = _bookmark('b-after', _epub(1010));
        final before = _bookmark('a-before', _epub(990));
        for (final candidates in [
          [farther, after, before],
          [before, after, farther],
        ]) {
          expect(
            bookmarkNearLocation(
              bookmarks: candidates,
              format: 'epub',
              locator: _epub(1000),
            ),
            same(before),
          );
        }
      },
    );

    test('legacy positions match only the unchanged serialized target', () {
      final saved = _bookmark('legacy', _epub(1000, exact: false));
      expect(
        bookmarkNearLocation(
          bookmarks: [saved],
          format: 'epub',
          locator: saved.location,
        ),
        same(saved),
      );
      for (final locator in [
        _epub(1001, exact: false),
        '{"s":0,"c":1000,"f":0.1}',
        _epub(1000),
      ]) {
        expect(
          bookmarkNearLocation(
            bookmarks: [saved],
            format: 'epub',
            locator: locator,
          ),
          isNull,
        );
      }
      expect(
        bookmarkNearLocation(
          bookmarks: [_bookmark('v2', _epub(1000))],
          format: 'epub',
          locator: saved.location,
        ),
        isNull,
      );
    });

    test('unknown versions and selection ranges are not nearby positions', () {
      final saved = _bookmark('v2', _epub(1000));
      for (final locator in [
        '{"v":3,"s":0,"c":1000,"f":0}',
        '{"v":2,"s":0,"c":1000,"f":0,"so":1000,"eo":1010}',
      ]) {
        expect(
          bookmarkNearLocation(
            bookmarks: [saved],
            format: 'epub',
            locator: locator,
          ),
          isNull,
        );
        expect(
          bookmarkNearLocation(
            bookmarks: [_bookmark('incompatible', locator)],
            format: 'epub',
            locator: saved.location,
          ),
          isNull,
        );
      }
    });

    test('a nearby match returns the original exact navigation target', () {
      const locator = '{"v":2,"s":0,"c":1000,"f":0.25,"bo":456.75}';
      final saved = _bookmark('saved', locator);
      final match = bookmarkNearLocation(
        bookmarks: [saved],
        format: 'epub',
        locator: _epub(1150),
      );
      expect(match, same(saved));
      expect(match!.location, locator);
    });
  });

  group('PDF bookmark region', () {
    const geometry =
        '{"pdf":1,"p":7,"s":[{"p":7,"r":[[4,8]],"q":[[10,40,30,20]]}]}';

    test('plain and structured locations on one page share a region', () {
      final saved = _bookmark('saved', geometry);
      expect(
        bookmarkNearLocation(bookmarks: [saved], format: 'pdf', locator: '7'),
        same(saved),
      );
      expect(saved.location, geometry);
      expect(
        bookmarkNearLocation(
          bookmarks: [_bookmark('plain', '7')],
          format: 'pdf',
          locator: geometry,
        )?.id,
        'plain',
      );
    });

    test('another page does not match and an exact page wins', () {
      final saved = _bookmark('exact', '7');
      expect(
        bookmarkNearLocation(
          bookmarks: [_bookmark('geometry', geometry), saved],
          format: 'pdf',
          locator: '7',
        ),
        same(saved),
      );
      expect(
        bookmarkNearLocation(bookmarks: [saved], format: 'pdf', locator: '8'),
        isNull,
      );
    });
  });

  test('empty, malformed, and incompatible formats do not match nearby', () {
    final saved = _bookmark('epub', _epub(1000));
    for (final locator in ['', 'not a locator', '7']) {
      expect(
        bookmarkNearLocation(
          bookmarks: [saved],
          format: 'epub',
          locator: locator,
        ),
        isNull,
      );
    }
    expect(
      bookmarkNearLocation(bookmarks: [saved], format: 'pdf', locator: '7'),
      isNull,
    );
    expect(
      bookmarkNearLocation(
        bookmarks: [saved],
        format: 'unknown',
        locator: _epub(1001),
      ),
      isNull,
    );
  });
}
