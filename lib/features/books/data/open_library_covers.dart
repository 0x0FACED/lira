import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'open_library_client.dart';

Future<File> newOpenLibraryCoverFile(String bookId) async {
  final directory = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'covers'),
  );
  await directory.create(recursive: true);
  return File(p.join(directory.path, '$bookId-ol-${const Uuid().v4()}.jpg'));
}

Future<void> deleteOpenLibraryCover(String bookId, String? path) async {
  if (path == null || !p.basename(path).startsWith('$bookId-ol-')) return;
  try {
    final directory = p.join(
      (await getApplicationDocumentsDirectory()).path,
      'covers',
    );
    if (p.equals(p.dirname(path), directory)) await File(path).delete();
  } on FileSystemException {
    // Best effort; the database already points to the selected cover.
  }
}

/// Zero means absent, a placeholder, or undecodable. Very large embedded
/// graphics are kept without decoding or reading them all into memory.
Future<int> _localShortSide(String? path) async {
  if (path == null || path.isEmpty) return 0;
  try {
    if (await File(path).length() > 12 * 1024 * 1024) return 300;
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final short = descriptor.width < descriptor.height
            ? descriptor.width
            : descriptor.height;
        if (short <= 1) return 0;
        if (descriptor.width * descriptor.height > 16 * 1024 * 1024) {
          return 300;
        }
        final codec = await descriptor.instantiateCodec(
          targetWidth: 1,
          targetHeight: 1,
        );
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          return short;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  } on Exception {
    return 0;
  }
}

bool _isQualityUpgrade(int existing, OpenLibraryCover cover) {
  final short = cover.width < cover.height ? cover.width : cover.height;
  return existing < 300 && short * 2 >= existing * 3;
}

Future<bool> recommendOpenLibraryCover(
  String? existingPath,
  OpenLibraryCover cover, {
  required bool sameEdition,
  required bool pdfPreview,
}) async {
  final existing = await _localShortSide(existingPath);
  return existing == 0 ||
      pdfPreview ||
      (sameEdition && _isQualityUpgrade(existing, cover));
}

Future<OpenLibraryCover?> findAutomaticOpenLibraryCover(
  OpenLibraryClient client,
  OpenLibraryCandidate candidate,
  String? existingPath,
) async {
  final coverId = candidate.coverId;
  if (!candidate.coverFromEdition || coverId == null) return null;
  try {
    final existing = await _localShortSide(existingPath);
    if (existing >= 300) return null;
    final cover = await client.fetchCover(coverId);
    return cover != null && _isQualityUpgrade(existing, cover) ? cover : null;
  } on Exception {
    // An optional cover must not block otherwise usable catalog metadata.
    return null;
  }
}
