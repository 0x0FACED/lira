import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Bidi, DateFormat;

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/discover_item.dart';
import '../domain/discover_source.dart';
import '../domain/material_controller.dart';

String discoverCategoryLabel(
  AppLocalizations l10n,
  DiscoverCategory category,
) => switch (category) {
  DiscoverCategory.books => l10n.discoverBooks,
  DiscoverCategory.blogs => l10n.discoverArticles,
  DiscoverCategory.documents => l10n.discoverDocuments,
};

IconData discoverCategoryIcon(DiscoverCategory category) => switch (category) {
  DiscoverCategory.books => Icons.menu_book_outlined,
  DiscoverCategory.blogs => Icons.article_outlined,
  DiscoverCategory.documents => Icons.description_outlined,
};

String discoverTopicLabel(AppLocalizations l10n, DiscoverTopic topic) =>
    switch (topic) {
      DiscoverTopic.technology => l10n.discoverTopicTechnology,
      DiscoverTopic.economics => l10n.discoverTopicEconomics,
      DiscoverTopic.nature => l10n.discoverTopicNature,
      DiscoverTopic.history => l10n.discoverTopicHistory,
      DiscoverTopic.culture => l10n.discoverTopicCulture,
      DiscoverTopic.psychology => l10n.discoverTopicPsychology,
      DiscoverTopic.science => l10n.discoverTopicScience,
    };

String discoverSourceLanguageLabel(
  AppLocalizations l10n,
  DiscoverSourceLanguage language,
) => switch (language) {
  DiscoverSourceLanguage.russian => l10n.discoverLanguageRussian,
  DiscoverSourceLanguage.english => l10n.discoverLanguageEnglish,
  DiscoverSourceLanguage.multilingual => l10n.discoverLanguageMultilingual,
};

String discoverDate(
  BuildContext context,
  DateTime date, {
  bool monthOnly = false,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return monthOnly
      ? DateFormat.yMMM(locale).format(date.toUtc())
      : DateFormat.yMMMd(locale).format(date.toLocal());
}

void showDiscoverError(BuildContext context, String message) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: colors.onError)),
      backgroundColor: colors.error,
    ),
  );
}

class DiscoverContent extends StatelessWidget {
  const DiscoverContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
      child: child,
    ),
  );
}

class DiscoverProgress extends StatelessWidget {
  const DiscoverProgress({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppLayout.discoverProgressSize,
    child: CircularProgressIndicator(
      strokeWidth: AppLayout.discoverProgressStroke,
    ),
  );
}

class DiscoverSectionHeading extends StatelessWidget {
  const DiscoverSectionHeading({
    super.key,
    required this.source,
    required this.onTap,
    this.subtitle,
  });

