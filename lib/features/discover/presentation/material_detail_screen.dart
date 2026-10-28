import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/discover_item.dart';
import '../domain/discover_source.dart';
import '../domain/material_controller.dart';
import 'discover_widgets.dart';

void openMaterialDetail(
  BuildContext context,
  DiscoverItem item,
  DiscoverSource source,
) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MaterialDetailScreen(item: item, source: source),
    ),
  );
}

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({
    super.key,
    required this.item,
    required this.source,
  });

  final DiscoverItem item;
  final DiscoverSource source;

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  bool _reading = false;
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final item = widget.item;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: DiscoverContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: l10n.discoverMaterialDetails,
                  leading: const BackButton(),
                ),
                if (item.imageUrl != null &&
                    widget.source.category != DiscoverCategory.documents)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.compact,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        height: AppLayout.discoverDetailImageHeight,
                        child: DiscoverImage(item: item, source: widget.source),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.compact),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppBadge(label: widget.source.name),
                          if (item.documentNumber != null)
                            AppBadge(label: 'RFC ${item.documentNumber}'),
                          if (item.status != null)
                            AppBadge(label: item.status!),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SelectableText(
                        item.title,
                        style: theme.textTheme.headlineMedium,
                      ),
                      if (item.author.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(
                          item.author,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      if (item.publishedAt != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          discoverDate(
                            context,
                            item.publishedAt!,
                            monthOnly: item.documentNumber != null,
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            onPressed: _reading ? null : _read,
                            icon: _reading
                                ? const DiscoverProgress()
                                : const Icon(Icons.auto_stories_outlined),
                            label: Text(
                              _reading
                                  ? l10n.discoverPreparing
                                  : l10n.discoverRead,
                            ),
                          ),
                          MaterialSaveButton(item: item, showLabel: true),
                          OutlinedButton.icon(
                            onPressed: _opening ? null : _openOriginal,
                            icon: _opening
                                ? const DiscoverProgress()
                                : const Icon(Icons.open_in_new_rounded),
                            label: Text(l10n.discoverOpenOriginal),
                          ),
                        ],
                      ),
                      if (item.summary.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SelectableText(
                          item.summary,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        widget.source.description(
                          Localizations.localeOf(context).languageCode,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _read() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _reading = true);
    try {
      final book = await ref
          .read(materialControllerProvider.notifier)
          .prepare(widget.item);
      if (mounted) context.push('/reader', extra: book);
    } catch (_) {
      if (mounted) showDiscoverError(context, l10n.discoverPrepareError);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _openOriginal() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _opening = true);
    try {
      if (!await launchUrl(
        widget.item.url,
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Could not open publication URL');
      }
    } catch (_) {
      if (mounted) showDiscoverError(context, l10n.discoverOpenOriginalError);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}
