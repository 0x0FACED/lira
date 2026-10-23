import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Parsed EPUB content ready for rendering
class ParsedEpub {
  final String title;
  final String author;
  final Uint8List? coverImage;
  final List<EpubChapter> chapters;
  final List<TOCItem> toc;
  final Map<String, Uint8List> images;

  ParsedEpub({
    required this.title,
    required this.author,
    this.coverImage,
    required this.chapters,
    required this.toc,
    required this.images,
  });
}

/// Chapter with HTML content
class EpubChapter {
  final String title;
  final String htmlContent;
  final String fileName;

  EpubChapter({
    required this.title,
    required this.htmlContent,
    required this.fileName,
  });
}

/// Item in the Table of Contents
class TOCItem {
  final String title;
  final String fileName;
  final List<TOCItem> subItems;

  TOCItem({
    required this.title,
    required this.fileName,
    this.subItems = const [],
  });
}

const _htmlMediaTypes = {
  'application/xhtml+xml',
  'text/html',
  'application/xml',
  'text/xml',
};

/// Parses EPUB bytes into structured content
class EpubParser {
  /// Parse EPUB from raw bytes.
  ///
  /// The package spine defines reading order; the TOC is only navigation and
  /// may omit documents, reorder them, or point to several anchors in one file.
  static Future<ParsedEpub> parse(Uint8List data) async {
    return _parseWithArchive(data);
  }

