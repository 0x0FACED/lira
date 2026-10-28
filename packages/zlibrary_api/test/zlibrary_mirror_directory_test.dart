import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

// The actual public /access-info format fetched from z-library.biz on 2026-10-28.
const _accessInfo = '''
Save this file in case you lose access to Z-Library.
It contains our latest domains, download links for Android and desktop apps, and other important links.

Main domains
    https://z-lib.sk
    https://z-library.im
    https://z-library.sk
    https://z-lib.fm

Stable user mirrors
    https://libb.la

Android APP
    https://s3proxy-alp.cdn-zlib.sk/swfs_second_public_files/soft/android/zlibrary-app-latest.apk

Desktop APP
    Windows: https://s3proxy-alp.cdn-zlib.sk/swfs_second_public_files/soft/desktop/Z-Library-latest.exe

Magic Email
Send any letter from your mailbox to our magic email address blackbox@z-library.so

Our Social Media
    https://x.com/Z_Lib_official
    https://telegram.me/zlib_chat
    https://mastodon.social/@Z_Lib_official

Other Useful Links
    https://wikipedia.org/wiki/Z-Library
    https://reddit.com/r/zlibrary
    https://lib-talk.io
''';

void main() {
  test(
      'parses only official main and stable-mirror sections, not app or social links',
      () async {
    final directory =
        ZLibraryMirrorDirectory(client: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), zLibraryMirrorDirectoryUrl);
      expect(request.headers['cookie'], isNull);
      expect(request.headers['authorization'], isNull);
      expect(request.followRedirects, isFalse);
      return http.Response(_accessInfo, 200,
          headers: {'content-type': 'text/plain; charset=utf-8'});
    }));
    addTearDown(directory.close);
    expect(await directory.fetch(), [
      'https://z-lib.sk',
      'https://z-library.im',
      'https://z-library.sk',
      'https://z-lib.fm',
      'https://libb.la',
    ]);
  });

  test('never retains or sends directory response tracking or account cookies',
      () async {
    var count = 0;
    final directory =
        ZLibraryMirrorDirectory(client: MockClient((request) async {
      count++;
      expect(request.headers['cookie'], isNull);
      return http.Response(_accessInfo, 200, headers: {
        'set-cookie':
            'tracking=private; Path=/, remix_userid=123; Path=/, remix_userkey=must-not-send; Path=/',
      });
    }));
    addTearDown(directory.close);
    await directory.fetch();
    await directory.fetch();
    expect(count, 2);
  });

  test(
      'reports unsupported browser challenges instead of inventing suggestions',
      () async {
    final directory = ZLibraryMirrorDirectory(
        client: MockClient((_) async =>
            http.Response('<title>Checking your browser ...</title>', 503)));
    addTearDown(directory.close);
    await expectLater(directory.fetch(), throwsA(isA<ZLibraryException>()));
  });

  test(
      'completes the observed anonymous browser handshake without forwarding account cookies',
      () async {
    const seed = 'BC0BB99F1906312BC1C6CB9FCDD8907AA75ECD88';
    var count = 0;
    final directory =
        ZLibraryMirrorDirectory(client: MockClient((request) async {
      count++;
      final header = request.headers['cookie'];
      expect(request.headers['authorization'], isNull);
      if (count == 1) {
        expect(header, isNull);
        return http.Response(
          "<title>Checking your browser ...</title><script>const a=['$seed','c_token=','array'];</script>",
          503,
          headers: {
            'set-cookie':
                'bsrv=node-2; Path=/, remix_userkey=must-not-send; Path=/'
          },
        );
      }
      expect(header, contains('bsrv=node-2'));
      expect(header, isNot(contains('remix_')));
      final token = RegExp(r'c_token=([^;]+)').firstMatch(header!)!.group(1)!;
      final duration = RegExp(r'c_time=([^;]+)').firstMatch(header)!.group(1)!;
      final digest = sha1.convert(utf8.encode(token)).bytes;
      final index = int.parse(seed[0], radix: 16);
      expect(digest.sublist(index, index + 2), [0xb0, 0x0b]);
      expect(double.parse(duration), greaterThanOrEqualTo(0));
      return http.Response(_accessInfo, 200);
    }));
    addTearDown(directory.close);
    expect(await directory.fetch(), contains('https://z-library.sk'));
    expect(await directory.fetch(), contains('https://libb.la'));
    expect(count, 3);
  });

  test('rejects HTTP200 HTML and changed directory formats', () async {
    final directory = ZLibraryMirrorDirectory(
        client: MockClient((_) async => http.Response(
            '<h1>Z-Library</h1><a href="https://unapproved.test">Free books</a>',
            200)));
    addTearDown(directory.close);
    await expectLater(directory.fetch(), throwsA(isA<ZLibraryException>()));
  });

  test(
      'allows an anonymous cookie-installing self-redirect, then bounds an unchanged loop',
      () async {
    var count = 0;
    final directory =
        ZLibraryMirrorDirectory(client: MockClient((request) async {
      count++;
      expect(request.headers['cookie'],
          count == 1 ? isNull : contains('__diamwall=value'));
      return http.Response('', 307, headers: {
        'location': request.url.toString(),
        'set-cookie': '__diamwall=value; Path=/'
      });
    }));
    addTearDown(directory.close);
    await expectLater(directory.fetch(), throwsA(isA<ZLibraryException>()));
    expect(count, 2);
  });

  test('never follows directory redirects to another origin', () async {
    var count = 0;
    final directory = ZLibraryMirrorDirectory(client: MockClient((_) async {
      count++;
      return http.Response('', 302,
          headers: {'location': 'https://third-party.test/mirrors'});
    }));
    addTearDown(directory.close);
    await expectLater(directory.fetch(), throwsA(isA<ZLibraryException>()));
    expect(count, 1);
  });

  test('rejects credential-bearing or path-bearing entries in mirror sections',
      () async {
    var page = _accessInfo.replaceFirst(
        'https://z-lib.sk', 'https://user:password@z-lib.sk');
    final directory = ZLibraryMirrorDirectory(
        client: MockClient((_) async => http.Response(page, 200)));
    addTearDown(directory.close);
    await expectLater(directory.fetch(), throwsA(isA<ZLibraryException>()));
    page = _accessInfo.replaceFirst(
        'https://z-lib.sk', 'https://z-lib.sk/untrusted/path');
    await expectLater(directory.fetch(), throwsA(isA<ZLibraryException>()));
  });

  group('normalization', () {
    test('accepts a host or canonical HTTPS origin', () {
      expect(normalizeZLibraryMirror('  Z-LIBRARY.BIZ/ '),
          'https://z-library.biz');
      expect(normalizeZLibraryMirror('https://z-library.biz:443/'),
          'https://z-library.biz');
      expect(normalizeZLibraryMirror('mirror.test:8443'),
          'https://mirror.test:8443');
    });

    for (final value in [
      '',
      'http://mirror.test',
      'ftp://mirror.test',
      'https://user:secret@mirror.test',
      'https://mirror.test/path',
      'https://mirror.test?token=secret',
      'https://mirror.test#fragment',
      'https://mirror.test:',
      'https://mirror..test',
      'https://-mirror.test',
      'mirror .test',
    ]) {
      test('rejects unsafe mirror input $value', () {
        expect(() => normalizeZLibraryMirror(value), throwsFormatException);
      });
    }
  });
}
