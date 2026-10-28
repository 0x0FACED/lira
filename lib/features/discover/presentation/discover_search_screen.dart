import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../search/presentation/book_search_results.dart';
import '../domain/discover_content_providers.dart';
import '../domain/discover_source.dart';
import '../domain/discover_sources_provider.dart';
import 'discover_source_screen.dart';
import 'discover_widgets.dart';
import 'material_detail_screen.dart';
import 'sources_screen.dart';

class DiscoverSearchScreen extends ConsumerStatefulWidget {
  const DiscoverSearchScreen({super.key, this.source, this.initialQuery});
  final DiscoverSource? source;
  final String? initialQuery;

  @override
  ConsumerState<DiscoverSearchScreen> createState() =>
      _DiscoverSearchScreenState();
}

class _DiscoverSearchScreenState extends ConsumerState<DiscoverSearchScreen> {
  late final TextEditingController _controller;
  late String _query;
  DiscoverCategory? _category;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (_query != query) setState(() => _query = query);
  }

  void _changed(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _submit();
    } else {
      _debounce = Timer(AppMotion.searchDebounce, _submit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sources = widget.source == null
        ? ref.watch(enabledDiscoverSourcesProvider)
        : [widget.source!];
    final categories = DiscoverCategory.values
        .where((category) => sources.any((s) => s.category == category))
        .toList();
    final category = categories.contains(_category)
        ? _category
        : categories.firstOrNull;
    final targets = sources.where((s) => s.category == category).toList();
    return Scaffold(
      body: SafeArea(
        child: DiscoverContent(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Controls can scroll independently when large type or the
                  // keyboard leaves too little room for the entire header.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          constraints.maxHeight *
                          AppLayout.discoverSearchControlsFraction,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppPageHeader(
                            title: widget.source?.name ?? l10n.search,
                            leading: const BackButton(),
                            subtitle: widget.source?.description(
                              Localizations.localeOf(context).languageCode,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.compact,
                              0,
                              AppSpacing.compact,
                              AppSpacing.compact,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppSearchField(
                                  controller: _controller,
                                  hintText: widget.source == null
                                      ? l10n.discoverSearchHint
                                      : l10n.discoverSourceSearchHint,
                                  autofocus: _query.isEmpty,
                                  onChanged: _changed,
                                  onSubmitted: (_) => _submit(),
                                  onSearch: _submit,
                                ),
                                if (categories.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.xs,
                                    children: [
                                      for (final value in categories)
                                        ChoiceChip(
                                          label: Text(
                                            discoverCategoryLabel(l10n, value),
                                          ),
                                          selected: category == value,
                                          onSelected: (_) =>
                                              setState(() => _category = value),
                                        ),
                                    ],
                                  ),
                                ],
                                if (widget.source?.searchesRecentOnly == true ||
                                    widget.source?.kind ==
                                        DiscoverSourceKind.rfc) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    widget.source!.searchesRecentOnly
                                        ? l10n.discoverRecentOnly
                                        : l10n.discoverWholeCatalog,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: sources.isEmpty
                        ? SingleChildScrollView(
                            child: AppEmptyState(
                              icon: Icons.tune_rounded,
                              title: l10n.discoverNoSources,
                              description: l10n.discoverNoSourcesHint,
                              action: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => const SourcesScreen(),
                                      ),
                                    ),
                                child: Text(l10n.discoverSources),
                              ),
                            ),
                          )
                        : _query.isEmpty
                        ? SingleChildScrollView(
                            child: AppEmptyState(
                              icon: Icons.search_rounded,
                              title: l10n.discoverSearchPrompt,
                              description: widget.source == null
                                  ? l10n.discoverSearchPromptHint
                                  : widget.source!.description(
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    ),
                            ),
                          )
                        : category == DiscoverCategory.books
                        ? BookSearchResults(
                            key: PageStorageKey(
                              'discover-books-${widget.source?.id ?? 'global'}',
                            ),
                            query: _query,
                            sourceId: widget.source?.id,
                          )
                        : CustomScrollView(
                            key: PageStorageKey(
                              'discover-results-${category?.name}-${widget.source?.id ?? 'global'}-$_query',
                            ),
                            slivers: [
                              for (final source in targets)
                                _SourceSearchSlivers(
                                  key: ValueKey('${source.id}:$_query'),
                                  source: source,
                                  query: _query,
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: AppSpacing.md),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SourceSearchSlivers extends ConsumerWidget {
  const _SourceSearchSlivers({
    super.key,
    required this.source,
    required this.query,
  });
  final DiscoverSource source;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final request = (sourceId: source.id, query: query);
    final results = ref.watch(discoverSearchProvider(request));
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: DiscoverSectionHeading(
            source: source,
            subtitle: source.searchesRecentOnly
                ? l10n.discoverRecentOnly
                : l10n.discoverWholeCatalog,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DiscoverSourceScreen(source: source),
              ),
            ),
          ),
        ),
        results.when(
          data: (items) {
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.compact),
                  child: Text(
                    l10n.discoverNoMaterials,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: DiscoverItemTile(
                      key: ValueKey(item.id),
                      item: item,
                      source: source,
                      onTap: () => openMaterialDetail(context, item, source),
                    ),
                  );
                }, childCount: items.length),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: DiscoverProgress()),
            ),
          ),
          error: (_, __) => SliverToBoxAdapter(
            child: DiscoverFailure(
              message: l10n.discoverSearchError,
              onRetry: () => ref.invalidate(discoverSearchProvider(request)),
            ),
          ),
        ),
      ],
    );
  }
}