  static ParsedEpub _parseWithArchive(Uint8List data) {
    final archive = ZipDecoder().decodeBytes(data, verify: false);
    final fileByPath = <String, ArchiveFile>{};
    final aliasToActualPath = <String, String>{};

    for (final file in archive.files.where((file) => file.isFile)) {
      final normalized = _normalizePath(file.name);
      fileByPath[normalized] = file;
      for (final alias in _pathAliases(normalized)) {
        aliasToActualPath.putIfAbsent(alias, () => normalized);
      }
    }

    final containerPath = _findArchivePath(
      'META-INF/container.xml',
      aliasToActualPath,
    );
    if (containerPath == null) {
      throw Exception('EPUB container.xml not found');
    }

    final containerDocument = XmlDocument.parse(
      _decodeTextFile(fileByPath[containerPath]!),
    );
    final rootFileNode = _firstDescendantByLocalName(
      containerDocument,
      'rootfile',
    );
    final opfRelativePath = _attributeValue(rootFileNode, 'full-path');
    if (opfRelativePath == null || opfRelativePath.isEmpty) {
      throw Exception('EPUB rootfile full-path is missing');
    }

    final opfPath = _findArchivePath(opfRelativePath, aliasToActualPath);
    if (opfPath == null) {
      throw Exception('OPF package file not found: $opfRelativePath');
    }

    final opfDocument = XmlDocument.parse(
      _decodeTextFile(fileByPath[opfPath]!),
    );
    final opfDir = _dirname(opfPath);
    final metadataNode = _firstDescendantByLocalName(opfDocument, 'metadata');
    final manifestNode = _firstDescendantByLocalName(opfDocument, 'manifest');
    final spineNode = _firstDescendantByLocalName(opfDocument, 'spine');

    if (manifestNode == null) {
      throw Exception('EPUB manifest is missing');
    }

    final title =
        _firstDescendantText(metadataNode, 'title') ?? 'Unknown Title';
    final author =
        _firstDescendantText(metadataNode, 'creator') ?? 'Unknown Author';

    final manifestItems = <_ManifestItem>[];
    final manifestById = <String, _ManifestItem>{};
    for (final itemNode in manifestNode.children.whereType<XmlElement>()) {
      if (itemNode.name.local.toLowerCase() != 'item') continue;
      final id = _attributeValue(itemNode, 'id');
      final href = _attributeValue(itemNode, 'href');
      final mediaType = _attributeValue(itemNode, 'media-type');
      if (id == null || href == null || mediaType == null) continue;

      final resolvedPath = _resolveRelativePath(opfDir, href);
      final manifestItem = _ManifestItem(
        id: id,
        href: href,
        resolvedPath: resolvedPath,
        mediaType: mediaType,
        properties: _attributeValue(itemNode, 'properties') ?? '',
      );
      manifestItems.add(manifestItem);
      manifestById[id] = manifestItem;
    }

    final images = <String, Uint8List>{};
    for (final item in manifestItems) {
      if (!item.mediaType.toLowerCase().startsWith('image/')) continue;
      final actualPath = _findArchivePath(item.resolvedPath, aliasToActualPath);
      if (actualPath == null) continue;
      _registerBinaryAliases(
        images,
        item.resolvedPath,
        _fileBytes(fileByPath[actualPath]!),
      );
    }

    Uint8List? coverImage;
    final coverItem = _resolveCoverItem(
      metadataNode,
      manifestItems,
      manifestById,
    );
    if (coverItem != null) {
      final coverPath = _findArchivePath(
        coverItem.resolvedPath,
        aliasToActualPath,
      );
      if (coverPath != null) {
        coverImage = _fileBytes(fileByPath[coverPath]!);
      }
    }

    final toc = _parseToc(
      manifestItems: manifestItems,
      fileByPath: fileByPath,
      aliasToActualPath: aliasToActualPath,
    );

    final tocTitlesByPath = <String, String>{};
    _flattenTocTitles(toc, tocTitlesByPath);

    final flatChapters = <EpubChapter>[];
    final seenPaths = <String>{};

    void addChapter(_ManifestItem item, {bool requiredBySpine = false}) {
      if (!_isHtmlManifestItem(item)) return;
      final actualPath = _findArchivePath(item.resolvedPath, aliasToActualPath);
      if (actualPath == null) {
        if (requiredBySpine) {
          throw FormatException(
            'EPUB spine document not found: ${item.resolvedPath}',
          );
        }
        return;
      }
      if (seenPaths.contains(actualPath)) return;

      final htmlContent = _decodeTextFile(fileByPath[actualPath]!);
      if (htmlContent.trim().isEmpty) {
        if (requiredBySpine) {
          throw FormatException(
            'EPUB spine document is empty: ${item.resolvedPath}',
          );
        }
        return;
      }

      flatChapters.add(
        EpubChapter(
          title:
              tocTitlesByPath[item.resolvedPath] ??
              _extractDocumentTitle(htmlContent) ??
              item.id,
          htmlContent: htmlContent,
          fileName: item.resolvedPath,
        ),
      );
      seenPaths.add(actualPath);
    }

    var hasSpineItems = false;
    if (spineNode != null) {
      for (final itemRefNode in spineNode.children.whereType<XmlElement>()) {
        if (itemRefNode.name.local.toLowerCase() != 'itemref') continue;
        hasSpineItems = true;
        final idRef = _attributeValue(itemRefNode, 'idref');
        if (idRef == null || idRef.isEmpty) {
          throw const FormatException('EPUB spine itemref is missing idref');
        }
        final item = manifestById[idRef];
        if (item == null) {
          throw FormatException(
            'EPUB spine item "$idRef" is missing from the manifest',
          );
        }
        addChapter(item, requiredBySpine: true);
      }
    }

    // Recover manifest order only when no spine items define reading order.
    // Explicit navigation documents are excluded, never files named like them.
    if (!hasSpineItems) {
      for (final item in manifestItems) {
        if (item.properties.split(RegExp(r'\s+')).contains('nav')) continue;
        addChapter(item);
      }
    }
    if (flatChapters.isEmpty) {
      throw const FormatException('EPUB contains no readable documents');
    }

    final normalizedToc = toc.isNotEmpty
        ? toc
        : flatChapters
              .map(
                (chapter) =>
                    TOCItem(title: chapter.title, fileName: chapter.fileName),
              )
              .toList(growable: false);

    return ParsedEpub(
      title: title,
      author: author,
      coverImage: coverImage,
      chapters: flatChapters,
      toc: normalizedToc,
      images: images,
    );
  }

  static _ManifestItem? _resolveCoverItem(
    XmlElement? metadataNode,
    List<_ManifestItem> manifestItems,
    Map<String, _ManifestItem> manifestById,
  ) {
    final epub3Cover = manifestItems.firstWhere(
      (item) =>
          item.mediaType.toLowerCase().startsWith('image/') &&
          item.properties.split(RegExp(r'\s+')).contains('cover-image'),
      orElse: () => _ManifestItem.empty,
    );
    if (epub3Cover != _ManifestItem.empty) {
      return epub3Cover;
    }

    if (metadataNode != null) {
      for (final meta in metadataNode.children.whereType<XmlElement>()) {
        if (meta.name.local.toLowerCase() != 'meta') continue;
        final name = _attributeValue(meta, 'name');
        if (name?.toLowerCase() != 'cover') continue;
        final content = _attributeValue(meta, 'content');
        final item = manifestById[content];
        if (item != null && item.mediaType.toLowerCase().startsWith('image/')) {
          return item;
        }
      }
    }

    for (final item in manifestItems) {
      if (!item.mediaType.toLowerCase().startsWith('image/')) continue;
      final lowerPath = item.resolvedPath.toLowerCase();
      if (lowerPath.contains('cover') || lowerPath.contains('jacket')) {
        return item;
      }
    }

    return null;
  }

