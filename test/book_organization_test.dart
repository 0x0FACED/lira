import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/books/domain/providers/book_organization_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'labels normalize into immutable snapshots and survive reopening',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = BookOrganizationsNotifier(prefs);
      final container = ProviderContainer(
        overrides: [bookOrganizationsProvider.overrideWith((ref) => notifier)],
      );
      addTearDown(container.dispose);
      final genres = [
        '  Science\n fiction ',
        'science FICTION',
        '',
        ' Фэнтези ',
      ];
      final tags = [
        ' Read\t soon ',
        '#read soon',
        '###Любимое ',
        'любимое',
        '#   ',
        '###',
      ];

      await notifier.setLabels(
        'book/one:эпос',
        BookOrganization(genres: genres, tags: tags),
      );
      genres.clear();
      tags.clear();

      final labels = container.read(bookOrganizationProvider('book/one:эпос'));
      expect(labels.genres, ['Science fiction', 'Фэнтези']);
      expect(labels.tags, ['#Read soon', '#Любимое']);
      expect(() => labels.genres.add('Other'), throwsUnsupportedError);
      expect(() => labels.tags.clear(), throwsUnsupportedError);
      expect(() => notifier.state.clear(), throwsUnsupportedError);

      await prefs.reload();
      final reopened = BookOrganizationsNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state['book/one:эпос']!.genres, labels.genres);
      expect(reopened.state['book/one:эпос']!.tags, labels.tags);
    },
  );

  test(
    'overlapping saves and removals cannot resurrect deleted labels',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = BookOrganizationsNotifier(prefs);
      addTearDown(notifier.dispose);

      final writes = [
        notifier.setLabels('first', const BookOrganization(tags: ['Old'])),
        notifier.setLabels(
          'second',
          const BookOrganization(genres: ['Fantasy']),
        ),
        notifier.removeLabels('first'),
        notifier.setLabels(
          'second',
          const BookOrganization(genres: ['Fantasy'], tags: ['New']),
        ),
      ];
      await Future.wait(writes);
      await prefs.reload();
      final reopened = BookOrganizationsNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state.keys, ['second']);
      expect(reopened.state['second']!.genres, ['Fantasy']);
      expect(reopened.state['second']!.tags, ['#New']);

      await reopened.setLabels(
        'second',
        const BookOrganization(genres: ['   '], tags: ['\n', '##  ']),
      );
      await prefs.reload();
      expect(reopened.state, isEmpty);
      expect(prefs.containsKey(BookOrganizationsNotifier.storageKey), isFalse);
      final afterRemoval = BookOrganizationsNotifier(prefs);
      addTearDown(afterRemoval.dispose);
      expect(afterRemoval.state, isEmpty);
    },
  );

  test(
    'malformed entries cannot discard valid labels from other books',
    () async {
      SharedPreferences.setMockInitialValues({
        BookOrganizationsNotifier.storageKey: jsonEncode({
          'broken': 'not an organization',
          'partly-valid': {
            'genres': [' Fantasy ', 42, 'FANTASY', null],
            'tags': false,
          },
          'valid': {
            'genres': ['History'],
            'tags': [' Research ', 'research', 'Primary source'],
          },
          'empty': {
            'genres': [],
            'tags': ['  '],
          },
        }),
      });
      final notifier = BookOrganizationsNotifier(
        await SharedPreferences.getInstance(),
      );
      addTearDown(notifier.dispose);

      expect(notifier.state.keys, ['partly-valid', 'valid']);
      expect(notifier.state['partly-valid']!.genres, ['Fantasy']);
      expect(notifier.state['partly-valid']!.tags, isEmpty);
      expect(notifier.state['valid']!.tags, ['#Research', '#Primary source']);
    },
  );

  test('invalid stored payloads start empty and can be replaced', () async {
    for (final payload in <Object>[false, '{', '[]', 'null']) {
      SharedPreferences.setMockInitialValues({
        BookOrganizationsNotifier.storageKey: payload,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = BookOrganizationsNotifier(prefs);
      addTearDown(notifier.dispose);
      expect(notifier.state, isEmpty);
      await notifier.setLabels('book', const BookOrganization(tags: ['Saved']));
      await prefs.reload();
      final reopened = BookOrganizationsNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state['book']!.tags, ['#Saved']);
    }
  });
}
