import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/models/book_dto.dart';

bool get _usesNativeShare =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

bool get bookFileClipboardAvailable => switch (defaultTargetPlatform) {
  TargetPlatform.linux ||
  TargetPlatform.macOS ||
  TargetPlatform.windows => true,
  _ => false,
};

const _bookFileClipboard = MethodChannel('dev.0xfaced.lira/file_clipboard');

String bookExportActionLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return _usesNativeShare ? l10n.bookShare : l10n.exportBook;
}

/// Shares the original local file on mobile, or saves a copy on desktop.
/// Cancellation is silent; only a completed desktop copy reports success.
Future<void> exportBook(
  BuildContext context,
  BookDto book, {
  Rect? shareOrigin,
}) => _exportBook(context, book, shareOrigin: shareOrigin);

/// Puts a reference to the existing book file on the system clipboard.
Future<void> copyBookToClipboard(BuildContext context, BookDto book) =>
    _exportBook(context, book, toClipboard: true);

Future<void> _exportBook(
  BuildContext context,
  BookDto book, {
  Rect? shareOrigin,
  bool toClipboard = false,
}) async {
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final origin = !toClipboard && _usesNativeShare
      ? _shareOrigin(context, shareOrigin)
      : null;
  void showMessage(String message) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Directory? temporary;
  try {
    final extension = book.format.trim().toLowerCase();
    if (extension != 'epub' && extension != 'pdf') {
      showMessage(l10n.bookExportUnsupportedFormat);
      return;
    }
    final path = book.fileUrl;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      showMessage(l10n.bookExportFileMissing);
      return;
    }
    final source = File(path);
    if (toClipboard) {
      if (!bookFileClipboardAvailable) {
        throw UnsupportedError('File clipboard is only supported on desktop');
      }
      await _bookFileClipboard.invokeMethod<void>(
        'copyFile',
        source.absolute.path,
      );
      showMessage(l10n.bookFileCopied);
      return;
    }
    final filename = _exportFilename(book.title, extension);
    final mime = extension == 'epub'
        ? 'application/epub+zip'
        : 'application/pdf';
    if (_usesNativeShare) {
      // Real-path XFiles ignore name overrides, so give the shared copy its
      // readable name on disk without renaming or modifying the library file.
      temporary = await (await getTemporaryDirectory()).createTemp(
        'lira-book-export-',
      );
      final shared = await source.copy(p.join(temporary.path, filename));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(shared.path, mimeType: mime)],
          sharePositionOrigin: origin,
        ),
      );
    } else {
      final location = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          XTypeGroup(
            label: extension.toUpperCase(),
            extensions: [extension],
            mimeTypes: [mime],
            uniformTypeIdentifiers: [
              extension == 'epub' ? 'org.idpf.epub-container' : 'com.adobe.pdf',
            ],
          ),
        ],
      );
      if (location == null) return;
      // Resolve symlinks before identity comparison; identical itself compares
      // a link rather than its target. Identity also catches hard links.
      final destination = File(location.path);
      if (await destination.exists() &&
          await FileSystemEntity.identical(
            await source.resolveSymbolicLinks(),
            await destination.resolveSymbolicLinks(),
          )) {
        showMessage(l10n.bookExportSameFile);
        return;
      }
      await source.copy(location.path);
      showMessage(l10n.bookExportSaved(location.path));
    }
  } catch (_) {
    showMessage(toClipboard ? l10n.bookCopyFileError : l10n.bookExportError);
  } finally {
    if (temporary != null) {
      try {
        await temporary.delete(recursive: true);
      } on FileSystemException {
        // The OS can reclaim the copy if a share extension still holds it.
      }
    }
  }
}

String _exportFilename(String title, String extension) {
  var name = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]'), '_').trim();
  if (p.extension(name).toLowerCase() == '.$extension') {
    name = p.basenameWithoutExtension(name);
  }
  name = String.fromCharCodes(
    name.runes.take(60),
  ).replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (name.isEmpty) name = 'book';
  if (RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
    caseSensitive: false,
  ).hasMatch(name)) {
    name = '_$name';
  }
  return '$name.$extension';
}

Rect _shareOrigin(BuildContext context, Rect? requested) {
  final size = MediaQuery.sizeOf(context);
  final viewport = Offset.zero & size;
  if (requested != null && requested.isFinite && !requested.isEmpty) {
    final visible = requested.intersect(viewport);
    if (!visible.isEmpty) return visible;
  }
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final route = (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        .intersect(viewport);
    if (!route.isEmpty) {
      return Rect.fromCenter(center: route.center, width: 1, height: 1);
    }
  }
  return Rect.fromCenter(center: viewport.center, width: 1, height: 1);
}
