import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/book_dto.dart';

class BookCard extends StatelessWidget {
  final BookDto book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Book'),
            content: Text('Are you sure you want to delete ${book.title}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildCover(context)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        book.format.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    // Show cover image if file exists
    if (book.coverUrl != null &&
        book.coverUrl!.isNotEmpty &&
        File(book.coverUrl!).existsSync()) {
      return Image.file(File(book.coverUrl!), fit: BoxFit.cover);
    }

    // Fallback: format-specific icon and color
    final isEpub = book.format.toLowerCase() == 'epub';
    return Container(
      color: isEpub ? const Color(0xFF1B3A4B) : const Color(0xFF3B1B2E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEpub ? Icons.auto_stories : Icons.picture_as_pdf,
              size: 48,
              color: isEpub ? const Color(0xFF64B5F6) : const Color(0xFFEF9A9A),
            ),
            const SizedBox(height: 8),
            Text(
              book.format.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
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
