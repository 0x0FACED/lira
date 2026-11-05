import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';
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

  static const coverAspectRatio = 2 / 3;
  static const _titleSize = 13.0;
  static const _authorSize = 11.0;
  static const _lineHeight = 1.3;

  /// Reserves the same text budget for every book, including a stacked footer.
  static double metadataExtent(
    TextScaler textScaler, {
    required double cardWidth,
    required int pageCountDigits,
  }) {
    final contentWidth = (cardWidth - AppSpacing.sm * 2).clamp(
      1.0,
      double.infinity,
    );
    // Bound digit advances including letter spacing; no per-card text layout.
    final pageLines =
        (textScaler.scale(11) * pageCountDigits * 1.1 / contentWidth).ceil();
    return AppSpacing.sm * 2 +
        _textLineExtent(textScaler, _titleSize) * 2 +
        AppSpacing.xs +
        _textLineExtent(textScaler, _authorSize) +
        AppSpacing.sm +
        _textLineExtent(textScaler, 11) * (pageLines + 1) +
        AppSpacing.xs * 3;
  }

  static double _textLineExtent(TextScaler scaler, double size) =>
      (scaler.scale(size) * _lineHeight).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final textScaler = MediaQuery.textScalerOf(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      onTap: onTap,
      onLongPress: () => showAppDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.deleteBook),
          content: Text(l10n.deleteBookConfirm(book.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onDelete();
              },
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: coverAspectRatio,
            child: Semantics(
              image: true,
              label: book.title,
              child: _buildCover(context),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _textLineExtent(textScaler, _titleSize) * 2,
                    child: Text(
                      book.title.trim(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: _titleSize,
                        height: _lineHeight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: _textLineExtent(textScaler, _authorSize),
                    child: Text(
                      book.author.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: _authorSize,
                        height: _lineHeight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(child: _buildFooter(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final format = AppBadge(label: book.format.toUpperCase());
    if (book.pageCount <= 0) {
      return Align(alignment: Alignment.bottomLeft, child: format);
    }
    final pageCount = '${book.pageCount}';
    final pagesLabel = '${AppLocalizations.of(context)!.pages}: $pageCount';
    final pages = Text(
      pageCount,
      semanticsLabel: pagesLabel,
      textAlign: TextAlign.right,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Conservatively allow space for both labels without measuring text
        // for every card. Narrow / large-text cards use the reserved rows.
        final labelWidth =
            MediaQuery.textScalerOf(context).scale(11) *
            (book.format.length + pageCount.length) *
            0.8;
        final stacked =
            constraints.maxWidth <
            labelWidth + AppSpacing.sm * 2 + AppSpacing.xs;
        if (stacked) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: format),
              const SizedBox(height: AppSpacing.xs),
              pages,
            ],
          );
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            children: [
              format,
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: pages),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCover(BuildContext context) {
    final path = book.coverUrl;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildFormatFallback(context),
      );
    }
    return _buildFormatFallback(context);
  }

  Widget _buildFormatFallback(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colors.outlineVariant, width: 3),
              top: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Center(
            child: Icon(
              book.format.toLowerCase() == 'epub'
                  ? Icons.auto_stories_outlined
                  : Icons.description_outlined,
              size: 36,
              color: colors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
