import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../books/domain/providers/books_provider.dart';
import '../../../books/presentation/book_labels.dart';
import '../../../books/presentation/widgets/book_cover.dart';
import '../../domain/models/search_result_item.dart';
import '../../domain/providers/download_provider.dart';

class SearchBookCard extends ConsumerWidget {
  final SearchResultItem book;

  const SearchBookCard({super.key, required this.book});

  static String _sourceName(SearchResultItem book) =>
      book.source == SearchResultSource.anna ? "Anna's" : 'Z-Lib';

  static int metadataCharacterCount(SearchResultItem book) =>
      book.format.length +
      _sourceName(book).length +
      3 +
      (book.size.isEmpty ? 0 : book.size.length + 3);

  static String _metadata(SearchResultItem book) => [
    book.format.toUpperCase(),
    _sourceName(book),
    if (book.size.isNotEmpty) book.size,
  ].join(' · ');

  static double captionExtent(
    BuildContext context,
    double width,
    int maxMetadataCharacters,
  ) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = text.titleSmall!.copyWith(fontSize: 14, height: 1.4);
    final authorStyle = text.bodySmall!.copyWith(fontSize: 12, height: 1.4);
    double lineHeight(TextStyle style) =>
        scaler.scale(style.fontSize!) * (style.height ?? 1.2);
    final metadataCharactersPerLine = math.max(
      1,
      (width / scaler.scale(text.bodySmall!.fontSize!)).floor(),
    );
    final metadataLines =
        (maxMetadataCharacters / metadataCharactersPerLine).ceil() + 1;
    return (AppSpacing.compact +
            lineHeight(titleStyle) * 2 +
            AppSpacing.xs +
            lineHeight(authorStyle) +
            lineHeight(text.bodySmall!) * metadataLines +
            AppSpacing.sm * 2 +
            math.max(
              AppLayout.minTouchTarget,
              lineHeight(text.labelMedium!) + AppSpacing.xs + 4,
            ))
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = theme.textTheme.titleSmall!.copyWith(
      fontSize: 14,
      height: 1.4,
    );
    final authorStyle = theme.textTheme.bodySmall!.copyWith(
      fontSize: 12,
      height: 1.4,
    );
    final scaler = MediaQuery.textScalerOf(context);
    double lineHeight(TextStyle style) =>
        scaler.scale(style.fontSize!) * style.height!;
    final author = bookAuthorLabel(book.author, l10n);
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
                  color: colors.error,
                  icon: Semantics(
                    label: l10n.cancelDownload,
                    child: const Icon(Icons.close_rounded),
                  ),
                  onPressed: () => ref
                      .read(downloadNotifierProvider.notifier)
                      .cancelDownload(book.id),
                ),
              ],
            )
          : Align(
              key: ValueKey('download-${book.id}'),
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Semantics(
                  label: l10n.downloadBook,
                  child: const Icon(Icons.download_rounded),
                ),
                onPressed: () => _handleDownload(context, ref),
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                          _buildFallbackCover(author),
                    )
                  : _buildFallbackCover(author),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.compact),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: lineHeight(titleStyle) * 2,
                  child: Text(
                    book.title,
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: lineHeight(authorStyle),
                  child: Text(
                    author,
                    style: authorStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(_metadata(book), style: theme.textTheme.bodySmall),
                const Spacer(),
                const SizedBox(height: AppSpacing.sm),
                action,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackCover(String author) => TypographicBookCover(
    title: book.title,
    author: author,
    format: book.format,
  );

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
      final details = e.toString();
      if (details.contains('download_cancelled')) return;
      final duplicate = details.contains('duplicate_book');
      final errorMessage = duplicate
          ? l10n.duplicateBookError
          : l10n.searchDownloadFailed;
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: TextStyle(color: colors.onError)),
          action: duplicate
              ? null
              : SnackBarAction(
                  label: l10n.searchTechnicalDetails,
                  textColor: colors.onError,
                  onPressed: () => showAppDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.searchDownloadFailed),
                      content: SingleChildScrollView(
                        child: SelectableText(details),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            MaterialLocalizations.of(context).closeButtonLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          backgroundColor: colors.error,
        ),
      );
    } finally {
      downloads.finish(book.id);
    }
  }
}
