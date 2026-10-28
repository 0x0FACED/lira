import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

import '../domain/discover_item.dart';
import '../domain/discover_source.dart';
import 'discover_feed_parser.dart';

/// Converts the full publisher document, never the feed's summary, to an EPUB.
class DiscoverEpubBuilder {
  DiscoverEpubBuilder(this._dio);
  final Dio _dio;

  Future<Uint8List> build(DiscoverItem item) async {
    canonicalDiscoverUrl(item.url);
    _ExtractedMaterial material;
    final number = item.documentNumber;
    if (number != null) {
      if (number <= 0 ||
          !{'www.rfc-editor.org', 'rfc-editor.org'}.contains(item.url.host)) {
        throw const FormatException(
          'RFC documents must come from the official RFC Editor',
        );
      }
      try {
        material = await _fetchHtml(item);
      } on FormatException {
        material = await _fetchRfcText(item, number);
      } on DioException catch (error) {
        if (error.response?.statusCode != 404 &&
            error.response?.statusCode != 410)
          rethrow;
        material = await _fetchRfcText(item, number);
      }
    } else {
      material = await _fetchHtml(item);
    }
    final resources = <_Resource>[];
    for (var offset = 0; offset < material.images.length; offset += 4) {
      final groups = await Future.wait(
        material.images.skip(offset).take(4).map(_fetchImage),
      );
      resources.addAll(groups.expand((group) => group));
    }
    return _packageInBackground(item, material, resources);
  }

  Future<_ExtractedMaterial> _fetchHtml(DiscoverItem item) async {
    final response = await _dio.getUri<String>(
      item.url,
      options: Options(responseType: ResponseType.plain),
    );
    final raw = response.data;
    if (raw == null || raw.trim().isEmpty) {
      throw const FormatException('The publisher returned an empty document');
    }
    final base = response.realUri;
    return Isolate.run(() => _extractHtml(raw, item, base));
  }

  Future<_ExtractedMaterial> _fetchRfcText(
    DiscoverItem item,
    int number,
  ) async {
    final response = await _dio.getUri<String>(
      Uri.https('www.rfc-editor.org', '/rfc/rfc$number.txt'),
      options: Options(responseType: ResponseType.plain),
    );
    final text = response.data;
    if (text == null ||
        text.trim().length < 160 ||
        !RegExp('RFC\\s+$number\\b', caseSensitive: false).hasMatch(text) ||
        RegExp(
          r'<(?:!doctype|html|script)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      throw const FormatException(
        'The RFC Editor did not return the requested document',
      );
    }
    return _ExtractedMaterial(
      _element('pre', {}, [XmlText(_xmlText(text))]).toXmlString(),
      'en',
      const [],
    );
  }

