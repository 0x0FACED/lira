import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/data/settings_provider.dart' show sharedPrefs;

final openLibraryAutoProvider = NotifierProvider<OpenLibraryAutoNotifier, bool>(
  OpenLibraryAutoNotifier.new,
);

class OpenLibraryAutoNotifier extends Notifier<bool> {
  static const _key = 'open_library_auto';

  @override
  bool build() => sharedPrefs.getBool(_key) ?? false;

  Future<void> setEnabled(bool enabled) async {
    if (!await sharedPrefs.setBool(_key, enabled)) {
      throw StateError('Could not save the Open Library preference');
    }
    state = enabled;
  }
}