  static List<TOCItem> _parseToc({
    required List<_ManifestItem> manifestItems,
    required Map<String, ArchiveFile> fileByPath,
    required Map<String, String> aliasToActualPath,
  }) {
    final navItem = manifestItems.firstWhere(
      (item) => item.properties.toLowerCase().contains('nav'),
      orElse: () => _ManifestItem.empty,
    );
    if (navItem != _ManifestItem.empty) {
      final navPath = _findArchivePath(navItem.resolvedPath, aliasToActualPath);
      if (navPath != null) {
        try {
          return _parseNavDocument(
            _decodeTextFile(fileByPath[navPath]!),
            navItem.resolvedPath,
          );
        } catch (_) {}
      }
    }

    final ncxItem = manifestItems.firstWhere(
      (item) =>
          item.mediaType.toLowerCase() == 'application/x-dtbncx+xml' ||
          item.resolvedPath.toLowerCase().endsWith('.ncx'),
      orElse: () => _ManifestItem.empty,
    );
    if (ncxItem != _ManifestItem.empty) {
      final ncxPath = _findArchivePath(ncxItem.resolvedPath, aliasToActualPath);
      if (ncxPath != null) {
        try {
          return _parseNcxDocument(
            _decodeTextFile(fileByPath[ncxPath]!),
            ncxItem.resolvedPath,
          );
        } catch (_) {}
      }
    }

    return const [];
  }

  static List<TOCItem> _parseNavDocument(String document, String navPath) {
    final xml = XmlDocument.parse(document);
    final navNodes = xml.descendants.whereType<XmlElement>().where(
      (node) => node.name.local.toLowerCase() == 'nav',
    );

    XmlElement? tocNav;
    for (final nav in navNodes) {
      final type =
          _attributeValue(nav, 'type') ??
          _attributeValue(nav, 'epub:type') ??
          _attributeValue(nav, 'role');
      if (type?.toLowerCase().contains('toc') == true) {
        tocNav = nav;
        break;
      }
    }
    tocNav ??= navNodes.isNotEmpty ? navNodes.first : null;
    if (tocNav == null) return const [];

    final listNode = tocNav.children.whereType<XmlElement>().firstWhere((node) {
      final name = node.name.local.toLowerCase();
      return name == 'ol' || name == 'ul';
    }, orElse: () => XmlElement(XmlName('empty')));
    if (listNode.name.local == 'empty') return const [];

    return _parseNavList(listNode, navPath);
  }

  static List<TOCItem> _parseNavList(XmlElement listNode, String navPath) {
    final items = <TOCItem>[];

    for (final child in listNode.children.whereType<XmlElement>()) {
      final childName = child.name.local.toLowerCase();
      if (childName != 'li') continue;

      XmlElement? linkNode;
      XmlElement? nestedListNode;
      for (final liChild in child.children.whereType<XmlElement>()) {
        final name = liChild.name.local.toLowerCase();
        if (name == 'a' && linkNode == null) {
          linkNode = liChild;
        } else if ((name == 'ol' || name == 'ul') && nestedListNode == null) {
          nestedListNode = liChild;
        }
      }

      final title = linkNode?.innerText.trim();
      final href = linkNode != null ? _attributeValue(linkNode, 'href') : null;
      final resolved = href != null && href.isNotEmpty
          ? _resolveHrefWithFragment(navPath, href)
          : '';

      items.add(
        TOCItem(
          title: (title == null || title.isEmpty) ? 'Untitled' : title,
          fileName: resolved,
          subItems: nestedListNode == null
              ? const []
              : _parseNavList(nestedListNode, navPath),
        ),
      );
    }

    return items;
  }

  static List<TOCItem> _parseNcxDocument(String document, String ncxPath) {
    final xml = XmlDocument.parse(document);
    final navMap = _firstDescendantByLocalName(xml, 'navMap');
    if (navMap == null) return const [];

    final items = <TOCItem>[];
    for (final node in navMap.children.whereType<XmlElement>()) {
      if (node.name.local.toLowerCase() != 'navpoint') continue;
      items.add(_parseNcxPoint(node, ncxPath));
    }
    return items;
  }

