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
  final double? readingPercentage;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
    this.readingPercentage,
  });

  static const coverAspectRatio = 2 / 3;
  static const _titleSize = 14.0;
  static const _authorSize = 12.0;
  static const _lineHeight = 1.3;

  /// A shared budget keeps covers and reading metadata aligned across a shelf.
  static double metadataExtent(
    TextScaler textScaler, {
    required double cardWidth,
    required int pageCountDigits,
  }) {
    final width = cardWidth.clamp(1.0, double.infinity);
    final metadataLines =
        (textScaler.scale(11) * (pageCountDigits + 7) * 0.8 / width).ceil();
    final progressLines = (textScaler.scale(11) * 7 * 0.8 / width).ceil();
    return AppSpacing.compact +
        _textLineExtent(textScaler, _titleSize) * 2 +
        AppSpacing.xs +
        _textLineExtent(textScaler, _authorSize) +
        AppSpacing.sm +
        _textLineExtent(textScaler, 11) * (metadataLines + progressLines) +
        AppSpacing.xs +
        AppSpacing.sm +
        2;
  }

  static double _textLineExtent(TextScaler scaler, double size) =>
      (scaler.scale(size) * _lineHeight).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        onLongPress: () => _confirmDelete(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: coverAspectRatio,
              child: Semantics(
                image: true,
                label: book.title,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: _buildCover(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            SizedBox(
              height: _textLineExtent(textScaler, _titleSize) * 2,
              child: Text(
                book.title.trim(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w500,
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
    );
  }

  Future<void> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showAppDialog<void>(
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
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              onDelete();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w400,
      height: _lineHeight,
      letterSpacing: 0,
    );
    final percentage = readingPercentage?.clamp(0.0, 100.0);
    // A rounded display must not claim completion before the real end event.
    final displayed = percentage == null
        ? null
        : ((percentage * 10).floor() / 10).toStringAsFixed(1);
    final metadata = Wrap(
      spacing: AppSpacing.xs,
      children: [
        Text(book.format.toUpperCase(), style: style),
        if (book.pageCount > 0) ...[
          ExcludeSemantics(child: Text('·', style: style)),
          Text(
            '${book.pageCount}',
            semanticsLabel:
                '${AppLocalizations.of(context)!.pages}: ${book.pageCount}',
            style: style,
          ),
        ],
      ],
    );
    final progress = displayed == null
        ? null
        : Semantics(
            label: AppLocalizations.of(context)!.libraryReadingProgress,
            value: '$displayed%',
            excludeSemantics: true,
            child: Text('$displayed%', style: style),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth =
            MediaQuery.textScalerOf(context).scale(11) *
            (book.format.length +
                (book.pageCount > 0 ? '${book.pageCount}'.length + 3 : 0) +
                (displayed == null ? 0 : displayed.length + 1)) *
            0.8;
        final stacked = constraints.maxWidth < labelWidth + AppSpacing.sm;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked) ...[
              metadata,
              if (progress != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerRight, child: progress),
              ],
            ] else
              Row(
                children: [
                  Expanded(child: metadata),
                  if (progress != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    progress,
                  ],
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 2,
              child: percentage == null
                  ? null
                  : ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 2,
                        borderRadius: BorderRadius.zero,
                        trackGap: 0,
                        stopIndicatorColor: Colors.transparent,
                      ),
                    ),
            ),
          ],
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
            _buildTypographicCover(context),
      );
    }
    return _buildTypographicCover(context);
  }

  Widget _buildTypographicCover(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final paper = switch (book.title.hashCode.abs() % 3) {
      0 => colors.surfaceContainer,
      1 => colors.surfaceContainerHigh,
      _ => colors.surfaceContainerHighest,
    };
    // Generated artwork behaves like an image; accessible text below the
    // cover retains the full title/author and follows interface text scaling.
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = (constraints.maxWidth * 0.1).clamp(8.0, 24.0);
            return ColoredBox(
              color: paper,
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.author.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: (constraints.maxWidth * 0.055).clamp(
                          9.0,
                          12.0,
                        ),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          book.title.trim(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: (constraints.maxWidth * 0.12).clamp(
                              12.0,
                              26.0,
                            ),
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      book.format.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
