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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withAlpha(40),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withAlpha(10),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover — fixed 3:4 aspect ratio, entire cover visible
                AspectRatio(aspectRatio: 3 / 4, child: _buildCover(context)),
                // Info — takes exactly the remaining space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title - explicitly 1 line with ellipsis
                        Flexible(
                          child: Text(
                            book.title.trim(),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.2,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Author - explicitly 1 line with ellipsis
                        Text(
                          book.author.trim(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Format badge & extra info — aligned right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Left side: Page count if available
                            if (book.pageCount > 0)
                              Text(
                                '${book.pageCount} p.',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            // Right side: Format badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                book.format.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    if (book.coverUrl != null &&
        book.coverUrl!.isNotEmpty &&
        File(book.coverUrl!).existsSync()) {
      // Show entire cover inside the area — no cropping
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.file(File(book.coverUrl!), fit: BoxFit.contain),
      );
    }

    final isEpub = book.format.toLowerCase() == 'epub';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