  static TOCItem _parseNcxPoint(XmlElement navPoint, String ncxPath) {
    final labelNode = _firstDescendantByLocalName(navPoint, 'text');
    final contentNode = navPoint.children.whereType<XmlElement>().firstWhere(
      (node) => node.name.local.toLowerCase() == 'content',
      orElse: () => XmlElement(XmlName('empty')),
    );
    final src = contentNode.name.local == 'empty'
        ? ''
        : (_attributeValue(contentNode, 'src') ?? '');

    final subItems = <TOCItem>[];
    for (final child in navPoint.children.whereType<XmlElement>()) {
      if (child.name.local.toLowerCase() != 'navpoint') continue;
      subItems.add(_parseNcxPoint(child, ncxPath));
    }

    return TOCItem(
      title: labelNode?.innerText.trim().isNotEmpty == true
          ? labelNode!.innerText.trim()
          : 'Untitled',
      fileName: src.isEmpty ? '' : _resolveHrefWithFragment(ncxPath, src),
      subItems: subItems,
    );
  }

  static void _flattenTocTitles(List<TOCItem> items, Map<String, String> sink) {
    for (final item in items) {
      final path = item.fileName.split('#').first;
      if (path.isNotEmpty && item.title.isNotEmpty) {
        sink.putIfAbsent(path, () => item.title);
      }
      if (item.subItems.isNotEmpty) {
        _flattenTocTitles(item.subItems, sink);
      }
    }
  }

  static bool _isHtmlManifestItem(_ManifestItem item) {
    final mediaType = item.mediaType.toLowerCase();
    return _htmlMediaTypes.contains(mediaType) ||
        item.resolvedPath.toLowerCase().endsWith('.xhtml') ||
        item.resolvedPath.toLowerCase().endsWith('.html') ||
        item.resolvedPath.toLowerCase().endsWith('.htm');
  }

