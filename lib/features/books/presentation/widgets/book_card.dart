import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/book_dto.dart';
import '../book_labels.dart';
import 'book_cover.dart';

class BookCard extends StatelessWidget {
  final BookDto book;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final double? readingPercentage;
  final bool compact;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
    this.readingPercentage,
    this.compact = false,
  });

  static const coverAspectRatio = BookCover.aspectRatio;
  static const hitInset = 4.0;
  static const _titleSize = 14.0;
  static const _authorSize = 12.0;
  static const _progressSize = 11.0;
  static const _progressBarHeight = 2.0;
  static const _lineHeight = 1.3;

  /// Reserve the same caption height for every book in the grid.
  static double metadataExtent(TextScaler textScaler) =>
      AppSpacing.compact +
      _textLineExtent(textScaler, _titleSize) * 2 +
      AppSpacing.xs +
      _textLineExtent(textScaler, _authorSize) +
      AppSpacing.sm +
      _textLineExtent(textScaler, _progressSize) +
      AppSpacing.sm +
      _progressBarHeight;

  static double _textLineExtent(TextScaler scaler, double size) =>
      (scaler.scale(size) * _lineHeight).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (compact) {
      return _BookCardInteraction(
        onTap: onTap,
        onLongPress: () => _confirmDelete(context),
        child: _buildCompactContent(context),
      );
    }
    final textScaler = MediaQuery.textScalerOf(context);
    return _BookCardInteraction(
      onTap: onTap,
      onLongPress: () => _confirmDelete(context),
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
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildFooter(context)),
        ],
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
              Text(
                book.title.trim(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w500,
                  height: _lineHeight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: AppSpacing.sm),
              _buildFooter(context),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
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
    final l10n = AppLocalizations.of(context)!;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: _progressSize,
      fontWeight: FontWeight.w400,
      height: _lineHeight,
      letterSpacing: 0,
    );
    final percentage = readingPercentage?.clamp(0.0, 100.0);
    // A rounded display must not claim completion before the real end event.
    final displayed = percentage == null
        ? null
        : formatReadingPercentage(percentage, l10n.localeName, floor: true);
    final progress = displayed == null
        ? null
        : Semantics(
            label: l10n.libraryReadingProgress,
            value: displayed,
            excludeSemantics: true,
            child: Text(displayed, style: style),
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
    if (!compact) {
      if (progress == null) return const SizedBox.shrink();
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _textLineExtent(
              MediaQuery.textScalerOf(context),
              _progressSize,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: progress,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          track,
        ],
      );
    }

    final metadata = Wrap(
      spacing: AppSpacing.xs,
      children: [
        Text(book.format.toUpperCase(), style: style),
        if (book.pageCount > 0) ...[
          ExcludeSemantics(child: Text('·', style: style)),
          Text(
            '${book.pageCount}',
            semanticsLabel: '${l10n.pages}: ${book.pageCount}',
            style: style,
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth =
            MediaQuery.textScalerOf(context).scale(_progressSize) *
            (book.format.length +
                (book.pageCount > 0 ? '${book.pageCount}'.length + 3 : 0) +
                (displayed?.length ?? 0)) *
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
            track,
          ],
        );
      },
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
