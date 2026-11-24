import 'package:archive/archive.dart';

Future<T> parseEpubFile<T>(String path, T Function(Archive) parse) async {
  throw UnsupportedError(
    'EPUB file paths are supported on native platforms only',
  );
}
