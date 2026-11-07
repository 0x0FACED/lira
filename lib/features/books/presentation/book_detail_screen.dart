import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/books_provider.dart';
import 'book_labels.dart';
import 'widgets/book_cover.dart';

class BookDetailScreen extends ConsumerWidget {
  final BookDto book;

  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentBook =
        ref
            .watch(booksControllerProvider)
            .valueOrNull
            ?.firstWhere((b) => b.id == book.id, orElse: () => book) ??
        book;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: l10n.details,
                    leading: MergeSemantics(
                      child: Semantics(
                        label: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        child: BackButton(onPressed: () => context.pop()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.pageGutter(context),
                      0,
                      AppLayout.pageGutter(context),
                      AppSpacing.lg,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cover = SizedBox(
                          width: 240,
                          child: BookCover(book: currentBook),
                        );
                        final details = _buildDetails(
                          context,
                          ref,
                          l10n,
                          currentBook,
                        );
                        if (constraints.maxWidth >= 720) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cover,
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: details),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: cover),
                            const SizedBox(height: AppSpacing.lg),
                            details,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookDto currentBook,
  ) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                currentBook.title,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: Semantics(
                label: l10n.editBook,
                child: const Icon(Icons.edit_outlined),
              ),
              onPressed: () => _showEditDialog(context, ref, l10n, currentBook),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          bookAuthorLabel(currentBook.author, l10n),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.compact),
        AppMetadata(label: currentBook.format.toUpperCase()),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => context.push('/reader', extra: currentBook),
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(
            currentBook.format == 'epub' ? l10n.readBook : l10n.openBook,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildDetailRow(
          context,
          l10n.pages,
          currentBook.pageCount > 0 ? '${currentBook.pageCount}' : l10n.unknown,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildDetailRow(
          context,
          l10n.size,
          currentBook.fileSizeBytes > 0
              ? _formatBytes(currentBook.fileSizeBytes, l10n.localeName)
              : l10n.unknown,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildDetailRow(
          context,
          l10n.added,
          '${currentBook.createdAt.year}-${currentBook.createdAt.month.toString().padLeft(2, '0')}-${currentBook.createdAt.day.toString().padLeft(2, '0')}',
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: colors.error),
          onPressed: () => showAppDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: Text(l10n.deleteBook),
              content: Text(l10n.deleteBookConfirm(currentBook.title)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    ref
                        .read(booksControllerProvider.notifier)
                        .removeBook(currentBook.id);
                    context.pop();
                  },
                  child: Text(l10n.delete),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.delete, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Text('$label: $value', style: Theme.of(context).textTheme.bodySmall);
  }

  String _formatBytes(int bytes, String locale) {
    const suffixes = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < suffixes.length - 1) {
      size /= 1024;
      unit++;
    }
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(size);
    return '$number ${suffixes[unit]}';
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookDto currentBook,
  ) {
    var title = currentBook.title;
    var author = currentBook.author.trim() == 'Unknown Author'
        ? ''
        : currentBook.author;

    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.editBook),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: currentBook.title,
              onChanged: (value) => title = value,
              decoration: InputDecoration(labelText: l10n.editBookTitle),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              initialValue: author,
              onChanged: (value) => author = value,
              decoration: InputDecoration(labelText: l10n.editBookAuthor),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = title.trim();
              final newAuthor = author.trim();
              if (newTitle.isNotEmpty) {
                ref
                    .read(booksControllerProvider.notifier)
                    .updateBook(
                      currentBook.copyWith(title: newTitle, author: newAuthor),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