  Future<List<_Resource>> _fetchImage(
    _ImageRequest request, {
    Set<String> ancestors = const {},
  }) async {
    final key = request.url?.toString();
    if (key != null && ancestors.contains(key)) {
      throw const FormatException(
        'The article contains a cyclic image resource',
      );
    }
    Uint8List bytes;
    if (request.inline != null) {
      bytes = request.inline!;
    } else if (request.url!.scheme == 'data') {
      final data = request.url!.data;
      if (data == null || !data.mimeType.startsWith('image/')) {
        throw const FormatException('An article image has an invalid data URL');
      }
      bytes = data.contentAsBytes();
    } else {
      final response = await _dio.getUri<List<int>>(
        request.url!,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      bytes = data is Uint8List ? data : Uint8List.fromList(data ?? const []);
    }
    final path = request.path;
    final base = request.base ?? request.url;
    final prepared = await Isolate.run(
      () => _validatedImage(path, bytes, base),
    );
    if (prepared.resource.mediaType != 'image/svg+xml') {
      ui.Codec? codec;
      try {
        codec = await ui.instantiateImageCodec(prepared.resource.bytes);
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } catch (error) {
        throw FormatException(
          'The publisher returned a corrupt article image: $error',
        );
      } finally {
        codec?.dispose();
      }
    }
    final result = <_Resource>[prepared.resource];
    final visited = {...ancestors, if (key != null) key};
    for (final dependency in prepared.dependencies) {
      result.addAll(await _fetchImage(dependency, ancestors: visited));
    }
    return result;
  }
}

class _ImageRequest {
  const _ImageRequest(this.path, {this.url, this.inline, this.base});
  final String path;
  final Uri? url;
  final Uint8List? inline;
  final Uri? base;
}

class _Resource {
  const _Resource(this.path, this.mediaType, this.bytes);
  final String path;
  final String mediaType;
  final Uint8List bytes;
}

class _PreparedResource {
  const _PreparedResource(this.resource, [this.dependencies = const []]);
  final _Resource resource;
  final List<_ImageRequest> dependencies;
}

class _ExtractedMaterial {
  const _ExtractedMaterial(this.body, this.language, this.images);
  final String body;
  final String language;
  final List<_ImageRequest> images;
}

const _blockedTags = {
  'script',
  'style',
  'link',
  'meta',
  'base',
  'iframe',
  'frame',
  'frameset',
  'object',
  'embed',
  'applet',
  'canvas',
  'form',
  'input',
  'button',
  'select',
  'textarea',
  'nav',
  'aside',
  'footer',
  'noscript',
  'template',
  'audio',
  'video',
};
const _contentTags = {
  'div',
  'section',
  'article',
  'header',
  'p',
  'span',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'pre',
  'code',
  'tt',
  'kbd',
  'samp',
  'var',
  'ul',
  'ol',
  'li',
  'dl',
  'dt',
  'dd',
  'table',
  'caption',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'th',
  'td',
  'colgroup',
  'col',
  'figure',
  'figcaption',
  'a',
  'img',
  'br',
  'hr',
  'em',
  'strong',
  'b',
  'i',
  'u',
  's',
  'del',
  'ins',
  'sub',
  'sup',
  'abbr',
  'cite',
  'q',
  'dfn',
  'mark',
  'small',
  'details',
  'summary',
  'time',
};

_ExtractedMaterial _extractHtml(String raw, DiscoverItem item, Uri base) {
  final document = html.parse(raw);
  dom.Element? root;
  if (item.documentNumber != null) {
    final meta = document
        .querySelector('meta[name="rfc.number"]')
        ?.attributes['content'];
    final body = document.body;
    final number = item.documentNumber!;
    if (meta == '$number' ||
        (body != null &&
            body.querySelector('pre') != null &&
            RegExp(
              'RFC\\s+$number\\b',
              caseSensitive: false,
            ).hasMatch(body.text))) {
      root = body;
    }
  } else {
    for (final selector in [
      '[itemprop="articleBody"]',
      '.article-content',
      '.post-content',
      '.post__content',
      '.post-full-content',
      '.entry-content',
      'article',
    ]) {
      final candidates =
          document
              .querySelectorAll(selector)
              .where((element) => element.text.trim().length >= 160)
              .toList()
            ..sort((a, b) => b.text.length.compareTo(a.text.length));
      if (candidates.isNotEmpty) {
        root = candidates.first;
        break;
      }
    }
  }
  if (root == null)
    throw const FormatException('No full article content was found');
  final images = <_ImageRequest>[];
  final imagePaths = <String, String>{};
  final seenIds = <String>{};

  List<XmlNode> convert(dom.Node node) {
    if (node is dom.Text) return [XmlText(_xmlText(node.data))];
    if (node is! dom.Element) return const [];
    final tag = node.localName ?? '';
    if (node.attributes.containsKey('hidden') ||
        node.attributes['aria-hidden'] == 'true') {
      return const [];
    }
    if ({'video', 'audio', 'iframe'}.contains(tag)) {
      final result = <XmlNode>[];
      final poster = node.attributes['poster'];
      if (poster != null && poster.isNotEmpty) {
        result.addAll(
          convert(dom.Element.tag('img')..attributes['src'] = poster),
        );
      }
      final source =
          node.attributes['src'] ??
          node.querySelector('source')?.attributes['src'];
      final uri = source == null ? null : Uri.tryParse(source);
      if (uri != null) {
        final resolved = base.resolveUri(uri);
        if ({'http', 'https'}.contains(resolved.scheme) &&
            resolved.userInfo.isEmpty) {
          result.add(
            _element('p', {}, [
              _element(
                'a',
                {'href': resolved.toString()},
                [XmlText(node.attributes['title'] ?? resolved.toString())],
              ),
            ]),
          );
        }
      }
      return result;
    }
    if (_blockedTags.contains(tag)) return const [];
    if (tag == 'svg') {
      final path = 'images/image-${images.length}.svg';
      final bytes = Uint8List.fromList(utf8.encode(node.outerHtml));
      images.add(_ImageRequest(path, inline: bytes, base: base));
      return [
        _element('img', {
          'src': path,
          'alt': node.attributes['aria-label'] ?? '',
        }, []),
      ];
    }
    if (tag == 'img') {
      final source =
          node.attributes['data-src'] ??
          node.attributes['data-original'] ??
          node.attributes['src'];
      if (source == null || source.trim().isEmpty) {
        throw const FormatException(
          'An article image is missing its resource URL',
        );
      }
      final uri = base.resolve(source);
      if (!{'https', 'http', 'data'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty ||
          (uri.scheme != 'data' && uri.host.isEmpty)) {
        throw const FormatException(
          'An article image uses an unsafe resource URL',
        );
      }
      final path = imagePaths.putIfAbsent(uri.toString(), () {
        final path = 'images/image-${images.length}';
        images.add(_ImageRequest(path, url: uri));
        return path;
      });
      return [
        _element('img', {'src': path, 'alt': node.attributes['alt'] ?? ''}, []),
      ];
    }
    final children = node.nodes.expand(convert).toList();
    if (!_contentTags.contains(tag)) return children;
    final attributes = <String, String>{};
    final id = node.id.isNotEmpty
        ? node.id
        : (tag == 'a' ? node.attributes['name'] : null);
    if (id != null && id.isNotEmpty && seenIds.add(id)) attributes['id'] = id;
    for (final attribute in ['title', 'lang', 'dir']) {
      final value = node.attributes[attribute];
      if (value != null) attributes[attribute] = value;
    }
    if (tag == 'td' || tag == 'th') {
      for (final attribute in ['colspan', 'rowspan', 'scope']) {
        final value = node.attributes[attribute];
        if (value != null) attributes[attribute] = value;
      }
    }
    if (tag == 'ol' || tag == 'li') {
      for (final attribute in ['start', 'value', 'type']) {
        final value = node.attributes[attribute];
        if (value != null) attributes[attribute] = value;
      }
    }
    if (tag == 'a') {
      final href = node.attributes['href'];
      if (href != null && href.trim().isNotEmpty) {
        final uri = Uri.tryParse(href.trim());
        if (uri != null) {
          final resolved = base.resolveUri(uri);
          if (href.trim().startsWith('#') ||
              ({'http', 'https'}.contains(resolved.scheme) &&
                  resolved.userInfo.isEmpty &&
                  resolved.hasFragment &&
                  (canonicalDiscoverUrl(resolved) ==
                          canonicalDiscoverUrl(base) ||
                      canonicalDiscoverUrl(resolved) ==
                          canonicalDiscoverUrl(item.url)))) {
            attributes['href'] = '#${resolved.fragment}';
          } else if ({'http', 'https', 'mailto'}.contains(resolved.scheme) &&
              resolved.userInfo.isEmpty) {
            attributes['href'] = resolved.toString();
          }
        }
      }
    }
    return [_element(tag, attributes, children)];
  }

  final content = _element('div', {}, root.nodes.expand(convert).toList());
  final text = content.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length < 160) {
    throw const FormatException(
      'The publisher document has no substantive article content',
    );
  }
  final language = document.documentElement?.attributes['lang'] ?? 'en';
  return _ExtractedMaterial(content.toXmlString(), language, images);
}

String _xmlText(String value) =>
    value.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '');

