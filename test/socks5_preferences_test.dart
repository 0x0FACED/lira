import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/providers/preferences_provider.dart';
import 'package:lira/core/providers/socks5_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _SecureStorage secure;
  late Socks5PreferencesStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pref_proxy_enabled': true,
      'pref_proxy_host': 'legacy.example',
      'pref_proxy_port': 9050,
    });
    prefs = await SharedPreferences.getInstance();
    secure = _SecureStorage();
    store = Socks5PreferencesStore(prefs, secureStorage: secure);
  });

  Future<ProviderContainer> openProvider() async {
    final container = ProviderContainer(
      overrides: [
        socks5PreferencesStoreProvider.overrideWith((ref) async => store),
        initialSocks5ConfigProvider.overrideWithValue(await store.load()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('legacy no-auth and no-auth saves never require a plugin', () async {
    secure.failReads = true;
    secure.failWrites = true;
    secure.failDeletes = true;
    final old = await store.load();
    expect(old.enabled, isTrue);
    expect(old.host, 'legacy.example');
    expect(old.port, 9050);
    expect(old.credentialsUnavailable, isFalse);

    await store.setEndpoint('plain.example', 1081);
    await prefs.reload();
    final restored = await Socks5PreferencesStore(
      prefs,
      secureStorage: secure,
    ).load();
    expect(restored.host, 'plain.example');
    expect(restored.port, 1081);
    expect(restored.enabled, isTrue);
    expect(restored.username, isNull);
    expect(restored.password, isNull);
    expect(restored.credentialsUnavailable, isFalse);
    expect(secure.calls, 0);
  });

  test('pair and endpoint survive restart and explicit clear', () async {
    final first = await openProvider();
    final notifier = first.read(socks5ConfigProvider.notifier);
    await notifier.setEnabled(false);
    await notifier.setEndpoint(
      'authenticated.example',
      1082,
      username: ' user ',
      password: ' secret ',
    );
    expect(first.read(socks5ConfigProvider).enabled, isFalse);
    for (final key in prefs.getKeys()) {
      expect(prefs.get(key).toString(), isNot(contains(' secret ')));
      expect(prefs.get(key).toString(), isNot(contains(' user ')));
    }

    await prefs.reload();
    store = Socks5PreferencesStore(prefs, secureStorage: secure);
    final restarted = await openProvider();
    final restored = restarted.read(socks5ConfigProvider);
    expect(restored.enabled, isFalse);
    expect(restored.host, 'authenticated.example');
    expect(restored.port, 1082);
    expect(restored.username, ' user ');
    expect(restored.password, ' secret ');
    expect(restored.credentialsUnavailable, isFalse);

    await restarted.read(socks5ConfigProvider.notifier).setEnabled(true);
    expect(restarted.read(socks5ConfigProvider).password, ' secret ');
    await restarted
        .read(socks5ConfigProvider.notifier)
        .setEndpoint('plain.example', 1083);
    expect(secure.value, isNull);
    await prefs.reload();
    store = Socks5PreferencesStore(prefs, secureStorage: secure);
    final cleared = (await openProvider()).read(socks5ConfigProvider);
    expect(cleared.enabled, isTrue);
    expect(cleared.host, 'plain.example');
    expect(cleared.port, 1083);
    expect(cleared.username, isNull);
    expect(cleared.password, isNull);
    expect(cleared.credentialsUnavailable, isFalse);
  });

  for (final missing in [false, true]) {
    test(
      'unreadable or missing secret is fail-closed: missing=$missing',
      () async {
        await store.setEndpoint(
          'authenticated.example',
          1080,
          username: 'user',
          password: 'password',
        );
        if (missing) {
          secure.value = null;
        } else {
          secure.failReads = true;
        }
        final restored = await store.load();
        expect(restored.enabled, isTrue);
        expect(restored.credentialsUnavailable, isTrue);
        expect(restored.username, isNull);
        expect(restored.password, isNull);
      },
    );
  }

  test(
    'first write fault cannot downgrade and a subsequent save recovers',
    () async {
      final container = await openProvider();
      final notifier = container.read(socks5ConfigProvider.notifier);
      secure.failWrites = true;
      await expectLater(
        notifier.setEndpoint(
          'new.example',
          1084,
          username: 'user',
          password: 'password',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'sanitized message',
            isNot(contains('sensitive platform details')),
          ),
        ),
      );
      final failed = container.read(socks5ConfigProvider);
      expect(failed.enabled, isTrue);
      expect(failed.credentialsUnavailable, isTrue);
      expect((await store.load()).credentialsUnavailable, isTrue);

      secure.failWrites = false;
      await notifier.setEndpoint(
        'recovered.example',
        1085,
        username: 'user2',
        password: 'password2',
      );
      final recovered = container.read(socks5ConfigProvider);
      expect(recovered.host, 'recovered.example');
      expect(recovered.port, 1085);
      expect(recovered.username, 'user2');
      expect(recovered.password, 'password2');
      expect(recovered.credentialsUnavailable, isFalse);
    },
  );

  test('auth update fault preserves the complete previous record', () async {
    await store.setEndpoint(
      'old.example',
      1080,
      username: 'old-user',
      password: 'old-password',
    );
    final container = await openProvider();
    secure.failWrites = true;
    await expectLater(
      container
          .read(socks5ConfigProvider.notifier)
          .setEndpoint(
            'new.example',
            1081,
            username: 'new-user',
            password: 'new-password',
          ),
      throwsStateError,
    );
    final config = container.read(socks5ConfigProvider);
    expect(config.host, 'old.example');
    expect(config.port, 1080);
    expect(config.username, 'old-user');
    expect(config.password, 'old-password');
    expect(config.credentialsUnavailable, isFalse);
  });

  test(
    'failed clear preserves authentication until deletion succeeds',
    () async {
      await store.setEndpoint(
        'old.example',
        1080,
        username: 'user',
        password: 'password',
      );
      final container = await openProvider();
      final notifier = container.read(socks5ConfigProvider.notifier);
      secure.failDeletes = true;
      await expectLater(
        notifier.setEndpoint('plain.example', 1081),
        throwsStateError,
      );
      expect(container.read(socks5ConfigProvider).host, 'old.example');
      expect(container.read(socks5ConfigProvider).password, 'password');
      secure.failDeletes = false;
      await notifier.setEndpoint('plain.example', 1081);
      expect(secure.value, isNull);
      expect(container.read(socks5ConfigProvider).password, isNull);
    },
  );

  test(
    'a clear failing after deletion stays fail-closed and can be retried',
    () async {
      await store.setEndpoint(
        'old.example',
        1080,
        username: 'user',
        password: 'password',
      );
      final container = await openProvider();
      final notifier = container.read(socks5ConfigProvider.notifier);
      secure.deleteThenFail = true;
      await expectLater(
        notifier.setEndpoint('plain.example', 1081),
        throwsStateError,
      );
      final failed = container.read(socks5ConfigProvider);
      expect(failed.enabled, isTrue);
      expect(failed.credentialsUnavailable, isTrue);
      expect(failed.password, isNull);
      expect((await store.load()).credentialsUnavailable, isTrue);
      secure.deleteThenFail = false;
      await notifier.setEndpoint('plain.example', 1081);
      expect(
        container.read(socks5ConfigProvider).credentialsUnavailable,
        isFalse,
      );
      expect(container.read(socks5ConfigProvider).host, 'plain.example');
    },
  );

  test('startup and queued save wait for persisted enabled state', () async {
    final gate = Completer<Socks5PreferencesStore>();
    final container = ProviderContainer(
      overrides: [
        socks5PreferencesStoreProvider.overrideWith((ref) => gate.future),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(socks5ConfigProvider).enabled, isTrue);
    expect(container.read(socks5ConfigProvider).credentialsUnavailable, isTrue);
    final save = container
        .read(socks5ConfigProvider.notifier)
        .setEndpoint('queued.example', 1086);
    gate.complete(store);
    await save;
    expect(container.read(socks5ConfigProvider).host, 'queued.example');
    expect(container.read(socks5ConfigProvider).enabled, isTrue);
    expect(
      container.read(socks5ConfigProvider).credentialsUnavailable,
      isFalse,
    );
  });

  test('credential validation measures UTF-8 without trimming', () {
    expect(Socks5Config.validCredentials(null, null), isTrue);
    expect(Socks5Config.validCredentials('', ''), isFalse);
    expect(Socks5Config.validCredentials('user', null), isFalse);
    expect(Socks5Config.validCredentials(null, 'password'), isFalse);
    expect(Socks5Config.validCredentials(' ', ' '), isTrue);
    expect(Socks5Config.validCredentials('a' * 255, 'b' * 255), isTrue);
    expect(Socks5Config.validCredentials('a' * 256, 'password'), isFalse);
    expect(Socks5Config.validCredentials('é' * 128, 'password'), isFalse);
    expect(Socks5Config.validCredentials('user', 'é' * 128), isFalse);
  });
}

class _SecureStorage implements Socks5SecureStorage {
  String? value;
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;
  bool deleteThenFail = false;
  int calls = 0;

  @override
  Future<String?> read(String key) async {
    calls++;
    if (failReads) throw StateError('sensitive platform details');
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    calls++;
    if (failWrites) throw StateError('sensitive platform details');
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    calls++;
    if (failDeletes) throw StateError('sensitive platform details');
    value = null;
    if (deleteThenFail) throw StateError('sensitive platform details');
  }
}
