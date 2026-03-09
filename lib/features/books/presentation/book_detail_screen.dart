import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/books_provider.dart';

class BookDetailScreen extends ConsumerWidget {
  final BookDto book;

  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final currentBook =
        ref
            .watch(booksControllerProvider)
            .valueOrNull
            ?.firstWhere((b) => b.id == book.id, orElse: () => book) ??
        book;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            // Dark overlay on back button so it's visible on any cover
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCover(context, currentBook),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentBook.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentBook.author,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showEditDialog(context, ref, l10n, currentBook),
                        tooltip: l10n.editBook,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentBook.format.toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details Section
                  Text(
                    l10n.details,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    Icons.pages_outlined,
                    l10n.pages,
                    currentBook.pageCount > 0
                        ? '${currentBook.pageCount}'
                        : l10n.unknown,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    context,
                    Icons.sd_storage_outlined,
                    l10n.size,
                    currentBook.fileSizeBytes > 0
                        ? _formatBytes(currentBook.fileSizeBytes)
                        : l10n.unknown,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    context,
                    Icons.calendar_today_outlined,
                    l10n.added,
                    '${currentBook.createdAt.year}-${currentBook.createdAt.month.toString().padLeft(2, '0')}-${currentBook.createdAt.day.toString().padLeft(2, '0')}',
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        context.push('/reader', extra: currentBook);
                      },
                      icon: const Icon(Icons.menu_book),
                      label: Text(
                        currentBook.format == 'epub'
                            ? l10n.readBook
                            : l10n.openBook,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.deleteBook),
                            content: Text(
                              l10n.deleteBookConfirm(currentBook.title),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref
                                      .read(booksControllerProvider.notifier)
                                      .removeBook(currentBook.id);
                                  context.pop();
                                },
                                child: Text(
                                  l10n.delete,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: Text(
                        l10n.delete,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
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
    final titleController = TextEditingController(text: currentBook.title);
    final authorController = TextEditingController(text: currentBook.author);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editBook),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: l10n.editBookTitle),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: authorController,
              decoration: InputDecoration(labelText: l10n.editBookAuthor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newAuthor = authorController.text.trim();

              if (newTitle.isNotEmpty) {
                final updatedBook = currentBook.copyWith(
                  title: newTitle,
                  author: newAuthor.isEmpty ? 'Unknown Author' : newAuthor,
                );

                ref
                    .read(booksControllerProvider.notifier)
                    .updateBook(updatedBook);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, BookDto currentBook) {
    if (currentBook.coverUrl != null &&
        currentBook.coverUrl!.isNotEmpty &&
        File(currentBook.coverUrl!).existsSync()) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.file(
          File(currentBook.coverUrl!), // <-- using ! here is safe due to check
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildFormatFallback(currentBook);
          },
        ),
      );
    }

    return _buildFormatFallback(currentBook);
  }

  Widget _buildFormatFallback(BookDto currentBook) {
    final isEpub = currentBook.format.toLowerCase() == 'epub';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isEpub
              ? [const Color(0xFF1B3A4B), const Color(0xFF0D253F)]
              : [const Color(0xFF3B1B2E), const Color(0xFF2D1426)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEpub ? Icons.auto_stories : Icons.picture_as_pdf,
              size: 80,
              color: isEpub ? const Color(0xFF64B5F6) : const Color(0xFFEF9A9A),
            ),
            const SizedBox(height: 16),
            Text(
              currentBook.format.toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isEpub
                    ? const Color(0xFF64B5F6)
                    : const Color(0xFFEF9A9A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
