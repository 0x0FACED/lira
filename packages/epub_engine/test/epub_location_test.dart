import 'dart:convert';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy saved location retains chapter, anchor, pixels and selection',
    () {
      final location = EpubLocation.fromJson(
        '{"s":2,"a":"part","c":12,"f":0.4,"bo":34,"bf":0.5,"so":12,"eo":20}',
      )!;

      expect(location.chapterIndex, 2);
      expect(location.anchor, 'part');
      expect(location.charOffset, 12);
      expect(location.hasExactCharOffset, isFalse);
      expect(location.scrollFraction, 0.4);
      expect(location.bookScrollOffset, 34);
      expect(location.bookScrollFraction, 0.5);
      expect(location.startOffset, 12);
      expect(location.endOffset, 20);
      expect(EpubLocation.fromJson(location.toJson())!.cfi.hasRange, isTrue);
      expect(
        EpubLocation.fromJson(
          location.copyWith(charOffset: 20).toJson(),
        )!.hasExactCharOffset,
        isFalse,
      );
    },
  );

  test(
    'v2 content offsets remain distinguishable after copying and storage',
    () {
      final location = EpubLocation.fromPosition(
        chapterIndex: 2,
        charOffset: 120,
        hasExactCharOffset: true,
      ).copyWith(scrollFraction: 0.75);

      expect(jsonDecode(location.toJson())['v'], 2);
      final restored = EpubLocation.fromJson(location.toJson())!;
      expect(restored.hasExactCharOffset, isTrue);
      expect(restored.charOffset, 120);
      expect(restored.scrollFraction, 0.75);
    },
  );
}
