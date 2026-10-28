import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discover_repository.dart';
import 'discover_item.dart';
import 'discover_source.dart';
import 'discover_sources_provider.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  final repository = DiscoverRepository();
  ref.onDispose(repository.close);
  return repository;
});

DiscoverSource _source(Ref ref, String id) => ref
    .read(discoverCatalogProvider)
    .firstWhere(
      (source) => source.id == id,
      orElse: () =>
          throw ArgumentError.value(id, 'sourceId', 'Unknown Discover source'),
    );

final discoverFeedProvider = FutureProvider.family<DiscoverFeed, String>((
  ref,
  id,
) {
  return ref.watch(discoverRepositoryProvider).feed(_source(ref, id));
});

final discoverSearchProvider = FutureProvider.autoDispose
    .family<List<DiscoverItem>, DiscoverQuery>((ref, query) {
      return ref
          .watch(discoverRepositoryProvider)
          .search(_source(ref, query.sourceId), query.query);
    });
