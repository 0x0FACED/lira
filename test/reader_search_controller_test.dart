import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/reader/domain/engine/book_reader_engine.dart';
import 'package:lira/features/reader/domain/models/book_location.dart';
import 'package:lira/features/reader/domain/models/book_search.dart';
import 'package:lira/features/reader/presentation/reader_search_controller.dart';

class _DelayedSearchEngine implements BookReaderEngine {
  final requests = <BookSearchRequest>[];
  final pending = <Completer<BookSearchResults>>[];

  @override
  Future<BookSearchResults> search(BookSearchRequest request) {
    requests.add(request);
    final completer = Completer<BookSearchResults>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BookSearchResults _results() => BookSearchResults(
  hasText: true,
  matches: [
    for (var index = 0; index < 2; index++)
      BookSearchMatch(
        location: BookLocation(locator: 'result-$index'),
        excerpt: BookTextMatch('a matching passage', 2, 10),
        sectionIndex: index,
      ),
  ],
);

void main() {
  test('query punctuation is literal and whitespace keeps source offsets', () {
    const source = 'C++ and c++: a.\n\tB, not ax b';
    final plus = BookSearchRequest('c++').matches(source).toList();
    expect(plus.map((match) => (match.start, match.end)), [(0, 3), (8, 11)]);
    final phrase = BookSearchRequest('a. b').matches(source).single;
    expect(source.substring(phrase.start, phrase.end), 'a.\n\tB');
    expect(phrase.text, 'a. B');
  });

  test(
    'a late failure cannot clear newer results or the selected match',
    () async {
      final engine = _DelayedSearchEngine();
      final search = ReaderSearchController(engine);
      addTearDown(search.dispose);
      search.updateQuery('old');
      final old = search.searchNow();
      search.updateQuery('new');
      final current = search.searchNow();
      expect(engine.requests.first.isCancelled, isTrue);
      engine.pending.last.complete(_results());
      await current;
      search.select(1);
      engine.pending.first.completeError(StateError('Old query failed'));
      await old;
      expect(search.activeIndex, 1);
      expect(search.error, isNull);
      expect(search.isSearching, isFalse);
      expect(search.hasSearched, isTrue);
    },
  );

  test(
    'clearing or disposing during search cannot resurrect a session',
    () async {
      final engine = _DelayedSearchEngine();
      final search = ReaderSearchController(engine);
      search.updateQuery('clear');
      final clearing = search.searchNow();
      search.clear();
      engine.pending.first.complete(_results());
      await clearing;
      expect(search.matches, isEmpty);
      expect(search.query, isEmpty);
      expect(search.activeIndex, -1);
      expect(search.hasSearched, isFalse);
      search.updateQuery('dispose');
      final disposing = search.searchNow();
      var notifications = 0;
      search.addListener(() => notifications++);
      search.dispose();
      engine.pending.last.completeError(StateError('Document closed'));
      await disposing;
      expect(engine.requests.last.isCancelled, isTrue);
      expect(notifications, 0);
    },
  );
}
