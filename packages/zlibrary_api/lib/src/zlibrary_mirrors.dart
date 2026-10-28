/// Canonical entry points advertised by Z-Library's official access pages.
///
/// The official access page (https://go-to-library.sk/) links to z-library.biz;
/// that catalog's /access-info download lists the remaining main domains.
/// Availability varies by network; a browser verification page is not a result.
const List<String> defaultZLibraryMirrors = [
  'https://z-library.biz',
  'https://z-lib.sk',
  'https://z-library.im',
  'https://z-library.sk',
  'https://z-lib.fm',
];

/// Official plain-text access information linked from the catalog footer.
const String zLibraryMirrorDirectoryUrl = 'https://z-library.biz/access-info';

/// Accepts a host or HTTPS origin, never a URL containing credentials or a path.
String normalizeZLibraryMirror(String value) {
  final input = value.trim();
  if (input.isEmpty || RegExp(r'\s').hasMatch(input)) {
    throw const FormatException('Enter a host or an HTTPS origin.');
  }
  final uri = Uri.tryParse(input.contains('://') ? input : 'https://$input');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      input.endsWith(':') ||
      input.endsWith(':/') ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
        'Mirrors must be HTTPS origins without credentials or paths.');
  }
  final host = uri.host.toLowerCase();
  final isDomain =
      RegExp(r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$').hasMatch(host) &&
          !host.contains('..') &&
          host
              .split('.')
              .every((label) => !label.startsWith('-') && !label.endsWith('-'));
  final isIpv6 = host.contains(':') && RegExp(r'^[a-f0-9:]+$').hasMatch(host);
  if (!isDomain && !isIpv6) {
    throw const FormatException('Invalid mirror host.');
  }
  final port = uri.port;
  if (port < 1 || port > 65535) {
    throw const FormatException('Invalid mirror port.');
  }
  return Uri(scheme: 'https', host: host, port: port == 443 ? null : port)
      .origin;
}

class ZLibraryException implements Exception {
  final String message;

  const ZLibraryException(this.message);

  @override
  String toString() => 'Z-Library: $message';
}

class ZLibraryAuthenticationException extends ZLibraryException {
  const ZLibraryAuthenticationException(super.message);
}
