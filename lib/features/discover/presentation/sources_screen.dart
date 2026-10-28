import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/discover_source.dart';
import '../domain/discover_sources_provider.dart';
import 'discover_source_screen.dart';
import 'discover_widgets.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _selectedOnly = false;
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _persist(Future<void> Function() operation) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await operation();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.discoverSourcesSaveError),
          action: SnackBarAction(
            label: l10n.searchRetry,
            onPressed: () => _persist(operation),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final catalog = ref.watch(discoverCatalogProvider);
    final selected = ref.watch(selectedDiscoverSourcesProvider);
    final enabled = ref.watch(enabledDiscoverSourcesProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final matching = catalog
        .where(
          (source) =>
              (!_selectedOnly || selected.contains(source.id)) &&
              (_query.isEmpty ||
                  source.name.toLowerCase().contains(_query) ||
                  source
                      .description(languageCode)
                      .toLowerCase()
                      .contains(_query)),
        )
        .toList();
    final rows = <Object>[];
    if (_selectedOnly) {
      matching.sort(
        (a, b) => selected.indexOf(a.id).compareTo(selected.indexOf(b.id)),
      );
      rows.addAll(matching);
    } else {
      for (final category in DiscoverCategory.values) {
        final group = matching
            .where((source) => source.category == category)
            .toList();
        if (group.isEmpty) continue;
        group.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        rows.add(category);
        rows.addAll(group);
      }
    }
    final notifier = ref.read(selectedDiscoverSourcesProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: DiscoverContent(
          child: CustomScrollView(
            key: const PageStorageKey('discover-source-manager'),
            slivers: [
              SliverToBoxAdapter(
                child: AppPageHeader(
                  title: l10n.discoverSources,
                  leading: const BackButton(),
                  subtitle: l10n.discoverSelectedCount(enabled.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
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
                        controller: _searchController,
                        hintText: l10n.discoverSourcesSearchHint,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            label: Text(l10n.discoverSelectedOnly),
                            selected: _selectedOnly,
                            onSelected: (value) =>
                                setState(() => _selectedOnly = value),
                          ),
                          TextButton(
                            onPressed: _saving || selected.isEmpty
                                ? null
                                : () {
                                    final ids = [...selected];
                                    _persist(() async {
                                      for (final id in ids) {
                                        await notifier.setEnabled(id, false);
                                      }
                                    });
                                  },
                            child: Text(l10n.discoverClearAll),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _saving
                              ? l10n.discoverSavingSources
                              : _failed
                              ? l10n.discoverSourcesSaveError
                              : l10n.discoverSourcesSaved,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _failed ? theme.colorScheme.error : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: _selectedOnly && selected.isEmpty
                        ? l10n.discoverNoSources
                        : l10n.discoverNoMatchingSources,
                    description: _selectedOnly && selected.isEmpty
                        ? l10n.discoverNoSourcesHint
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.compact,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final row = rows[index];
                      if (row is DiscoverCategory) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.compact,
                          ),
                          child: Text(
                            discoverCategoryLabel(l10n, row),
                            style: theme.textTheme.titleMedium,
                          ),
                        );
                      }
                      final source = row as DiscoverSource;
                      final position = enabled.indexWhere(
                        (s) => s.id == source.id,
                      );
                      final isEnabled = selected.contains(source.id);
                      return Padding(
                        key: ValueKey(source.id),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppSurface(
                          padding: EdgeInsets.zero,
                          radius: AppRadius.md,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          Navigator.of(context).push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DiscoverSourceScreen(
                                                    source: source,
                                                  ),
                                            ),
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.compact,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              source.name,
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              source.description(languageCode),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.sm,
                                    ),
                                    child: Semantics(
                                      label: source.name,
                                      child: Switch(
                                        value: isEnabled,
                                        onChanged: _saving
                                            ? null
                                            : (value) => _persist(
                                                () => notifier.setEnabled(
                                                  source.id,
                                                  value,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isEnabled)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.compact,
                                    0,
                                    AppSpacing.sm,
                                    AppSpacing.xs,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${discoverCategoryLabel(l10n, source.category)} · ${l10n.discoverSourcePosition(position + 1)}',
                                          style: theme.textTheme.labelMedium,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l10n.discoverMoveUp,
                                        onPressed: _saving || position <= 0
                                            ? null
                                            : () => _persist(
                                                () => notifier.move(
                                                  source.id,
                                                  selected.indexOf(
                                                        enabled[position - 1]
                                                            .id,
                                                      ) -
                                                      selected.indexOf(
                                                        source.id,
                                                      ),
                                                ),
                                              ),
                                        icon: const Icon(
                                          Icons.arrow_upward_rounded,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l10n.discoverMoveDown,
                                        onPressed:
                                            _saving ||
                                                position < 0 ||
                                                position >= enabled.length - 1
                                            ? null
                                            : () => _persist(
                                                () => notifier.move(
                                                  source.id,
                                                  selected.indexOf(
                                                        enabled[position + 1]
                                                            .id,
                                                      ) -
                                                      selected.indexOf(
                                                        source.id,
                                                      ),
                                                ),
                                              ),
                                        icon: const Icon(
                                          Icons.arrow_downward_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: rows.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ],
          ),
        ),
      ),
    );
  }
}
