import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/book_dto.dart';
import '../book_labels.dart';
import '../book_page_progress.dart';
import 'book_cover.dart';

class BookCard extends StatelessWidget {
  final BookDto book;
  final VoidCallback onTap;
  final ValueChanged<BuildContext> onLongPress;
  final double? readingPercentage;
  final String? readingLocation;
  final bool isFavorite;
  final bool compact;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onLongPress,
    this.readingPercentage,
    this.readingLocation,
    this.isFavorite = false,
    this.compact = false,
  });

  static const coverAspectRatio = BookCover.aspectRatio;
  static const hitInset = 4.0;
  static const _titleSize = 14.0;
  static const _authorSize = 12.0;
  static const _metadataSize = 11.0;
  static const _progressBarHeight = 2.0;
  static const _lineHeight = 1.3;

  /// One metadata row keeps grid geometry independent of each book's values.
  static double metadataExtent(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return AppSpacing.compact +
        _textLineExtent(textScaler, _titleSize) * 2 +
        AppSpacing.xs +
        _textLineExtent(textScaler, _authorSize) +
        AppSpacing.xs +
        _textLineExtent(textScaler, _metadataSize) +
        AppSpacing.sm +
        _progressBarHeight;
  }

  static double _textLineExtent(TextScaler scaler, double size) =>
      (scaler.scale(size) * _lineHeight).ceilToDouble();

  static TextStyle? _fileMetadataStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        fontSize: _metadataSize,
        fontWeight: FontWeight.w400,
        height: _lineHeight,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: theme.colorScheme.onSurfaceVariant,
      );

  static TextStyle? _progressStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        fontSize: _metadataSize,
        fontWeight: FontWeight.w400,
        height: _lineHeight,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: theme.colorScheme.onSurface,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (compact) {
      return _BookCardInteraction(
        onTap: onTap,
        onLongPress: () => onLongPress(context),
        child: _buildCompactContent(context),
      );
    }
    final textScaler = MediaQuery.textScalerOf(context);
    return _BookCardInteraction(
      onTap: onTap,
      onLongPress: () => onLongPress(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookCover(book: book),
          const SizedBox(height: AppSpacing.compact),
          SizedBox(
            height: _textLineExtent(textScaler, _titleSize) * 2,
            child: Text(
              book.title.trim(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: _titleSize,
                letterSpacing: 0,
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
              bookAuthorLabel(book.author, l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: _authorSize,
                height: _lineHeight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(child: _buildFooter(context)),
        ],
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final textScaler = MediaQuery.textScalerOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: BookCover(book: book)),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Text(
                bookAuthorLabel(book.author, l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: _authorSize,
                  height: _lineHeight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildFooter(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(
    BuildContext context,
    BookProgressLabels labels,
  ) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final lineExtent = _textLineExtent(textScaler, _metadataSize);
    final markerSize = lineExtent - 1;
    final format = book.format.toUpperCase();
    final formatStyle = _fileMetadataStyle(theme);
    final progressStyle = _progressStyle(theme);
    return SizedBox(
      key: const ValueKey('book-card-metadata-row'),
      height: lineExtent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            locale: Localizations.localeOf(context),
            maxLines: 1,
          );
          double measure(String text, TextStyle? style) {
            painter.text = TextSpan(text: text, style: style);
            painter.layout();
            return painter.width;
          }

          late double width;
          var label = labels.full;
          try {
            final formatWidth =
                measure(format, formatStyle) +
                (isFavorite ? AppSpacing.xs + markerSize : 0);
            final gap = label.isEmpty ? 0.0 : AppSpacing.sm;
            width = formatWidth + gap + measure(label, progressStyle);
            if (width > constraints.maxWidth && labels.compact != label) {
              // Drop only the page unit before shrinking: every coordinate,
              // approximation marker and percentage remains visible.
              label = labels.compact;
              width = formatWidth + gap + measure(label, progressStyle);
            }
          } finally {
            painter.dispose();
          }
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: width > constraints.maxWidth
                  ? width
                  : constraints.maxWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        format,
                        key: const ValueKey('book-card-format'),
                        style: formatStyle,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      if (isFavorite) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IgnoreBaseline(
                          child: Icon(
                            Icons.favorite,
                            size: markerSize,
                            color: theme.colorScheme.primary,
                            semanticLabel: AppLocalizations.of(
                              context,
                            )!.bookFavoriteStatus,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Semantics(
                      label: AppLocalizations.of(
                        context,
                      )!.libraryReadingProgress,
                      value: labels.full,
                      excludeSemantics: true,
                      child: Text(
                        label,
                        key: const ValueKey('book-card-progress-label'),
                        style: progressStyle,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final percentage = readingPercentage?.isFinite == true
        ? readingPercentage!.clamp(0.0, 100.0)
        : null;
    // Manual completion is independent of both the position and the percentage.
    final labels = bookProgressLabels(
      l10n: l10n,
      book: book,
      readingPercentage: percentage,
      readingLocation: readingLocation,
      countFormat: NumberFormat.decimalPattern(l10n.localeName),
      percentageFormat: NumberFormat('0.0', l10n.localeName),
    );
    final track = SizedBox(
      height: _progressBarHeight,
      child: percentage == null
          ? null
          : ExcludeSemantics(
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: _progressBarHeight,
                color: compact ? null : theme.colorScheme.secondary,
                borderRadius: BorderRadius.zero,
                trackGap: 0,
                stopIndicatorColor: Colors.transparent,
              ),
            ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetadataRow(context, labels),
        const SizedBox(height: AppSpacing.sm),
        track,
      ],
    );
  }
}

class _BookCardInteraction extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  const _BookCardInteraction({
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      hoverColor: Colors.transparent,
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(BookCard.hitInset),
        child: child,
      ),
    ),
  );
}
