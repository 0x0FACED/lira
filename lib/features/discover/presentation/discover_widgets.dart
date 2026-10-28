import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
          padding: const EdgeInsets.all(AppSpacing.compact),
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
    return IconButton.filledTonal(
      tooltip: label,
      onPressed: saved || _saving ? null : _save,
      icon: icon,
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

  final DiscoverItem item;
  final DiscoverSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textFirst =
        source.category == DiscoverCategory.documents || item.imageUrl == null;
    return AppSurface(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!textFirst)
            AspectRatio(
              aspectRatio: AppLayout.discoverImageAspectRatio,
              child: DiscoverImage(item: item, source: source),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.documentNumber != null) ...[
                    Text(
                      'RFC ${item.documentNumber}',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    item.title,
                    maxLines: AppLayout.discoverTitleLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (item.author.isNotEmpty)
                    Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (item.publishedAt != null)
                    Text(
                      discoverDate(
                        context,
                        item.publishedAt!,
                        monthOnly: item.documentNumber != null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.status ?? source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      MaterialSaveButton(item: item),
                    ],
                  ),
                ],
              ),
            ),
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
    return ColoredBox(
      color: colors.surfaceContainer,
      child: item.imageUrl == null
          ? fallback
          : Image.network(
              item.imageUrl.toString(),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => fallback,
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
    return AppSurface(
      onTap: onTap,
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.documentNumber != null) ...[
            Text(
              'RFC ${item.documentNumber}',
              style: theme.textTheme.labelLarge,
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.compact),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(AppLocalizations.of(context)!.searchRetry),
        ),
      ],
    ),
  );
}
