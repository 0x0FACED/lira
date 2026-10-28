import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/search/domain/providers/anna_access_provider.dart';
import 'package:lira/features/search/domain/providers/zlibrary_mirrors_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'approved mirror edits preserve priority and survive reopening without readding removed defaults',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ZLibraryMirrorsNotifier(prefs);
      addTearDown(notifier.dispose);
      await notifier.setMirrors([
        'z-library.biz',
        'https://Z-LIB.SK/',
        'https://z-library.biz',
      ]);
      final reopened = ZLibraryMirrorsNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state, ['https://z-library.biz', 'https://z-lib.sk']);
      await reopened.setMirrors(['https://z-lib.sk']);
      final afterRemoval = ZLibraryMirrorsNotifier(prefs);
      addTearDown(afterRemoval.dispose);
      expect(afterRemoval.state, ['https://z-lib.sk']);
    },
  );

  test('unsafe mirror edits cannot replace the approved list', () async {
    SharedPreferences.setMockInitialValues({
      ZLibraryMirrorsNotifier.storageKey: ['https://z-library.biz'],
    });
    final notifier = ZLibraryMirrorsNotifier(
      await SharedPreferences.getInstance(),
    );
    addTearDown(notifier.dispose);
    for (final value in [
      'http://z-library.biz',
      'https://user:password@z-library.biz',
      'https://z-library.biz/search',
      'https://z-library.biz?token=secret',
    ]) {
      expect(() => notifier.setMirrors([value]), throwsFormatException);
      expect(notifier.state, ['https://z-library.biz']);
    }
    expect(() => notifier.setMirrors([]), throwsFormatException);
  });

  test(
    'Anna browser session stays pinned to its approved origin and can be removed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = AnnaAccessNotifier(prefs);
      addTearDown(notifier.dispose);
      await notifier.setSession(
        AnnaAccessSession(
          origin: 'https://annas-archive.gd',
          cookieHeader: 'Cookie: verification=opaque==; preference=one',
          userAgent: 'Test browser',
        ),
      );
      final reopened = AnnaAccessNotifier(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.state?.origin, 'https://annas-archive.gd');
      expect(reopened.state?.cookies, {
        'verification': 'opaque==',
        'preference': 'one',
      });
      expect(
        () => AnnaAccessSession(
          origin: 'https://unapproved.example',
          cookieHeader: 'session=secret',
          userAgent: 'Test browser',
        ),
        throwsFormatException,
      );
      expect(
        () => AnnaAccessSession(
          origin: 'https://annas-archive.gd',
          cookieHeader: 'session=x\r\nInjected: value',
          userAgent: 'Test browser',
        ),
        throwsFormatException,
      );
      await reopened.setSession(null);
      final cleared = AnnaAccessNotifier(prefs);
      addTearDown(cleared.dispose);
      expect(cleared.state, isNull);
    },
  );
}
