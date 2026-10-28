import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../search/presentation/zlibrary_mirrors_screen.dart';
import '../../search/presentation/anna_access_screen.dart';
import '../domain/discover_content_providers.dart';
import '../domain/discover_source.dart';
import 'discover_search_screen.dart';
import 'discover_widgets.dart';
import 'material_detail_screen.dart';

class DiscoverSourceScreen extends ConsumerStatefulWidget {
  const DiscoverSourceScreen({super.key, required this.source});
  final DiscoverSource source;

  @override
  ConsumerState<DiscoverSourceScreen> createState() =>
      _DiscoverSourceScreenState();
}

class _DiscoverSourceScreenState extends ConsumerState<DiscoverSourceScreen> {
  final _searchController = TextEditingController();
  bool _refreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => DiscoverSearchScreen(
        source: widget.source,
        initialQuery: _searchController.text.trim(),
      ),
    ),
  );

  Future<void> _refresh() async {
    if (_refreshing) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _refreshing = true);
    try {
      await ref
          .read(discoverRepositoryProvider)
          .feed(widget.source, refresh: true);
      if (!mounted) return;
      ref.invalidate(discoverFeedProvider(widget.source.id));
      await ref.read(discoverFeedProvider(widget.source.id).future);
    } catch (_) {
      if (mounted) showDiscoverError(context, l10n.discoverFeedError);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final source = widget.source;
    final feed = source.hasFeed
        ? ref.watch(discoverFeedProvider(source.id))
        : null;
    final scrollView = CustomScrollView(
      key: PageStorageKey('discover-source-${source.id}'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: AppPageHeader(
            title: source.name,
            subtitle: source.description(
              Localizations.localeOf(context).languageCode,
            ),
            leading: const BackButton(),
            actions: [
              if (source.kind == DiscoverSourceKind.anna)
                IconButton(
                  tooltip: l10n.annaSessionTitle,
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const AnnaAccessScreen()),
                  ),
                  icon: const Icon(Icons.key_outlined),
                ),
              if (source.kind == DiscoverSourceKind.zlibrary)
                IconButton(
                  tooltip: l10n.zLibraryMirrors,
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const ZLibraryMirrorsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.dns_outlined),
                ),
              if (source.hasFeed)
                IconButton(
                  tooltip: l10n.discoverRefresh,
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const DiscoverProgress()
                      : const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.compact,
              0,
              AppSpacing.compact,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchField(
                  controller: _searchController,
                  hintText: l10n.discoverSourceSearchHint,
                  onSubmitted: (_) => _search(),
                  onSearch: _search,
                ),
                if (source.hasFeed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    source.searchesRecentOnly
                        ? l10n.discoverRecentOnly
                        : l10n.discoverWholeCatalog,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!source.hasFeed)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: discoverCategoryIcon(source.category),
              title: l10n.discoverSearchOnly,
              description: l10n.discoverSearchSourceHint,
              action: OutlinedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search_rounded),
                label: Text(l10n.search),
              ),
            ),
          )
        else
          feed!.when(
            data: (value) => SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.compact,
                      0,
                      AppSpacing.compact,
                      AppSpacing.compact,
                    ),
                    child: Text(
                      value.isStale
                          ? '${l10n.discoverCachedFeed}\n${l10n.discoverUpdated(discoverDate(context, value.updatedAt))}'
                          : l10n.discoverUpdated(
                              discoverDate(context, value.updatedAt),
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                if (value.items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.article_outlined,
                    title: l10n.discoverNoMaterials,
                  );
                }
                final item = value.items[index - 1];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.compact,
                    0,
                    AppSpacing.compact,
                    AppSpacing.sm,
                  ),
                  child: DiscoverItemTile(
                    key: ValueKey(item.id),
                    item: item,
                    source: source,
                    onTap: () => openMaterialDetail(context, item, source),
                  ),
                );
              }, childCount: value.items.isEmpty ? 2 : value.items.length + 1),
            ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: DiscoverProgress()),
            ),
            error: (_, __) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: DiscoverFailure(
                  message: l10n.discoverFeedError,
                  onRetry: _refresh,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: DiscoverContent(
          child: source.hasFeed
              ? RefreshIndicator(onRefresh: _refresh, child: scrollView)
              : scrollView,
        ),
      ),
    );
  }
}