XmlElement _element(
  String name,
  Map<String, String> attributes,
  List<XmlNode> children,
) => XmlElement(
  XmlName(name),
  attributes.entries
      .map((entry) => XmlAttribute(XmlName(entry.key), _xmlText(entry.value)))
      .toList(),
  children,
);

_PreparedResource _validatedImage(String path, Uint8List bytes, Uri? base) {
  bool starts(List<int> signature) =>
      bytes.length >= signature.length &&
      signature.indexed.every((entry) => bytes[entry.$1] == entry.$2);
  String? mediaType;
  if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
    mediaType = 'image/png';
  if (starts([0xff, 0xd8, 0xff])) mediaType = 'image/jpeg';
  if (starts(utf8.encode('GIF87a')) || starts(utf8.encode('GIF89a')))
    mediaType = 'image/gif';
  if (bytes.length >= 12 &&
      starts(utf8.encode('RIFF')) &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP')
    mediaType = 'image/webp';
  if (mediaType != null)
    return _PreparedResource(_Resource(path, mediaType, bytes));
  final text = utf8.decode(bytes, allowMalformed: true).trimLeft();
  if (text.startsWith('<svg') || text.startsWith('<?xml')) {
    final svg = XmlDocument.parse(text).rootElement;
    if (svg.name.local != 'svg')
      throw const FormatException('The image is not SVG');
    final dependencies = <_ImageRequest>[];
    for (final image in _svgImages(svg)) {
      final href = image.attributes
          .where((attribute) => attribute.name.local == 'href')
          .map((attribute) => attribute.value)
          .firstOrNull;
      if (href == null || href.startsWith('#')) continue;
      final uri = base?.resolve(href) ?? Uri.parse(href);
      if (!{'http', 'https', 'data'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException(
          'The SVG contains an unsafe image resource',
        );
      }
      final dependencyPath = '$path-resource-${dependencies.length}';
      dependencies.add(_ImageRequest(dependencyPath, url: uri));
      image.attributes.removeWhere(
        (attribute) => attribute.name.local == 'href',
      );
      image.attributes.add(
        XmlAttribute(XmlName('href'), dependencyPath.split('/').last),
      );
    }
    final sanitized = _sanitizeSvg(svg);
    if (sanitized == null)
      throw const FormatException('The SVG image is empty');
    return _PreparedResource(
      _Resource(
        path,
        'image/svg+xml',
        Uint8List.fromList(utf8.encode(sanitized.toXmlString())),
      ),
      dependencies,
    );
  }
  throw const FormatException(
    'The publisher returned an unsupported or invalid article image',
  );
}

Iterable<XmlElement> _svgImages(XmlElement node) sync* {
  if (!_svgTags.contains(node.name.local)) return;
  if (node.name.local == 'image') yield node;
  for (final child in node.childElements) {
    yield* _svgImages(child);
  }
}

const _svgTags = {
  'svg',
  'g',
  'defs',
  'path',
  'rect',
  'circle',
  'ellipse',
  'line',
  'polyline',
  'polygon',
  'text',
  'tspan',
  'title',
  'desc',
  'clipPath',
  'mask',
  'use',
  'image',
  'linearGradient',
  'radialGradient',
  'stop',
  'pattern',
  'marker',
};
const _svgAttributes = {
  'id',
  'viewBox',
  'width',
  'height',
  'x',
  'y',
  'x1',
  'x2',
  'y1',
  'y2',
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'd',
  'points',
  'transform',
  'fill',
  'fill-rule',
  'fill-opacity',
  'stroke',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-opacity',
  'opacity',
  'clip-path',
  'clip-rule',
  'mask',
  'offset',
  'stop-color',
  'stop-opacity',
  'gradientUnits',
  'gradientTransform',
  'spreadMethod',
  'fx',
  'fy',
  'patternUnits',
  'patternContentUnits',
  'patternTransform',
  'markerWidth',
  'markerHeight',
  'markerUnits',
  'refX',
  'refY',
  'orient',
  'text-anchor',
  'dominant-baseline',
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'preserveAspectRatio',
  'dx',
  'dy',
  'rotate',
  'textLength',
  'lengthAdjust',
};

XmlElement? _sanitizeSvg(XmlElement node) {
  final tag = node.name.local;
  if (!_svgTags.contains(tag)) return null;
  final attributes = <String, String>{};
  if (tag == 'svg') attributes['xmlns'] = 'http://www.w3.org/2000/svg';
  for (final attribute in node.attributes) {
    final name = attribute.name.local;
    final value = attribute.value;
    if (name == 'href' &&
        (value.startsWith('#') ||
            (tag == 'image' && RegExp(r'^[\w.-]+$').hasMatch(value)))) {
      attributes['href'] = value;
    } else if (_svgAttributes.contains(name) && _safeSvgValue(value)) {
      attributes[name] = value;
    }
  }
  final style = node.getAttribute('style');
  if (style != null) {
    for (final declaration in style.split(';')) {
      final colon = declaration.indexOf(':');
      if (colon < 0) continue;
      final name = declaration.substring(0, colon).trim();
      final value = declaration.substring(colon + 1).trim();
      if (_svgAttributes.contains(name) &&
          name != 'id' &&
          _safeSvgValue(value)) {
        attributes[name] = value;
      }
    }
  }
  final children = <XmlNode>[];
  for (final child in node.children) {
    if (child is XmlText) children.add(XmlText(_xmlText(child.value)));
    if (child is XmlElement) {
      final converted = _sanitizeSvg(child);
      if (converted != null) children.add(converted);
    }
  }
  return _element(tag, attributes, children);
}

bool _safeSvgValue(String value) =>
    !value.contains(r'\') &&
    !RegExp(
      r'(?:https?:|data:|javascript:|@import|expression\s*\()',
      caseSensitive: false,
    ).hasMatch(value) &&
    (!RegExp(r'url\s*\(', caseSensitive: false).hasMatch(value) ||
        RegExp(r'^url\(#[\w.-]+\)$', caseSensitive: false).hasMatch(value));

Future<Uint8List> _packageInBackground(
  DiscoverItem item,
  _ExtractedMaterial material,
  List<_Resource> resources,
) => Isolate.run(() => _packageEpub(item, material, resources));

Uint8List _packageEpub(
  DiscoverItem item,
  _ExtractedMaterial material,
  List<_Resource> resources,
) {
  final archive = Archive();
  void add(String path, String text, {bool compress = true}) {
    final bytes = utf8.encode(text);
    archive.addFile(
      ArchiveFile(path, bytes.length, bytes)..compress = compress,
    );
  }

  String escaped(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(_xmlText(value));
  final title = escaped(item.title);
  final author = escaped(item.author);
  final id = escaped(item.id);
  final source = discoverSourceCatalog
      .where((source) => source.id == item.sourceId)
      .firstOrNull;
  final publisher = escaped(source?.name ?? item.sourceId);
  final url = escaped(item.url.toString());
  final now = DateTime.now().toUtc().toIso8601String().split('.').first;
  final publication = item.publishedAt == null
      ? ''
      : '<dc:date>${item.publishedAt!.toUtc().toIso8601String()}</dc:date>';
  add('mimetype', 'application/epub+zip', compress: false);
  add(
    'META-INF/container.xml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''',
  );
  final language = const HtmlEscape(
    HtmlEscapeMode.attribute,
  ).convert(material.language);
  final manifest = StringBuffer();
  for (var index = 0; index < resources.length; index++) {
    final resource = resources[index];
    archive.addFile(
      ArchiveFile(
        'EPUB/${resource.path}',
        resource.bytes.length,
        resource.bytes,
      ),
    );
    manifest.write(
      '<item id="image$index" href="${resource.path}" media-type="${resource.mediaType}"/>',
    );
  }
  add('EPUB/package.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="material-id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="material-id">$id</dc:identifier><dc:title>$title</dc:title><dc:creator>$author</dc:creator><dc:language>$language</dc:language><dc:source>$url</dc:source><dc:publisher>$publisher</dc:publisher>$publication<meta property="dcterms:modified">${now}Z</meta></metadata>
<manifest><item id="content" href="content.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/><item id="style" href="style.css" media-type="text/css"/>$manifest</manifest>
<spine toc="ncx"><itemref idref="content"/></spine></package>''');
  final body = XmlDocument.parse(material.body).rootElement;
  final headings = body.descendants
      .whereType<XmlElement>()
      .where((node) => {'h1', 'h2', 'h3'}.contains(node.name.local))
      .toList();
  final ids = body.descendants
      .whereType<XmlElement>()
      .map((node) => node.getAttribute('id'))
      .toSet();
  var headingIndex = 0;
  final navigation = StringBuffer(
    '<li><a href="content.xhtml">$title</a></li>',
  );
  for (final heading in headings) {
    var anchor = heading.getAttribute('id');
    if (anchor == null) {
      do {
        anchor = 'lira-heading-${headingIndex++}';
      } while (ids.contains(anchor));
      heading.attributes.add(XmlAttribute(XmlName('id'), anchor));
      ids.add(anchor);
    }
    final href = 'content.xhtml#${Uri.encodeComponent(anchor)}';
    navigation.write(
      '<li><a href="$href">${escaped(heading.innerText)}</a></li>',
    );
  }
  add(
    'EPUB/content.xhtml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="$language" lang="$language"><head><title>$title</title><link rel="stylesheet" href="style.css" type="text/css"/></head><body><header><h1>$title</h1><p>$author</p><p><a href="${const HtmlEscape(HtmlEscapeMode.attribute).convert(item.url.toString())}">$publisher</a></p></header>${body.toXmlString()}</body></html>''',
  );
  add(
    'EPUB/nav.xhtml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>$title</title></head><body><nav epub:type="toc" id="toc"><h1>$title</h1><ol>$navigation</ol></nav></body></html>''',
  );
  add(
    'EPUB/toc.ncx',
    '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="$id"/></head><docTitle><text>$title</text></docTitle><navMap><navPoint id="start" playOrder="1"><navLabel><text>$title</text></navLabel><content src="content.xhtml"/></navPoint></navMap></ncx>''',
  );
  add(
    'EPUB/style.css',
    '''body { line-height: 1.5; } img, svg { max-width: 100%; height: auto; }
pre { white-space: pre; font-family: monospace; } code, tt, kbd, samp { font-family: monospace; }
table { border-collapse: collapse; } th, td { border: 1px solid; padding: 0.35em; }
blockquote { margin-left: 1em; } figcaption { font-style: italic; }''',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