  final DiscoverSource source;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.pageGutter(context),
            vertical: AppSpacing.compact,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.name, style: theme.textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class MaterialSaveButton extends ConsumerStatefulWidget {
  const MaterialSaveButton({
    super.key,
    required this.item,
    this.showLabel = false,
  });

  final DiscoverItem item;
  final bool showLabel;

  @override
  ConsumerState<MaterialSaveButton> createState() => _MaterialSaveButtonState();
}

class _MaterialSaveButtonState extends ConsumerState<MaterialSaveButton> {
  bool _saved = false;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant MaterialSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _saved = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final savedIds = ref.watch(savedMaterialIdsProvider);
    if (savedIds.asData case final data?) {
      _saved = data.value.contains(widget.item.id);
    }
    final saved = _saved;
    final preparing = ref.watch(
      materialControllerProvider.select(
        (states) => states[widget.item.id]?.isLoading ?? false,
      ),
    );
    final label = saved
        ? l10n.discoverSaved
        : _saving
        ? l10n.discoverPreparing
        : l10n.discoverSave;
    final icon = preparing
        ? const DiscoverProgress()
        : Icon(saved ? Icons.check_rounded : Icons.add_rounded);
    if (widget.showLabel) {
      return OutlinedButton.icon(
        onPressed: saved || _saving ? null : _save,
        icon: icon,
        label: Text(label),
      );
    }
    return IconButton(
      onPressed: saved || _saving ? null : _save,
      icon: Semantics(label: label, child: icon),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await ref
          .read(materialControllerProvider.notifier)
          .prepare(widget.item, save: true);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.discoverSavedMessage(widget.item.title))),
      );
    } catch (_) {
      if (mounted) showDiscoverError(context, l10n.discoverSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class DiscoverItemCard extends StatelessWidget {
  const DiscoverItemCard({
    super.key,
    required this.item,
    required this.source,
    required this.onTap,
  });

  static const _inset = AppSpacing.compact;

  static bool _isTextFirst(DiscoverItem item, DiscoverSource source) =>
      source.category == DiscoverCategory.documents || item.imageUrl == null;

  static TextStyle _titleStyle(TextTheme text) =>
      text.titleLarge!.copyWith(fontSize: 18, height: 1.3);

  static double shelfHeight(
    BuildContext context,
    DiscoverSource source,
    Iterable<DiscoverItem> items,
    double cardWidth,
  ) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double lines(TextStyle style, int count) =>
        (scaler.scale(style.fontSize!) * (style.height ?? 1)).ceilToDouble() *
        count;
    final smallLine = lines(text.bodySmall!, 1);
    final titleHeight = lines(_titleStyle(text), AppLayout.discoverTitleLines);
    final summaryHeight = lines(
      text.bodyMedium!,
      AppLayout.discoverSummaryLines,
    );
    final imageHeight =
        (cardWidth - _inset * 2) / AppLayout.discoverImageAspectRatio;
    var tallest = 0.0;
    // The viewport uses the largest caption budget so mixed cards share a
    // baseline for the save button.
    for (final item in items) {
      var height = titleHeight;
      if (item.documentNumber != null) height += smallLine + AppSpacing.xs;
      if (item.author.trim().isNotEmpty || item.publishedAt != null) {
        height += smallLine + AppSpacing.xs;
      }
      if (!_isTextFirst(item, source)) {
        height += imageHeight + AppSpacing.sm;
      } else if (item.summary.isNotEmpty) {
        height += summaryHeight + AppSpacing.sm;
      }
      if (height > tallest) tallest = height;
    }
    final footerHeight = smallLine > AppLayout.minTouchTarget
        ? smallLine
        : AppLayout.minTouchTarget;
    return _inset * 2 + tallest + AppSpacing.xs + footerHeight;
  }

  final DiscoverItem item;
  final DiscoverSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textFirst = _isTextFirst(item, source);
    final author = item.author.trim();
    final publishedAt = item.publishedAt;
    final date = publishedAt == null
        ? null
        : discoverDate(
            context,
            publishedAt,
            monthOnly: item.documentNumber != null,
          );
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!textFirst) ...[
                AspectRatio(
                  aspectRatio: AppLayout.discoverImageAspectRatio,
                  child: DiscoverImage(item: item, source: source),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (item.documentNumber != null) ...[
                Text(
                  'RFC ${item.documentNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                item.title,
                maxLines: AppLayout.discoverTitleLines,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(theme.textTheme),
              ),
              if (author.isNotEmpty || date != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _Byline(author: author, date: date),
              ],
              if (textFirst && item.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.summary,
                    maxLines: AppLayout.discoverSummaryLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: item.status == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: AppSpacing.xs,
                            ),
                            child: Text(
                              item.status!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                  ),
                  MaterialSaveButton(item: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Byline extends StatelessWidget {
  const _Byline({required this.author, required this.date});

  final String author;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Text entry(String value, {TextDirection? direction}) => Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: direction,
      style: style,
    );
    final published = date;
    if (author.isEmpty) return entry(published!);
    final name = entry(
      author,
      direction: Bidi.detectRtlDirectionality(author)
          ? TextDirection.rtl
          : TextDirection.ltr,
    );
    if (published == null) {
      return Align(alignment: AlignmentDirectional.centerStart, child: name);
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Flexible(child: name),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: ExcludeSemantics(child: Text('·', style: style)),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
            child: entry(published),
          ),
        ],
      ),
    );
  }
}

class DiscoverImage extends StatelessWidget {
  const DiscoverImage({super.key, required this.item, required this.source});
  final DiscoverItem item;
  final DiscoverSource source;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.compact),
        child: Text(
          item.summary.isNotEmpty ? item.summary : source.name,
          maxLines: AppLayout.discoverSummaryLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ColoredBox(
        color: colors.surfaceContainer,
        child: item.imageUrl == null
            ? fallback
            : Image.network(
                item.imageUrl.toString(),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class DiscoverItemTile extends StatelessWidget {
  const DiscoverItemTile({
    super.key,
    required this.item,
    required this.source,
    required this.onTap,
  });

  final DiscoverItem item;
  final DiscoverSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.compact),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.documentNumber != null) ...[
              Text(
                'RFC ${item.documentNumber}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(item.title, style: theme.textTheme.titleMedium),
            if (item.author.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(item.author, style: theme.textTheme.bodySmall),
            ],
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.summary,
                maxLines: AppLayout.discoverSummaryLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      source.name,
                      if (item.publishedAt != null)
                        discoverDate(
                          context,
                          item.publishedAt!,
                          monthOnly: item.documentNumber != null,
                        ),
                      if (item.status != null) item.status!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MaterialSaveButton(item: item),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DiscoverFailure extends StatelessWidget {
  const DiscoverFailure({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.cloud_off_outlined,
    title: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(AppLocalizations.of(context)!.searchRetry),
    ),
  );
}
