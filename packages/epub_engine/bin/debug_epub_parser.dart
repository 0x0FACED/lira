import 'dart:io';
import 'dart:typed_data';

import 'package:epub_engine/epub_engine.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run bin/debug_epub_parser.dart <epub-file> [...]');
    exit(64);
  }

  for (final path in args) {
    final bytes = await File(path).readAsBytes();
    final parsed = await EpubParser.parse(Uint8List.fromList(bytes));

    stdout.writeln('FILE: $path');
    stdout.writeln('TITLE: ${parsed.title}');
    stdout.writeln('AUTHOR: ${parsed.author}');
    stdout.writeln('COVER: ${parsed.coverImage?.length ?? 0}');
    stdout.writeln('CHAPTERS: ${parsed.chapters.length}');
    for (final chapter in parsed.chapters.take(10)) {
      stdout.writeln(
        '  CH: title="${chapter.title}" file="${chapter.fileName}" html=${chapter.htmlContent.trim().length}',
      );
    }
    stdout.writeln('TOC ROOT: ${parsed.toc.length}');
    _printToc(parsed.toc, 0, maxDepth: 2, maxItemsPerLevel: 10);
    stdout.writeln('---');
  }
}

void _printToc(
  List<TOCItem> items,
  int depth, {
  required int maxDepth,
  required int maxItemsPerLevel,
}) {
  if (depth > maxDepth) return;
  for (final item in items.take(maxItemsPerLevel)) {
    stdout.writeln(
      '${'  ' * depth}TOC[$depth]: title="${item.title}" file="${item.fileName}" sub=${item.subItems.length}',
    );
    if (item.subItems.isNotEmpty) {
      _printToc(
        item.subItems,
        depth + 1,
        maxDepth: maxDepth,
        maxItemsPerLevel: maxItemsPerLevel,
      );
    }
  }
}
