import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/providers/download_provider.dart';
import '../../../books/domain/providers/books_provider.dart';
import '../../domain/models/search_result_item.dart';

class SearchBookCard extends ConsumerWidget {
  final SearchResultItem book;

  const SearchBookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final downloadProgress = ref.watch(downloadNotifierProvider)[book.id];
    final isDownloading = downloadProgress != null;

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover
            SizedBox(
              width: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (book.imgUrl.isNotEmpty)
                    Image.network(
                      book.imgUrl,
                      fit: BoxFit.cover,
                      headers: book.source == SearchResultSource.anna
                          ? const {
                              'User-Agent':
                                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                            }
                          : null,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackCover(theme),
                    )
                  else
                    _buildFallbackCover(theme),

                  // Format badge overlay (top-right of cover)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.format.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Download overlay
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isDownloading
                        ? Container(
                            key: const ValueKey('downloading'),
                            color: Colors.black54,
                            child: Center(
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  value:
                                      downloadProgress > 0 ? downloadProgress : null,
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('idle')),
                  ),
                ],
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSourceBadge(context),
                        if (book.size.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.storage_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurface.withAlpha(80),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            book.size,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withAlpha(100),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action button
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: isDownloading
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.red.withAlpha(200),
                          backgroundColor: Colors.red.withAlpha(20),
                        ),
                        tooltip: 'Cancel download',
                        onPressed: () {
                          ref
                              .read(downloadNotifierProvider.notifier)
                              .cancelDownload(book.id);
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.download_rounded, size: 22),
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.primary.withAlpha(20),
                        ),
                        onPressed: () => _handleDownload(context, ref),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withAlpha(15),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 36,
          color: theme.colorScheme.primary.withAlpha(60),
        ),
      ),
    );
  }

  Widget _buildSourceBadge(BuildContext context) {
    final isAnna = book.source == SearchResultSource.anna;
    final color = isAnna ? Colors.blue : Colors.green;
    final label = isAnna ? "Anna's" : 'Z-Lib';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref
          .read(booksControllerProvider.notifier)
          .downloadAndImportBook(book, ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${book.title} downloaded and added to library.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      String errorMessage = e.toString();
      if (errorMessage.contains('duplicate_book')) {
        errorMessage = l10n.duplicateBookError;
      } else if (errorMessage.contains('download_cancelled')) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }
}
