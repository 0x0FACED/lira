import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/favorite_books_provider.dart';

Future<bool> confirmBookDeletion(BuildContext context, BookDto book) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: Text(l10n.deleteBook),
      content: Text(l10n.bookDeleteWarning(book.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialog).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<void> setBookReadMark(
  BuildContext context,
  WidgetRef ref,
  BookDto book,
  bool marked,
) async {
  try {
    final current = await ref.read(
      readingProgressControllerProvider(book.id).future,
    );
    final controller = ref.read(
      readingProgressControllerProvider(book.id).notifier,
    );
    final location = marked
        ? (book.format.toLowerCase() == 'pdf' && book.pageCount > 0
              ? book.pageCount.toString()
              : (current?.location ?? ''))
        : '';
    await controller.saveProgress(
      location: location,
      percentage: marked ? 100.0 : 0.0,
    );
    await controller.flush();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.bookReadMarkError)),
    );
  }
}

/// Toggles [bookId] in favorites and displays a snackbar on failure.
Future<void> setBookFavorite(
  BuildContext context,
  WidgetRef ref,
  String bookId,
  bool isFavorite,
) async {
  try {
    await ref
        .read(favoriteBookIdsProvider.notifier)
        .setFavorite(bookId, isFavorite);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.bookFavoriteError)),
    );
  }
}
