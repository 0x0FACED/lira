import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/discover_content_providers.dart';
import '../domain/discover_item.dart';
import '../domain/discover_source.dart';
import '../domain/discover_sources_provider.dart';
import 'discover_carousel.dart';
import 'discover_search_screen.dart';
import 'discover_source_screen.dart';
import 'discover_widgets.dart';
import 'material_detail_screen.dart';
import 'sources_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  bool _activated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack lays out hidden tabs too. Do not even create feed consumers
    // until the tab has actually been selected.
    if (TickerMode.valuesOf(context).enabled) _activated = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            DiscoverSearchScreen(initialQuery: _searchController.text.trim()),
      ),
    );
  }

  void _openSources() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const SourcesScreen()));

  @override
  Widget build(BuildContext context) {
    if (!_activated) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final sources = ref.watch(enabledDiscoverSourcesProvider);
    final feeds = sources.where((source) => source.hasFeed).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey('discover-overview'),
          cacheExtent: 0,
          slivers: [
            SliverToBoxAdapter(
              child: DiscoverContent(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final theme = Theme.of(context);
                    final colors = theme.colorScheme;
                    final labelStyle = theme.textTheme.labelLarge;
                    final painter = TextPainter(
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    );
                    double measure(String text, TextStyle? style) {
                      painter.text = TextSpan(text: text, style: style);
                      painter.layout();
                      return painter.width.ceilToDouble();
                    }

                    final titleWidth = measure(
                      l10n.discover,
                      theme.textTheme.headlineMedium,
                    );
                    final actionWidth = math.max(
                      AppLayout.minTouchTarget,
                      measure(l10n.discoverSources, labelStyle) +
                          2 * AppSpacing.compact,
                    );
                    painter.dispose();
                    final availableWidth =
                        constraints.maxWidth -
                        2 * AppLayout.pageGutter(context);
                    return AppPageHeader(
                      title: l10n.discover,
                      keepActionsInline:
                          availableWidth >=
                          titleWidth + AppSpacing.sm + actionWidth,
                      actions: [
                        TextButton(
                          onPressed: _openSources,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            textStyle: labelStyle,
                            minimumSize: const Size.square(
                              AppLayout.minTouchTarget,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.compact,
                            ),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                          child: Text(l10n.discoverSources),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DiscoverContent(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageGutter(context),
                    0,
                    AppLayout.pageGutter(context),
                    AppSpacing.md,
                  ),
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: l10n.discoverSearchHint,
                    onSubmitted: (_) => _search(),
                    onSearch: _search,
                  ),
                ),
              ),
            ),
            if (feeds.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: sources.isEmpty
                      ? Icons.tune_rounded
                      : Icons.search_rounded,
                  title: sources.isEmpty
                      ? l10n.discoverNoSources
                      : l10n.discoverSearchOnly,
                  description: sources.isEmpty
                      ? l10n.discoverNoSourcesHint
                      : l10n.discoverSearchOnlyHint,
                  action: sources.isEmpty
                      ? OutlinedButton(
                          onPressed: _openSources,
                          child: Text(l10n.discoverSources),
                        )
                      : OutlinedButton.icon(
                          onPressed: _search,
                          icon: const Icon(Icons.search_rounded),
                          label: Text(l10n.search),
                        ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SourceShelf(
                    key: ValueKey(feeds[index].id),
                    source: feeds[index],
                  ),
                  childCount: feeds.length,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final index = feeds.indexWhere((s) => s.id == key.value);
                    return index < 0 ? null : index;
                  },
                ),
              ),
            if (feeds.isNotEmpty)
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          ],
        ),
      ),
    );
  }
}

class _SourceShelf extends ConsumerStatefulWidget {
  const _SourceShelf({super.key, required this.source});
  final DiscoverSource source;

  @override
  ConsumerState<_SourceShelf> createState() => _SourceShelfState();
}

class _SourceShelfState extends ConsumerState<_SourceShelf>
    with AutomaticKeepAliveClientMixin {
  AsyncValue<DiscoverFeed>? _lastFeed;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final source = widget.source;
    if (TickerMode.valuesOf(context).enabled) {
      _lastFeed = ref.watch(discoverFeedProvider(source.id));
    }
    final feed = _lastFeed ?? const AsyncLoading<DiscoverFeed>();
    return DiscoverContent(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShelfHeading(
              name: source.name,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => DiscoverSourceScreen(source: source),
                ),
              ),
            ),
            feed.when(
              data: (value) {
                if (value.items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppLayout.pageGutter(context),
                      vertical: AppSpacing.compact,
                    ),
                    child: Text(
                      l10n.discoverNoMaterials,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final text = Theme.of(context).textTheme.bodyMedium!;
                        final scaler = MediaQuery.textScalerOf(context);
                        final scale =
                            scaler.scale(text.fontSize!) / text.fontSize!;
                        final cardWidth = math.min(
                          constraints.maxWidth -
                              AppLayout.pageGutter(context) * 2,
                          AppLayout.discoverCardWidth *
                              scale.clamp(
                                1,
                                AppLayout.discoverMaxCardTextScale,
                              ),
                        );
                        final height = DiscoverItemCard.shelfHeight(
                          context,
                          source,
                          value.items.take(AppLayout.discoverShelfItemLimit),
                          cardWidth,
                        );
                        return DiscoverCarousel(
                          source: source,
                          items: value.items,
                          cardWidth: cardWidth,
                          height: height,
                          onOpen: (item) =>
                              openMaterialDetail(context, item, source),
                        );
                      },
                    ),
                    if (value.isStale)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppLayout.pageGutter(context),
                          AppSpacing.sm,
                          AppLayout.pageGutter(context),
                          0,
                        ),
                        child: Text(
                          '${l10n.discoverCachedFeed}\n${l10n.discoverUpdated(discoverDate(context, value.updatedAt))}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: DiscoverProgress()),
              ),
              error: (_, __) => DiscoverFailure(
                message: l10n.discoverFeedError,
                onRetry: () => ref.invalidate(discoverFeedProvider(source.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfHeading extends StatelessWidget {
  const _ShelfHeading({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.pageGutter(context)),
      child: Column(
        children: [
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(name, style: theme.textTheme.titleLarge),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45,
                  ),
                  child: TextButton(
                    onPressed: onTap,
                    child: Text(
                      l10n.discoverViewAll,
                      semanticsLabel: l10n.discoverViewAllFrom(name),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
