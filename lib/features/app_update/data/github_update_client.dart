import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:lira/features/app_update/domain/app_update.dart';

/// Public release transport. No credentials are sent, including on redirects.
class GitHubUpdateClient {
  GitHubUpdateClient({HttpClient? httpClient, Uri? apiBase})
    : _httpClient = httpClient ?? HttpClient(),
      _apiBase = apiBase ?? Uri.https('api.github.com', '/') {
    if (!_validApiBase(_apiBase)) {
      _httpClient.close(force: true);
      throw ArgumentError.value(
        apiBase,
        'apiBase',
        'Expected GitHub or loopback.',
      );
    }
    // Preserve the app's SOCKS connection factory, but never its permissive TLS.
    _httpClient.badCertificateCallback = null;
    _httpClient.authenticate = null;
    _httpClient.authenticateProxy = null;
    _httpClient.connectionTimeout = _connectionTimeout;
    _httpClient.autoUncompress = false;
  }

  static const _repository = ['0x0FACED', 'lira'];
  static const _apkName = 'app-release.apk';
  static const _connectionTimeout = Duration(seconds: 15);
  static const _readTimeout = Duration(seconds: 30);
  static const _metadataLimit = 1024 * 1024;
  static const _apkLimit = 1024 * 1024 * 1024;
  static const _redirectHosts = {
    'release-assets.githubusercontent.com',
    'objects.githubusercontent.com',
    'github-releases.githubusercontent.com',
  };
  static final _digestPattern = RegExp(r'^[a-fA-F0-9]{64}$');

  final HttpClient _httpClient;
  final Uri _apiBase;

  bool get _isLocal => _apiBase.scheme == 'http';

  Future<AppUpdateRelease> latest() async {
    try {
      final uri = _apiBase.replace(
        pathSegments: ['repos', ..._repository, 'releases', 'latest'],
      );
      final response = await _get(uri, failure: UpdateFailure.network);
      final bytes = await _readBytes(response, _metadataLimit);
      final Object? body = jsonDecode(utf8.decode(bytes));
      if (body is! Map<String, dynamic> ||
          body['draft'] != false ||
          body['prerelease'] != false ||
          body['published_at'] is! String ||
          DateTime.tryParse(body['published_at'] as String) == null ||
          body['tag_name'] is! String ||
          body['html_url'] is! String) {
        throw const AppUpdateException(UpdateFailure.invalidRelease);
      }
      final tag = body['tag_name'] as String;
      final version = _parseTag(tag);
      final releaseUrl = Uri.parse(body['html_url'] as String);
      if (!_isReleaseUrl(releaseUrl, tag)) {
        throw const AppUpdateException(UpdateFailure.invalidRelease);
      }
      return AppUpdateRelease(
        version: version,
        releaseUrl: releaseUrl,
        apk: _optionalApk(body['assets'], tag),
      );
    } on FormatException {
      throw const AppUpdateException(UpdateFailure.invalidRelease);
    } on TimeoutException {
      throw const AppUpdateException(UpdateFailure.network);
    } on IOException {
      throw const AppUpdateException(UpdateFailure.network);
    }
  }

