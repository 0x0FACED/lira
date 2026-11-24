import 'dart:isolate';

import 'package:archive/archive_io.dart';

Future<T> parseEpubFile<T>(String path, T Function(Archive) parse) {
  return Isolate.run(() {
    // Archive keeps compressed entries as file-backed slices. Its bounded file
    // buffer and per-entry reads never materialize the complete ZIP in Dart.
    final input = InputFileStream(path);
    try {
      return parse(ZipDecoder().decodeBuffer(input, verify: false));
    } finally {
      input.closeSync();
    }
  });
}
