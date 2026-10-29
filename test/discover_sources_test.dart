import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/discover/domain/discover_source.dart';
import 'package:lira/features/discover/domain/discover_sources_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('migration retains the previously selected book sources', () async {
    SharedPreferences.setMockInitialValues({'pref_search_source': 'zlibrary'});
    final prefs = await SharedPreferences.getInstance();
    final notifier = DiscoverSourcesNotifier(prefs);
    addTearDown(notifier.dispose);
    expect(notifier.state, contains(DiscoverSourceIds.zlibrary));
    expect(notifier.state, isNot(contains(DiscoverSourceIds.anna)));
    await notifier.setEnabled(DiscoverSourceIds.cloudflare, false);
    final reopened = DiscoverSourcesNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, contains(DiscoverSourceIds.zlibrary));
    expect(reopened.state, isNot(contains(DiscoverSourceIds.anna)));
    expect(reopened.state, isNot(contains(DiscoverSourceIds.cloudflare)));
  });

  test('an intentionally empty selection survives reopening', () async {
    SharedPreferences.setMockInitialValues({
      DiscoverSourcesNotifier.storageKey: <String>[],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [discoverPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(enabledDiscoverSourcesProvider), isEmpty);
    await container
        .read(selectedDiscoverSourcesProvider.notifier)
        .setEnabled(DiscoverSourceIds.github, true);
    await container
        .read(selectedDiscoverSourcesProvider.notifier)
        .setEnabled(DiscoverSourceIds.github, false);
    final reopened = DiscoverSourcesNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, isEmpty);
  });

  test(
    'rapid changes preserve final order and unknown sources across catalog expansion',
    () async {
      SharedPreferences.setMockInitialValues({
        DiscoverSourcesNotifier.storageKey: [
          'future-blog',
          DiscoverSourceIds.cloudflare,
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = DiscoverSourcesNotifier(prefs);
      addTearDown(notifier.dispose);
      await Future.wait([
        notifier.setEnabled(DiscoverSourceIds.github, true),
        notifier.setEnabled(DiscoverSourceIds.cloudflare, false),
        notifier.move(DiscoverSourceIds.github, -1),
      ]);
      final reopened = DiscoverSourcesNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state, [DiscoverSourceIds.github, 'future-blog']);
      final expanded = ProviderContainer(
        overrides: [
          discoverPreferencesProvider.overrideWithValue(prefs),
          discoverCatalogProvider.overrideWithValue([
            ...discoverSourceCatalog,
            const DiscoverSource(
              id: 'future-blog',
              name: 'Future Blog',
              kind: DiscoverSourceKind.rss,
              category: DiscoverCategory.blogs,
              descriptionEn: 'A new source',
              topics: {DiscoverTopic.science},
              language: DiscoverSourceLanguage.english,
              descriptionRu: 'Новый источник',
              homeUrl: 'https://example.org/',
              feedUrl: 'https://example.org/feed.xml',
            ),
          ]),
        ],
      );
      addTearDown(expanded.dispose);
      expect(
        expanded
            .read(enabledDiscoverSourcesProvider)
            .map((source) => source.id),
        [DiscoverSourceIds.github, 'future-blog'],
      );
    },
  );

  test('catalog additions preserve a saved selection until enabled', () async {
    final saved = [
      DiscoverSourceIds.github,
      'unknown-source',
      DiscoverSourceIds.anna,
    ];
    SharedPreferences.setMockInitialValues({
      DiscoverSourcesNotifier.storageKey: saved,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [discoverPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(selectedDiscoverSourcesProvider), saved);
    expect(
      container.read(enabledDiscoverSourcesProvider).map((source) => source.id),
      [DiscoverSourceIds.github, DiscoverSourceIds.anna],
    );

    final additions = [
      DiscoverSourceIds.batrachospermum,
      DiscoverSourceIds.elementy,
      DiscoverSourceIds.ourWorldInData,
      DiscoverSourceIds.jstorDaily,
      DiscoverSourceIds.aeon,
      DiscoverSourceIds.mongabay,
    ];
    final notifier = container.read(selectedDiscoverSourcesProvider.notifier);
    for (final id in additions) {
      expect(
        discoverSourceCatalog.where((source) => source.id == id),
        isNotEmpty,
      );
      await notifier.setEnabled(id, true);
    }
    final reopened = DiscoverSourcesNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, [...saved, ...additions]);
  });
}