  AppUpdateApk? _optionalApk(Object? assets, String tag) {
    if (assets is! List) return null;
    Map<String, dynamic>? candidate;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic> || asset['name'] != _apkName) {
        continue;
      }
      if (candidate != null) return null;
      candidate = asset;
    }
    if (candidate == null) return null;
    final size = candidate['size'];
    final url = candidate['browser_download_url'];
    final digest = candidate['digest'];
    if (candidate['state'] != 'uploaded' ||
        size is! int ||
        size <= 0 ||
        size > _apkLimit ||
        url is! String ||
        digest is! String ||
        !digest.startsWith('sha256:')) {
      return null;
    }
    final checksum = digest.substring('sha256:'.length);
    if (!_validDigest(checksum)) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !_isReleaseAssetUrl(uri, tag)) return null;
    return AppUpdateApk(
      name: _apkName,
      url: uri,
      sizeBytes: size,
      sha256: checksum.toLowerCase(),
    );
  }

  Future<File> download(
    AppUpdateRelease release,
    Directory directory, {
    required void Function(int received, int total) onProgress,
  }) async {
    final apk = release.apk;
    final segments = release.releaseUrl.pathSegments;
    final tag = segments.isEmpty ? '' : segments.last;
    if (apk == null) {
      throw const AppUpdateException(UpdateFailure.invalidRelease);
    }
    try {
      if (!_isReleaseUrl(release.releaseUrl, tag) ||
          _parseTag(tag).displayVersion != release.version.displayVersion ||
          apk.name != _apkName ||
          apk.sizeBytes <= 0 ||
          apk.sizeBytes > _apkLimit ||
          !_validDigest(apk.sha256) ||
          !_isReleaseAssetUrl(apk.url, tag)) {
        throw const AppUpdateException(UpdateFailure.invalidRelease);
      }
    } on FormatException {
      throw const AppUpdateException(UpdateFailure.invalidRelease);
    }
    // The Android adapter supplies an app-private directory.
    final filename = 'lira-${release.version.displayVersion}-android.apk';
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    final partial = File('${file.path}.part');
    RandomAccessFile? output;
    var complete = false;
    try {
      try {
        await directory.create(recursive: true);
        output = await partial.open(mode: FileMode.write);
        onProgress(0, apk.sizeBytes);
        final response = await _get(
          apk.url,
          failure: UpdateFailure.download,
          asset: true,
        );
        if (response.contentLength != -1 &&
            response.contentLength != apk.sizeBytes) {
          await _cancel(response);
          throw const AppUpdateException(UpdateFailure.checksum);
        }
        final digest = _DigestSink();
        final hasher = sha256.startChunkedConversion(digest);
        var received = 0;
        await for (final chunk in response.timeout(_readTimeout)) {
          received += chunk.length;
          if (received > apk.sizeBytes) {
            throw const AppUpdateException(UpdateFailure.checksum);
          }
          await output.writeFrom(chunk);
          hasher.add(chunk);
          onProgress(received, apk.sizeBytes);
        }
        hasher.close();
        await output.close();
        output = null;
        if (received != apk.sizeBytes ||
            digest.value.toString() != apk.sha256.toLowerCase()) {
          throw const AppUpdateException(UpdateFailure.checksum);
        }
        final result = await partial.rename(file.path);
        complete = true;
        return result;
      } finally {
        try {
          await output?.close();
        } finally {
          if (!complete && await partial.exists()) await partial.delete();
        }
      }
    } on TimeoutException {
      throw const AppUpdateException(UpdateFailure.download);
    } on IOException {
      throw const AppUpdateException(UpdateFailure.download);
    }
  }

  static AppUpdateVersion _parseTag(String tag) =>
      AppUpdateVersion.parse(tag.startsWith('v') ? tag.substring(1) : tag);

  static bool _validDigest(String value) =>
      value.length == 64 && _digestPattern.hasMatch(value);

  static bool _isReleaseUrl(Uri uri, String tag) =>
      _safeOrigin(uri) &&
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      !uri.hasQuery &&
      _exactPath(uri, [..._repository, 'releases', 'tag', tag]);

  bool _isReleaseAssetUrl(Uri uri, String tag) {
    if (!_safeOrigin(uri) || uri.hasQuery) return false;
    final correctOrigin =
        (uri.scheme == 'https' && uri.host == 'github.com') ||
        (_isLocal && uri.origin == _apiBase.origin);
    return correctOrigin &&
        _exactPath(uri, [
          ..._repository,
          'releases',
          'download',
          tag,
          _apkName,
        ]);
  }

  static bool _exactPath(Uri uri, List<String> expected) {
    final segments = uri.pathSegments;
    if (segments.length != expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (segments[index] != expected[index]) return false;
    }
    return true;
  }

  bool _allowedRedirect(Uri uri, Uri original) {
    if (!_safeOrigin(uri)) return false;
    if (original.scheme == 'http') {
      return _isLocal &&
          uri.origin == _apiBase.origin &&
          uri.path == original.path;
    }
    return uri.scheme == 'https' &&
        (_redirectHosts.contains(uri.host) ||
            (uri.host == 'github.com' && uri.path == original.path));
  }

  static bool _safeOrigin(Uri uri) =>
      uri.isAbsolute &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      ((uri.scheme == 'https' && uri.port == 443) ||
          (uri.scheme == 'http' && _loopback(uri.host)));

  static bool _loopback(String host) =>
      host == '127.0.0.1' || host == '::1' || host == 'localhost';

  static bool _validApiBase(Uri uri) =>
      _safeOrigin(uri) &&
      !uri.hasQuery &&
      (uri.path.isEmpty || uri.path == '/') &&
      ((uri.scheme == 'https' && uri.host == 'api.github.com') ||
          (uri.scheme == 'http' && _loopback(uri.host)));

  Future<HttpClientResponse> _get(
    Uri original, {
    required UpdateFailure failure,
    bool asset = false,
  }) async {
    var uri = original;
    for (var redirects = 0; redirects <= 5; redirects++) {
      final request = await _httpClient.getUrl(uri).timeout(_connectionTimeout);
      request.followRedirects = false;
      request.cookies.clear();
      request.headers.removeAll(HttpHeaders.authorizationHeader);
      request.headers.removeAll(HttpHeaders.proxyAuthorizationHeader);
      request.headers.removeAll(HttpHeaders.cookieHeader);
      request.headers.set(HttpHeaders.userAgentHeader, 'Lira updater');
      request.headers.set(
        HttpHeaders.acceptHeader,
        asset ? 'application/octet-stream' : 'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response = await request.close().timeout(
        _connectionTimeout,
        onTimeout: () {
          final error = TimeoutException('Update response timed out.');
          request.abort(error);
          throw error;
        },
      );
      if (response.statusCode == HttpStatus.ok) return response;
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await _cancel(response);
        if (!asset || location == null || redirects == 5) {
          throw const AppUpdateException(UpdateFailure.invalidRelease);
        }
        final Uri next;
        try {
          next = uri.resolve(location);
        } on FormatException {
          throw const AppUpdateException(UpdateFailure.invalidRelease);
        }
        if (!_allowedRedirect(next, original)) {
          throw const AppUpdateException(UpdateFailure.invalidRelease);
        }
        uri = next;
        continue;
      }
      if (response.statusCode == HttpStatus.notFound) {
        await _cancel(response);
        throw const AppUpdateException(UpdateFailure.unavailable);
      }
      if (response.statusCode == HttpStatus.tooManyRequests ||
          (response.statusCode == HttpStatus.forbidden &&
              (response.headers.value('x-ratelimit-remaining') == '0' ||
                  response.headers.value(HttpHeaders.retryAfterHeader) !=
                      null))) {
        await _cancel(response);
        throw const AppUpdateException(UpdateFailure.rateLimited);
      }
      if (response.statusCode == HttpStatus.forbidden) {
        try {
          final bytes = await _readBytes(response, 16 * 1024);
          final message = utf8.decode(bytes).toLowerCase();
          if (message.contains('rate limit')) {
            throw const AppUpdateException(UpdateFailure.rateLimited);
          }
        } on AppUpdateException catch (error) {
          if (error.failure == UpdateFailure.rateLimited) rethrow;
        } on FormatException {
          // A non-GitHub error page is not evidence of rate limiting.
        }
      } else {
        await _cancel(response);
      }
      throw AppUpdateException(failure);
    }
    throw const AppUpdateException(UpdateFailure.invalidRelease);
  }

  static Future<Uint8List> _readBytes(
    HttpClientResponse response,
    int limit,
  ) async {
    if (response.contentLength > limit) {
      await _cancel(response);
      throw const AppUpdateException(UpdateFailure.invalidRelease);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(_readTimeout)) {
      if (bytes.length + chunk.length > limit) {
        throw const AppUpdateException(UpdateFailure.invalidRelease);
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Future<void> _cancel(HttpClientResponse response) =>
      response.listen(null).cancel();

  void close() => _httpClient.close(force: true);
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
