import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/app_update/data/github_update_client.dart';
import 'package:lira/features/app_update/domain/app_update.dart';

Matcher failsWith(UpdateFailure failure) => throwsA(
  isA<AppUpdateException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

void main() {
  group('stable versions', () {
    test('preserves optional builds and compares numeric public versions', () {
      bool newer(String candidate, String installed) => AppUpdateVersion.parse(
        candidate,
      ).isNewerThan(AppUpdateVersion.parse(installed));

      final public = AppUpdateVersion.parse('0.6.4');
      expect(public.version, '0.6.4');
      expect(public.buildNumber, isNull);
      expect(public.displayVersion, '0.6.4');
      expect(AppUpdateVersion.parse('0.6.4+8').displayVersion, '0.6.4+8');
      expect(newer('0.10.0', '0.9.0+99'), isTrue);
      expect(newer('0.6.5+1', '0.6.4+8'), isTrue);
      expect(newer('0.6.3+99', '0.6.4+8'), isFalse);
      expect(newer('0.6.4+9', '0.6.4+8'), isTrue);
      expect(newer('0.6.4+8', '0.6.4+8'), isFalse);
      expect(newer('0.6.4+7', '0.6.4+8'), isFalse);
      expect(newer('0.6.4', '0.6.4+8'), isFalse);
      expect(newer('0.6.4+9', '0.6.4'), isFalse);
      expect(newer('0.6.4', '0.6.4'), isFalse);
    });

    test('rejects noncanonical versions and invalid Android build codes', () {
      for (final value in [
        'v0.6.4',
        '0.6',
        '0.6.4-beta',
        '00.6.4',
        '0.06.4',
        '0.6.04',
        '0.6.4+08',
        '0.6.4+0',
        '0.6.4+-1',
        '0.6.4+2100000001',
        '0.6.4+99999999999999999999999999',
        '99999999999999999999999999.6.4',
        '0.6.4\n',
        ' 0.6.4',
      ]) {
        expect(
          () => AppUpdateVersion.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
    });
  });

  late _ReleaseServer server;
  late GitHubUpdateClient client;
  late Directory directory;

  setUp(() async {
    server = await _ReleaseServer.start();
    client = GitHubUpdateClient(apiBase: server.base);
    directory = await Directory.systemTemp.createTemp('lira-update-test-');
  });

  tearDown(() async {
    client.close();
    await server.close();
    await directory.delete(recursive: true);
  });

  test('resolves a stable tag, release page and GitHub asset digest', () async {
    final release = await client.latest();
    expect(release.version.displayVersion, '0.6.4');
    expect(release.releaseUrl, _ReleaseServer.releaseUri('v0.6.4'));
    expect(release.apk?.name, 'app-release.apk');
    expect(release.apk?.url, server.assetUri());
    expect(release.apk?.sizeBytes, server.payload.length);
    expect(release.apk?.sha256, sha256.convert(server.payload).toString());
    expect(server.requests, hasLength(1));
  });

  test('parses the published Lira v0.6.4 asset contract', () async {
    server.assets.single.addAll({
      'size': 101834736,
      'browser_download_url':
          'https://github.com/0x0FACED/lira/releases/download/v0.6.4/app-release.apk',
      'digest':
          'sha256:905950354fb13dcbeb954582b7439f7fa5ec06b98c07100dd4d0e4fc210b42fb',
    });
    final release = await client.latest();
    expect(release.version.version, '0.6.4');
    expect(release.apk?.sizeBytes, 101834736);
    expect(
      release.apk?.sha256,
      '905950354fb13dcbeb954582b7439f7fa5ec06b98c07100dd4d0e4fc210b42fb',
    );
  });

  test('accepts an optional tag prefix and canonical numeric build', () async {
    for (final tag in ['0.6.4', 'v0.6.4+8']) {
      server.metadata['tag_name'] = tag;
      server.metadata['html_url'] = _ReleaseServer.releaseUri(tag).toString();
      server.assets.single['browser_download_url'] = server
          .assetUri(tag: tag)
          .toString();
      final release = await client.latest();
      expect(release.version.displayVersion, tag.replaceFirst('v', ''));
      expect(release.apk, isNotNull);
    }
  });

  final malformedReleases = <String, void Function(_ReleaseServer)>{
    'draft': (server) => server.metadata['draft'] = true,
    'prerelease': (server) => server.metadata['prerelease'] = true,
    'unpublished': (server) => server.metadata['published_at'] = null,
    'missing tag': (server) => server.metadata.remove('tag_name'),
    'noncanonical tag': (server) => server.metadata['tag_name'] = 'v00.6.4',
    'prerelease tag': (server) => server.metadata['tag_name'] = 'v0.6.4-beta',
    'trailing tag newline': (server) =>
        server.metadata['tag_name'] = 'v0.6.4\n',
    'missing release URL': (server) => server.metadata.remove('html_url'),
    'foreign release host': (server) => server.metadata['html_url'] =
        'https://github.com.evil.example/0x0FACED/lira/releases/tag/v0.6.4',
    'foreign repository': (server) => server.metadata['html_url'] =
        'https://github.com/someone/lira/releases/tag/v0.6.4',
    'different release tag': (server) => server.metadata['html_url'] =
        _ReleaseServer.releaseUri('v0.6.3').toString(),
    'insecure release URL': (server) => server.metadata['html_url'] =
        _ReleaseServer.releaseUri('v0.6.4').replace(scheme: 'http').toString(),
    'release credentials': (server) =>
        server.metadata['html_url'] = _ReleaseServer.releaseUri(
          'v0.6.4',
        ).replace(userInfo: 'secret').toString(),
    'release query': (server) =>
        server.metadata['html_url'] = _ReleaseServer.releaseUri(
          'v0.6.4',
        ).replace(query: 'redirect=evil').toString(),
    'release fragment': (server) =>
        server.metadata['html_url'] = _ReleaseServer.releaseUri(
          'v0.6.4',
        ).replace(fragment: 'other').toString(),
    'release port': (server) => server.metadata['html_url'] =
        _ReleaseServer.releaseUri('v0.6.4').replace(port: 8443).toString(),
  };
  for (final entry in malformedReleases.entries) {
    test('rejects ${entry.key}', () async {
      entry.value(server);
      await expectLater(
        client.latest(),
        failsWith(UpdateFailure.invalidRelease),
      );
    });
  }

  final unavailableApks = <String, void Function(_ReleaseServer)>{
    'missing assets': (server) => server.metadata.remove('assets'),
    'malformed asset list': (server) =>
        server.metadata['assets'] = 'unavailable',
    'malformed asset entries': (server) =>
        server.metadata['assets'] = [null, 1],
    'no APK': (server) => server.assets.clear(),
    'wrong APK name': (server) => server.assets.single['name'] = 'other.apk',
    'duplicate APK': (server) => server.assets.add({...server.assets.single}),
    'incomplete upload': (server) => server.assets.single['state'] = 'new',
    'invalid asset size': (server) => server.assets.single['size'] = '1024',
    'empty APK': (server) => server.assets.single['size'] = 0,
    'oversized APK': (server) =>
        server.assets.single['size'] = 1024 * 1024 * 1024 + 1,
    'missing digest': (server) => server.assets.single.remove('digest'),
    'wrong digest algorithm': (server) =>
        server.assets.single['digest'] = 'sha512:${'a' * 64}',
    'malformed digest': (server) =>
        server.assets.single['digest'] = 'sha256:bad',
    'digest newline': (server) =>
        server.assets.single['digest'] = 'sha256:${'a' * 64}\n',
    'foreign APK host': (server) => server.assets.single['browser_download_url'] =
        'https://github.com.evil.example/0x0FACED/lira/releases/download/v0.6.4/app-release.apk',
    'foreign APK repository': (server) =>
        server.assets.single['browser_download_url'] = server.base
            .resolve('/someone/lira/releases/download/v0.6.4/app-release.apk')
            .toString(),
    'different APK tag': (server) =>
        server.assets.single['browser_download_url'] = server
            .assetUri(tag: 'v0.6.3')
            .toString(),
    'APK credentials': (server) =>
        server.assets.single['browser_download_url'] = server
            .assetUri()
            .replace(userInfo: 'secret')
            .toString(),
    'APK query': (server) => server.assets.single['browser_download_url'] =
        server.assetUri().replace(query: 'other=1').toString(),
    'APK fragment': (server) => server.assets.single['browser_download_url'] =
        server.assetUri().replace(fragment: 'other').toString(),
  };
  for (final entry in unavailableApks.entries) {
    test('still detects desktop release with ${entry.key}', () async {
      entry.value(server);
      final release = await client.latest();
      expect(release.version.version, '0.6.4');
      expect(release.releaseUrl, _ReleaseServer.releaseUri('v0.6.4'));
      expect(release.apk, isNull);
      expect(server.requests, hasLength(1));
      await expectLater(
        client.download(release, directory, onProgress: (_, _) {}),
        failsWith(UpdateFailure.invalidRelease),
      );
      expect(await directory.list().toList(), isEmpty);
    });
  }

  test('normalizes an uppercase GitHub sha256 digest', () async {
    server.assets.single['digest'] =
        'sha256:${sha256.convert(server.payload).toString().toUpperCase()}';
    expect(
      (await client.latest()).apk?.sha256,
      sha256.convert(server.payload).toString(),
    );
  });

  for (final chunked in [false, true]) {
    test('bounds ${chunked ? 'chunked' : 'sized'} release metadata', () async {
      server.apiBody = ' ' * (1024 * 1024 + 1);
      server.apiChunked = chunked;
      await expectLater(
        client.latest(),
        failsWith(UpdateFailure.invalidRelease),
      );
    });
  }

  final statuses = [
    (404, <String, String>{}, '', UpdateFailure.unavailable),
    (403, {'x-ratelimit-remaining': '0'}, '', UpdateFailure.rateLimited),
    (403, {'retry-after': '60'}, '', UpdateFailure.rateLimited),
    (
      403,
      <String, String>{},
      'Secondary rate limit',
      UpdateFailure.rateLimited,
    ),
    (429, <String, String>{}, '', UpdateFailure.rateLimited),
    (403, <String, String>{}, 'Forbidden', UpdateFailure.network),
    (500, <String, String>{}, '', UpdateFailure.network),
  ];
  for (final (status, headers, message, failure) in statuses) {
    test('maps HTTP $status ($message) to ${failure.name}', () async {
      server.apiStatus = status;
      server.apiHeaders.addAll(headers);
      server.apiBody = jsonEncode({'message': message});
      await expectLater(client.latest(), failsWith(failure));
    });
  }

  test('never follows a metadata redirect', () async {
    server.apiStatus = HttpStatus.found;
    server.apiHeaders[HttpHeaders.locationHeader] = '/another-api';
    await expectLater(client.latest(), failsWith(UpdateFailure.invalidRelease));
    expect(server.requests, hasLength(1));
  });

  test('streams, verifies and atomically publishes a versioned APK', () async {
    final release = await client.latest();
    final path = '${directory.path}/lira-0.6.4-android.apk';
    final progress = <int>[];
    final file = await client.download(
      release,
      directory,
      onProgress: (received, total) {
        expect(total, server.payload.length);
        expect(File(path).existsSync(), isFalse);
        expect(File('$path.part').existsSync(), isTrue);
        progress.add(received);
      },
    );
    expect(file.path, path);
    expect(await file.readAsBytes(), server.payload);
    expect(progress.first, 0);
    expect(progress.last, server.payload.length);
    for (var index = 1; index < progress.length; index++) {
      expect(progress[index], greaterThan(progress[index - 1]));
    }
    expect(await File('$path.part').exists(), isFalse);
    expect(await directory.list().toList(), hasLength(1));
  });

  test('rejects a bad hash without replacing a verified APK', () async {
    final release = await client.latest();
    final previous = File('${directory.path}/lira-0.6.4-android.apk');
    await previous.writeAsBytes([1, 2, 3]);
    server.downloadPayload = [...server.payload]..[0] = 255;
    await expectLater(
      client.download(release, directory, onProgress: (_, _) {}),
      failsWith(UpdateFailure.checksum),
    );
    expect(await previous.readAsBytes(), [1, 2, 3]);
    expect(await File('${previous.path}.part').exists(), isFalse);
  });

  test(
    'downloading a different version preserves the previously launched APK',
    () async {
      final previous = File('${directory.path}/lira-0.6.3-android.apk');
      await previous.writeAsBytes([1, 2, 3]);
      final file = await client.download(
        await client.latest(),
        directory,
        onProgress: (_, _) {},
      );
      expect(file.path, isNot(previous.path));
      expect(await previous.readAsBytes(), [1, 2, 3]);
      expect(await file.readAsBytes(), server.payload);
    },
  );

  for (final oversized in [false, true]) {
    test(
      'rejects a ${oversized ? 'oversized' : 'truncated'} chunked APK',
      () async {
        final release = await client.latest();
        server.downloadPayload = oversized
            ? [...server.payload, 1, 2, 3]
            : server.payload.sublist(0, 16 * 1024);
        server.omitContentLength = true;
        await expectLater(
          client.download(release, directory, onProgress: (_, _) {}),
          failsWith(UpdateFailure.checksum),
        );
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }

  test('rejects a mismatched content length and removes its partial', () async {
    final release = await client.latest();
    server.downloadPayload = server.payload.sublist(0, 16 * 1024);
    await expectLater(
      client.download(release, directory, onProgress: (_, _) {}),
      failsWith(UpdateFailure.checksum),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('maps an interrupted stream and removes its partial', () async {
    final release = await client.latest();
    server.disconnect = true;
    await expectLater(
      client.download(release, directory, onProgress: (_, _) {}),
      failsWith(UpdateFailure.download),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('maps a failed APK response and removes its partial', () async {
    final release = await client.latest();
    server.apkStatus = HttpStatus.internalServerError;
    await expectLater(
      client.download(release, directory, onProgress: (_, _) {}),
      failsWith(UpdateFailure.download),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  final unsafeRedirects = [
    'https://github.com.evil.example/asset.apk',
    'https://release-assets.githubusercontent.com.evil.example/asset.apk',
    '/someone/lira/releases/download/v0.6.4/app-release.apk',
    '/0x0FACED/lira/releases/download/v0.6.3/app-release.apk',
    'http://secret@127.0.0.1/asset.apk',
    '/0x0FACED/lira/releases/download/v0.6.4/app-release.apk#other',
  ];
  for (final redirect in unsafeRedirects) {
    test(
      'rejects unsafe asset redirect $redirect before following it',
      () async {
        final release = await client.latest();
        server.apkRedirect = redirect;
        await expectLater(
          client.download(release, directory, onProgress: (_, _) {}),
          failsWith(UpdateFailure.invalidRelease),
        );
        expect(server.requests, hasLength(2));
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }

  test('follows a confined asset redirect', () async {
    final release = await client.latest();
    server.apkRedirect = '${release.apk!.url}?download=1';
    final file = await client.download(
      release,
      directory,
      onProgress: (_, _) {},
    );
    expect(await file.readAsBytes(), server.payload);
  });

  test('bounds asset redirect loops and removes the partial', () async {
    final release = await client.latest();
    server.apkRedirect = '${release.apk!.url}?download=1';
    server.redirectForever = true;
    await expectLater(
      client.download(release, directory, onProgress: (_, _) {}),
      failsWith(UpdateFailure.invalidRelease),
    );
    expect(server.requests, hasLength(7));
    expect(await directory.list().toList(), isEmpty);
  });

  test('revalidates caller-supplied metadata before creating a file', () async {
    final release = await client.latest();
    final apk = release.apk!;
    final invalid = [
      AppUpdateRelease(
        version: release.version,
        releaseUrl: release.releaseUrl,
        apk: AppUpdateApk(
          name: '../${apk.name}',
          url: apk.url,
          sizeBytes: apk.sizeBytes,
          sha256: apk.sha256,
        ),
      ),
      AppUpdateRelease(
        version: AppUpdateVersion.parse('0.6.5'),
        releaseUrl: release.releaseUrl,
        apk: apk,
      ),
      AppUpdateRelease(
        version: release.version,
        releaseUrl: _ReleaseServer.releaseUri('v0.6.3'),
        apk: apk,
      ),
    ];
    for (final candidate in invalid) {
      await expectLater(
        client.download(candidate, directory, onProgress: (_, _) {}),
        failsWith(UpdateFailure.invalidRelease),
      );
    }
    expect(server.requests, hasLength(1));
    expect(await directory.list().toList(), isEmpty);
  });

  test('never sends credentials to metadata, assets or redirects', () async {
    client.close();
    final transport = _RecordingHttpClient(HttpClient());
    client = GitHubUpdateClient(httpClient: transport, apiBase: server.base);
    final release = await client.latest();
    server.apkRedirect = '${release.apk!.url}?download=1';
    await client.download(release, directory, onProgress: (_, _) {});
    expect(server.requests, hasLength(3));
    expect(server.credentialHeaders, everyElement(isEmpty));
  });

  test('only permits production GitHub or an explicit loopback API', () {
    for (final base in [
      'http://api.github.com',
      'https://api.github.com.evil.example',
      'https://api.github.com:8443',
      'https://secret@api.github.com',
      'https://api.github.com/another/path',
      'https://api.github.com/?secret=1',
      'http://192.168.1.1',
    ]) {
      expect(
        () => GitHubUpdateClient(apiBase: Uri.parse(base)),
        throwsArgumentError,
        reason: base,
      );
    }
  });
}

class _RecordingHttpClient implements HttpClient {
  _RecordingHttpClient(this._delegate);

  final HttpClient _delegate;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) {
    _delegate.badCertificateCallback = callback;
  }

  @override
  set authenticate(dynamic callback) {
    _delegate.authenticate = callback;
  }

  @override
  set authenticateProxy(dynamic callback) {
    _delegate.authenticateProxy = callback;
  }

  @override
  set connectionTimeout(Duration? timeout) =>
      _delegate.connectionTimeout = timeout;

  @override
  set autoUncompress(bool value) => _delegate.autoUncompress = value;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final request = await _delegate.getUrl(url);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer secret');
    request.headers.set(HttpHeaders.proxyAuthorizationHeader, 'Basic secret');
    request.headers.set(HttpHeaders.cookieHeader, 'session=secret');
    request.cookies.add(Cookie('another-session', 'secret'));
    return request;
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReleaseServer {
  _ReleaseServer(this._server) {
    assets = [
      {
        'name': 'app-release.apk',
        'state': 'uploaded',
        'size': payload.length,
        'browser_download_url': assetUri().toString(),
        'digest': 'sha256:${sha256.convert(payload)}',
      },
    ];
    metadata = {
      'tag_name': 'v0.6.4',
      'draft': false,
      'prerelease': false,
      'published_at': '2026-10-01T12:00:00Z',
      'html_url': releaseUri('v0.6.4').toString(),
      'assets': assets,
    };
    _server.listen(_serve);
  }

  final HttpServer _server;
  final payload = List<int>.generate(96 * 1024, (index) => index % 251);
  final apiHeaders = <String, String>{};
  final requests = <Uri>[];
  final credentialHeaders = <List<String>>[];
  late List<Map<String, Object?>> assets;
  late Map<String, Object?> metadata;
  int apiStatus = HttpStatus.ok;
  String? apiBody;
  bool apiChunked = false;
  int apkStatus = HttpStatus.ok;
  List<int>? downloadPayload;
  bool omitContentLength = false;
  bool disconnect = false;
  String? apkRedirect;
  bool redirectForever = false;

  Uri get base => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  Uri assetUri({String tag = 'v0.6.4'}) => base.replace(
    pathSegments: [
      '0x0FACED',
      'lira',
      'releases',
      'download',
      tag,
      'app-release.apk',
    ],
  );

  static Uri releaseUri(String tag) => Uri(
    scheme: 'https',
    host: 'github.com',
    pathSegments: ['0x0FACED', 'lira', 'releases', 'tag', tag],
  );

  static Future<_ReleaseServer> start() async =>
      _ReleaseServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> _serve(HttpRequest request) async {
    requests.add(request.uri);
    credentialHeaders.add([
      for (final name in [
        HttpHeaders.authorizationHeader,
        HttpHeaders.proxyAuthorizationHeader,
        HttpHeaders.cookieHeader,
      ])
        ...?request.headers[name],
    ]);
    try {
      await _respond(request);
    } on IOException {
      // Rejected oversized or interrupted downloads deliberately close sockets.
    }
  }

  Future<void> _respond(HttpRequest request) async {
    final response = request.response;
    if (request.uri.path == '/repos/0x0FACED/lira/releases/latest') {
      response.statusCode = apiStatus;
      apiHeaders.forEach(response.headers.set);
      response.headers.contentType = ContentType.json;
      final bytes = utf8.encode(apiBody ?? jsonEncode(metadata));
      if (!apiChunked) response.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
      return;
    }
    if (request.uri.path != assetUri().path) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (apkRedirect != null && (!request.uri.hasQuery || redirectForever)) {
      response.statusCode = HttpStatus.found;
      response.headers.set(HttpHeaders.locationHeader, apkRedirect!);
      await response.close();
      return;
    }
    response.statusCode = apkStatus;
    if (apkStatus != HttpStatus.ok) {
      await response.close();
      return;
    }
    final bytes = downloadPayload ?? payload;
    if (disconnect) {
      final socket = await response.detachSocket(writeHeaders: false);
      socket.add(
        utf8.encode(
          'HTTP/1.1 200 OK\r\nContent-Length: ${bytes.length}\r\n'
          'Connection: close\r\n\r\n',
        ),
      );
      socket.add(bytes.sublist(0, 8192));
      await socket.flush();
      socket.destroy();
      return;
    }
    if (!omitContentLength) response.contentLength = bytes.length;
    response.bufferOutput = false;
    for (var offset = 0; offset < bytes.length; offset += 8192) {
      final end = offset + 8192 < bytes.length ? offset + 8192 : bytes.length;
      response.add(bytes.sublist(offset, end));
      await response.flush();
      if (end < bytes.length) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
    await response.close();
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}
