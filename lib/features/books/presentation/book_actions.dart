import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/domain/providers/manual_read_status_provider.dart';
import '../domain/models/book_dto.dart';

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
  String bookId,
  bool marked,
) async {
  try {
    await ref
        .read(manuallyReadBookIdsProvider.notifier)
        .setRead(bookId, marked);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.bookReadMarkError)),
    );
  }
}