  static Uint8List _fileBytes(ArchiveFile file) {
    final raw = file.content;
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is String) return Uint8List.fromList(utf8.encode(raw));
    return Uint8List(0);
  }

  static String _decodeTextFile(ArchiveFile file) {
    final bytes = _fileBytes(file);
    Endian? endian;
    var start = 0;
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        endian = Endian.little;
        start = 2;
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        endian = Endian.big;
        start = 2;
      }
    }
    if (endian == null && bytes.length >= 4) {
      if (bytes[0] == 0x3C && bytes[1] == 0 && bytes[3] == 0) {
        endian = Endian.little;
      } else if (bytes[0] == 0 && bytes[1] == 0x3C && bytes[2] == 0) {
        endian = Endian.big;
      }
    }
    if (endian == null) return utf8.decode(bytes);
    if ((bytes.length - start).isOdd) {
      throw FormatException('Truncated UTF-16 EPUB document: ${file.name}');
    }
    final data = ByteData.sublistView(bytes, start);
    final units = Uint16List(data.lengthInBytes ~/ 2);
    var expectingLowSurrogate = false;
    for (var index = 0; index < units.length; index++) {
      final unit = data.getUint16(index * 2, endian);
      if (expectingLowSurrogate) {
        if (unit < 0xDC00 || unit > 0xDFFF) {
          throw FormatException('Invalid UTF-16 EPUB document: ${file.name}');
        }
        expectingLowSurrogate = false;
      } else if (unit >= 0xD800 && unit <= 0xDBFF) {
        expectingLowSurrogate = true;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        throw FormatException('Invalid UTF-16 EPUB document: ${file.name}');
      }
      units[index] = unit;
    }
    if (expectingLowSurrogate) {
      throw FormatException('Invalid UTF-16 EPUB document: ${file.name}');
    }
    return String.fromCharCodes(units);
  }

  static String? _findArchivePath(
    String requestedPath,
    Map<String, String> aliasToActualPath,
  ) {
    final normalized = _normalizePath(requestedPath);
    for (final alias in _pathAliases(normalized)) {
      final match = aliasToActualPath[alias];
      if (match != null) return match;
    }
    return null;
  }

  static Iterable<String> _pathAliases(String path) sync* {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty) return;
    yield normalized;

    final decoded = _decodePercentLenient(normalized);
    if (decoded != normalized) {
      yield decoded;
    }

    final lower = normalized.toLowerCase();
    if (lower != normalized) {
      yield lower;
    }

    final decodedLower = decoded.toLowerCase();
    if (decodedLower != decoded && decodedLower != lower) {
      yield decodedLower;
    }
  }

  static void _registerBinaryAliases(
    Map<String, Uint8List> sink,
    String path,
    List<int> bytes,
  ) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final normalized = _normalizePath(path);
    final baseName = normalized.split('/').isNotEmpty
        ? normalized.split('/').last
        : normalized;

    sink.putIfAbsent(normalized, () => data);

    final decoded = _decodePercentLenient(normalized);
    if (decoded != normalized) {
      sink.putIfAbsent(decoded, () => data);
    }

    if (baseName.isNotEmpty) {
      sink.putIfAbsent(baseName, () => data);
      final decodedBaseName = _decodePercentLenient(baseName);
      if (decodedBaseName != baseName) {
        sink.putIfAbsent(decodedBaseName, () => data);
      }
    }
  }

  static String? _attributeValue(XmlElement? element, String attributeName) {
    if (element == null) return null;
    final normalizedTarget = attributeName.toLowerCase();
    for (final attribute in element.attributes) {
      final local = attribute.name.local.toLowerCase();
      final qualified = attribute.name.qualified.toLowerCase();
      if (local == normalizedTarget || qualified == normalizedTarget) {
        return attribute.value;
      }
    }
    return null;
  }

  static XmlElement? _firstDescendantByLocalName(XmlNode? root, String name) {
    if (root == null) return null;
    final normalized = name.toLowerCase();
    for (final node in root.descendants.whereType<XmlElement>()) {
      if (node.name.local.toLowerCase() == normalized) {
        return node;
      }
    }
    return null;
  }

  static String? _firstDescendantText(XmlNode? root, String name) {
    final element = _firstDescendantByLocalName(root, name);
    final text = element?.innerText.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String? _extractDocumentTitle(String htmlContent) {
    try {
      final xml = XmlDocument.parse(htmlContent);
      return _firstDescendantText(xml, 'title');
    } catch (_) {
      return null;
    }
  }

  static String _resolveHrefWithFragment(String basePath, String href) {
    final fragmentIndex = href.indexOf('#');
    final pathPart = fragmentIndex >= 0
        ? href.substring(0, fragmentIndex)
        : href;
    final fragment = fragmentIndex >= 0
        ? href.substring(fragmentIndex + 1)
        : null;
    final resolvedPath = _resolveRelativePath(_dirname(basePath), pathPart);
    if (fragment == null || fragment.isEmpty) {
      return resolvedPath;
    }
    return '$resolvedPath#$fragment';
  }

  static String _resolveRelativePath(String baseDir, String href) {
    final trimmed = href.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return _normalizePath(baseDir);
    if (trimmed.startsWith('/')) {
      return _normalizePath(trimmed.substring(1));
    }
    return _normalizePath(baseDir.isEmpty ? trimmed : '$baseDir/$trimmed');
  }

  static String _dirname(String path) {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty || !normalized.contains('/')) {
      return '';
    }
    return normalized.substring(0, normalized.lastIndexOf('/'));
  }

  static String _normalizePath(String path) {
    final source = path.replaceAll('\\', '/');
    final segments = <String>[];

    for (final segment in source.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (segments.isNotEmpty) {
          segments.removeLast();
        }
        continue;
      }
      segments.add(segment);
    }

    return segments.join('/');
  }

  static String _decodePercentLenient(String input) {
    final output = StringBuffer();
    final bytes = <int>[];

    void flushBytes() {
      if (bytes.isEmpty) return;
      output.write(utf8.decode(bytes, allowMalformed: true));
      bytes.clear();
    }

    int? hexValue(String char) {
      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        return char.codeUnitAt(0) - 48;
      }
      final lower = char.toLowerCase().codeUnitAt(0);
      if (lower >= 97 && lower <= 102) {
        return lower - 87;
      }
      return null;
    }

    var index = 0;
    while (index < input.length) {
      final char = input[index];
      if (char == '%' && index + 2 < input.length) {
        final hi = hexValue(input[index + 1]);
        final lo = hexValue(input[index + 2]);
        if (hi != null && lo != null) {
          bytes.add((hi << 4) + lo);
          index += 3;
          continue;
        }
      }

      flushBytes();
      output.write(char);
      index++;
    }

    flushBytes();
    return output.toString();
  }
}

class _ManifestItem {
  final String id;
  final String href;
  final String resolvedPath;
  final String mediaType;
  final String properties;

  const _ManifestItem({
    required this.id,
    required this.href,
    required this.resolvedPath,
    required this.mediaType,
    required this.properties,
  });

  static const empty = _ManifestItem(
    id: '',
    href: '',
    resolvedPath: '',
    mediaType: '',
    properties: '',
  );
}
