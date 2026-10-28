part of 'zlibrary_api_client.dart';

/// Reads only the catalog's official public access-info download.
///
/// Uses its own anonymous transport, never the user's account client or stored
/// credentials. Only origin-scoped browser-verification/backend cookies may be
/// retained; account/session cookies and cross-origin redirects are rejected.
/// Unsupported browser challenges remain errors, never fabricated suggestions.
class ZLibraryMirrorDirectory {
  final ZLibraryApi _anonymous;

  ZLibraryMirrorDirectory({http.Client? client})
      : _anonymous = ZLibraryApi(
          mirrors: [Uri.parse(zLibraryMirrorDirectoryUrl).origin],
          client: client,
        );

  Future<List<String>> fetch() async {
    if (_anonymous._closed)
      throw StateError('ZLibraryMirrorDirectory is closed.');
    final result = await _anonymous._request(
      Uri.parse(zLibraryMirrorDirectoryUrl),
      anonymousOnly: true,
    );
    ZLibraryApi._requireSuccess(result.response);
    return _parseAccessInfo(result.response.body);
  }

  // Format observed in the real /access-info download: mirror sections precede
  // Android/desktop app downloads, magic email, social and other useful links.
  // Only the two named mirror sections may contribute suggestions.
  List<String> _parseAccessInfo(String body) {
    if (!body
            .contains('Save this file in case you lose access to Z-Library.') ||
        !body.contains('Main domains')) {
      throw const ZLibraryException(
          'The official mirror directory format was not recognized. Open it in your browser.');
    }
    var inMirrorSection = false;
    final mirrors = <String>{};
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final text = line.trim();
      if (text.isEmpty) continue;
      if (text == 'Main domains' || text == 'Stable user mirrors') {
        inMirrorSection = true;
      } else if (!line.startsWith(' ') && !line.startsWith('\t')) {
        inMirrorSection = false;
      } else if (inMirrorSection && text.startsWith('https://')) {
        try {
          mirrors.add(normalizeZLibraryMirror(text));
        } on FormatException {
          throw const ZLibraryException(
              'The official mirror directory contained an invalid mirror origin.');
        }
      }
    }
    if (mirrors.isEmpty) {
      throw const ZLibraryException(
          'The official mirror directory contained no HTTPS mirror origins.');
    }
    return List.unmodifiable(mirrors);
  }

  void close() => _anonymous.close();
}
