import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/data/settings_provider.dart' show sharedPrefs;

/// Local-only labels; the notifier normalizes and freezes supplied lists.
class BookOrganization {
  const BookOrganization({this.genres = const [], this.tags = const []});

  final List<String> genres;
  final List<String> tags;
}

const _emptyOrganization = BookOrganization();

final bookOrganizationsProvider =
    StateNotifierProvider<
      BookOrganizationsNotifier,
      Map<String, BookOrganization>
    >((ref) => BookOrganizationsNotifier(sharedPrefs));

final bookOrganizationProvider = Provider.family<BookOrganization, String>(
  (ref, bookId) => ref.watch(
    bookOrganizationsProvider.select(
      (organizations) => organizations[bookId] ?? _emptyOrganization,
    ),
  ),
);

final _labelWhitespace = RegExp(r'\s+');
final _leadingHashes = RegExp(r'^#+');

/// Retains the first spelling of each nonempty label in display order.
List<String> normalizeBookLabels(Iterable<Object?> labels) =>
    _normalizeLabels(labels, tagPrefix: false);

/// Normalizes tags so every nonempty tag starts with a single `#`.
List<String> normalizeBookTags(Iterable<Object?> labels) =>
    _normalizeLabels(labels, tagPrefix: true);

List<String> _normalizeLabels(
  Iterable<Object?> labels, {
  required bool tagPrefix,
}) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final label in labels) {
    if (label is! String) continue;
    var display = label.trim().replaceAll(_labelWhitespace, ' ');
    if (tagPrefix) {
      display = display.replaceFirst(_leadingHashes, '').trimLeft();
      if (display.isEmpty) continue;
      display = '#$display';
    }
    if (display.isNotEmpty && seen.add(display.toLowerCase())) {
      normalized.add(display);
    }
  }
  return normalized.isEmpty ? const [] : List<String>.unmodifiable(normalized);
}

class BookOrganizationsNotifier
    extends StateNotifier<Map<String, BookOrganization>> {
  BookOrganizationsNotifier(this._prefs) : super(_load(_prefs));

  static const storageKey = 'book_organizations_v1';

  final SharedPreferences _prefs;
  Future<void> _writes = Future<void>.value();

  static BookOrganization _labels(
    Iterable<Object?> genres,
    Iterable<Object?> tags,
  ) {
    final normalizedGenres = normalizeBookLabels(genres);
    final normalizedTags = normalizeBookTags(tags);
    if (normalizedGenres.isEmpty && normalizedTags.isEmpty) {
      return _emptyOrganization;
    }
    return BookOrganization(genres: normalizedGenres, tags: normalizedTags);
  }

  static Map<String, BookOrganization> _load(SharedPreferences prefs) {
    final stored = prefs.get(storageKey);
    if (stored is! String) return const {};
    Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map<String, dynamic>) return const {};

    final organizations = <String, BookOrganization>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final genres = value['genres'];
      final tags = value['tags'];
      final labels = _labels(
        genres is List ? genres : const [],
        tags is List ? tags : const [],
      );
      if (!identical(labels, _emptyOrganization)) {
        organizations[entry.key] = labels;
      }
    }
    return Map<String, BookOrganization>.unmodifiable(organizations);
  }

  Future<void> setLabels(String bookId, BookOrganization labels) {
    final normalized = _labels(labels.genres, labels.tags);
    if (identical(normalized, _emptyOrganization)) {
      return removeLabels(bookId);
    }
    state = Map<String, BookOrganization>.unmodifiable({
      ...state,
      bookId: normalized,
    });
    return _persist();
  }

  Future<void> removeLabels(String bookId) {
    state = Map<String, BookOrganization>.unmodifiable({
      for (final entry in state.entries)
        if (entry.key != bookId) entry.key: entry.value,
    });
    return _persist();
  }

  Future<void> _persist() {
    // Capture this update before awaiting earlier writes, so overlapping edits
    // and removals persist in invocation order without losing another book.
    final payload = state.isEmpty
        ? null
        : jsonEncode({
            for (final entry in state.entries)
              entry.key: {
                'genres': entry.value.genres,
                'tags': entry.value.tags,
              },
          });
    final write = _writes.then<void>((_) async {
      final saved = payload == null
          ? await _prefs.remove(storageKey)
          : await _prefs.setString(storageKey, payload);
      if (!saved) throw StateError('Could not save book organization');
    });
    // Return failures to the caller without poisoning later queued updates.
    _writes = write.catchError((Object error, StackTrace stack) {});
    return write;
  }
}
