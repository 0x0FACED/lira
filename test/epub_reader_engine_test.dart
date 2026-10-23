import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/reader/domain/engine/epub_book_reader_engine.dart';

void main() {
  test(
    'invalid EPUB load fails rather than exposing a fabricated error book',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);

      await expectLater(
        engine.loadBook(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isNotNull),
      );
      expect(engine.getToc(), isEmpty);
    },
  );
}
