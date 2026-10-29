import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../books/domain/providers/books_provider.dart';
import '../../domain/models/search_result_item.dart';
import '../../domain/providers/download_provider.dart';

class SearchBookCard extends ConsumerWidget {
  final SearchResultItem book;

  const SearchBookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final downloadProgress = ref.watch(
      downloadNotifierProvider.select((progress) => progress[book.id]),
    );
    final isDownloading = downloadProgress != null;
    final isAnna = book.source == SearchResultSource.anna;
    final action = AppStateTransition(
      child: isDownloading
          ? Row(
              key: ValueKey('downloading-${book.id}'),
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (downloadProgress > 0) ...[
                        Text(
                          '${(downloadProgress * 100).round()}%',
                          style: theme.textTheme.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      LinearProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: l10n.cancelDownload,
                  style: IconButton.styleFrom(
                    foregroundColor: colors.error,
                    minimumSize: const Size.square(AppLayout.minTouchTarget),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => ref
                      .read(downloadNotifierProvider.notifier)
                      .cancelDownload(book.id),
                ),
              ],
            )
          : Align(
              key: ValueKey('download-${book.id}'),
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                tooltip: l10n.downloadBook,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(AppLayout.minTouchTarget),
                ),
                icon: const Icon(Icons.download_rounded),
                onPressed: () => _handleDownload(context, ref),
              ),
            ),
    );

    return AppSurface(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: colors.surfaceContainer,
              child: book.imgUrl.isNotEmpty
                  ? Image.network(
                      book.imgUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      headers: isAnna
                          ? const {
                              'User-Agent':
                                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                            }
                          : null,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackCover(theme),
                    )
                  : _buildFallbackCover(theme),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  book.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  book.author,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppBadge(label: book.format.toUpperCase()),
                    AppBadge(
                      label: isAnna ? "Anna's" : 'Z-Lib',
                      color: isAnna ? colors.tertiary : colors.secondary,
                    ),
                    if (book.size.isNotEmpty)
                      AppBadge(label: book.size, icon: Icons.storage_outlined),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.menu_book_outlined,
        size: 32,
        color: theme.colorScheme.secondary,
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final downloads = ref.read(downloadNotifierProvider.notifier);
    try {
      await ref
          .read(booksControllerProvider.notifier)
          .downloadAndImportBook(book);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookDownloaded(book.title))),
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
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: TextStyle(color: colors.onError)),
          backgroundColor: colors.error,
        ),
      );
    } finally {
      downloads.finish(book.id);
    }
  }
}
