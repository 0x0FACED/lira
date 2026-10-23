import 'dart:convert';

/// Normalize a raw ZIP name or canonical archive path without URI decoding.
///
/// Literal percent sequences are filename characters, not URI escapes.
String normalizeEpubArchivePath(String path) {
  final source = path.replaceAll('\\', '/');
  final segments = <String>[];
  for (final segment in source.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

/// Resolve a local reference against a document's canonical archive path.
///
/// Query strings and fragments are not part of resource keys. Schemed and
/// protocol-relative references are deliberately never fetched or matched.
String? resolveEpubPath(String documentPath, String href) {
  final source = href.trim().replaceAll('\\', '/');
  if (source.startsWith('//') ||
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(source)) {
    return null;
  }
  final end = source.indexOf(RegExp(r'[?#]'));
  final path = end < 0 ? source : source.substring(0, end);
  if (path.isEmpty) return normalizeEpubArchivePath(documentPath);
  final decodedPath = _decodePercentLenient(path);
  if (decodedPath.startsWith('/')) return normalizeEpubArchivePath(decodedPath);
  final base = documentPath.replaceAll('\\', '/');
  final slash = base.lastIndexOf('/');
  return normalizeEpubArchivePath(
    slash < 0 ? decodedPath : '${base.substring(0, slash)}/$decodedPath',
  );
}

String _decodePercentLenient(String input) {
  final output = StringBuffer();
  final bytes = <int>[];

  void flushBytes() {
    if (bytes.isEmpty) return;
    output.write(utf8.decode(bytes, allowMalformed: true));
    bytes.clear();
  }

  int? hexValue(int unit) {
    if (unit >= 48 && unit <= 57) return unit - 48;
    if (unit >= 65 && unit <= 70) return unit - 55;
    if (unit >= 97 && unit <= 102) return unit - 87;
    return null;
  }

  for (var index = 0; index < input.length; index++) {
    if (input.codeUnitAt(index) == 37 && index + 2 < input.length) {
      final high = hexValue(input.codeUnitAt(index + 1));
      final low = hexValue(input.codeUnitAt(index + 2));
      if (high != null && low != null) {
        bytes.add((high << 4) + low);
        index += 2;
        continue;
      }
    }
    flushBytes();
    output.write(input[index]);
  }
  flushBytes();
  return output.toString();
}
