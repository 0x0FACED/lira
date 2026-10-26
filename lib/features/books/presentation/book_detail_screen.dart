import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/books_provider.dart';

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
      appBar: AppBar(
        title: Text(l10n.details),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        top: false,
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
                    title: currentBook.title,
                    subtitle: currentBook.author,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.editBook,
                        onPressed: () =>
                            _showEditDialog(context, ref, l10n, currentBook),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.compact,
                      0,
                      AppSpacing.compact,
                      AppSpacing.md,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cover = SizedBox(
                          width: 240,
                          child: AppSurface(
                            padding: EdgeInsets.zero,
                            radius: AppRadius.md,
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: _buildCover(context, currentBook),
                            ),
                          ),
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
                            const SizedBox(height: AppSpacing.md),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppBadge(label: currentBook.format.toUpperCase()),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurface(
          child: Column(
            children: [
              _buildDetailRow(
                context,
                Icons.pages_outlined,
                l10n.pages,
                currentBook.pageCount > 0
                    ? '${currentBook.pageCount}'
                    : l10n.unknown,
              ),
              const Divider(height: AppSpacing.md),
              _buildDetailRow(
                context,
                Icons.sd_storage_outlined,
                l10n.size,
                currentBook.fileSizeBytes > 0
                    ? _formatBytes(currentBook.fileSizeBytes)
                    : l10n.unknown,
              ),
              const Divider(height: AppSpacing.md),
              _buildDetailRow(
                context,
                Icons.calendar_today_outlined,
                l10n.added,
                '${currentBook.createdAt.year}-${currentBook.createdAt.month.toString().padLeft(2, '0')}-${currentBook.createdAt.day.toString().padLeft(2, '0')}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => context.push('/reader', extra: currentBook),
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(
            currentBook.format == 'epub' ? l10n.readBook : l10n.openBook,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: colors.error),
          onPressed: () => showAppDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
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

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = (bytes.toDouble() / 1024).floor().toString().length ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double size = bytes / (1024 * i > 0 ? 1024 * i : 1);
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookDto currentBook,
  ) {
    var title = currentBook.title;
    var author = currentBook.author;

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
              initialValue: currentBook.author,
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
                      currentBook.copyWith(
                        title: newTitle,
                        author: newAuthor.isEmpty
                            ? 'Unknown Author'
                            : newAuthor,
                      ),
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

  Widget _buildCover(BuildContext context, BookDto currentBook) {
    final path = currentBook.coverUrl;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) =>
            _buildFormatFallback(context, currentBook),
      );
    }
    return _buildFormatFallback(context, currentBook);
  }

  Widget _buildFormatFallback(BuildContext context, BookDto currentBook) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colors.outlineVariant, width: 3),
              top: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentBook.format.toLowerCase() == 'epub'
                      ? Icons.auto_stories_outlined
                      : Icons.description_outlined,
                  size: 64,
                  color: colors.secondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  currentBook.format.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
