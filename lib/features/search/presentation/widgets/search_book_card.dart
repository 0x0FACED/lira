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

    // Watch download progress (0.0 to 1.0), or null if not downloading
    final downloadProgress = ref.watch(downloadNotifierProvider)[book.id];
    final isDownloading = downloadProgress != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: theme.colorScheme.shadow.withAlpha(40),
      child: SizedBox(
        height: 130, // Increased height to prevent overflow
        child: Row(
          children: [
            // Cover Area
            SizedBox(
              width: 100, // Slightly reduced width to match new proportions, or keep 120? Let's use 100 to make it more vertical rectangle
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (book.imgUrl.isNotEmpty)
                    Image.network(
                      book.imgUrl,
                      fit: BoxFit.cover,
                      headers: book.source == SearchResultSource.anna 
                        ? const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'} 
                        : null,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackCover(theme),
                    )
                  else
                    _buildFallbackCover(theme),

                  // Download Overlay with animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isDownloading
                        ? Container(
                            key: const ValueKey('downloading'),
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(
                                // -1 means indeterminate (preparing), 0+ means actual progress
                                value: downloadProgress > 0
                                    ? downloadProgress
                                    : null,
                                color: _getContrastColor(context),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('idle')),
                  ),
                ],
              ),
            ),

            // Book Info Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildBadge(
                          context,
                          book.source == SearchResultSource.anna ? "Anna's Archive" : 'Z-Library',
                          color: book.source == SearchResultSource.anna ? Colors.blue : Colors.green,
                        ),
                        _buildBadge(
                          context,
                          book.format.toUpperCase(),
                        ),
                        if (book.size.isNotEmpty)
                          Text(
                            book.size,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Download / Cancel Button Area
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: isDownloading
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      color: Colors.red,
                      tooltip: 'Cancel download',
                      onPressed: () {
                        ref
                            .read(downloadNotifierProvider.notifier)
                            .cancelDownload(book.id);
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.download_rounded),
                      color: theme.colorScheme.primary,
                      onPressed: () => _handleDownload(context, ref),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.book,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
      ),
    );
  }

  Color _getContrastColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Theme.of(context).colorScheme.primary;
  }

  Widget _buildBadge(BuildContext context, String text, {Color? color}) {
    final badgeColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
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
        // Download was cancelled by user — no error snackbar needed
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }
}

