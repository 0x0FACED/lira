import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;

import 'epub_paths.dart';
import 'epub_styles.dart';

/// A self-contained local image. Raster bytes are never decoded or copied.
class EpubImage {
  final Uint8List? _originalBytes;
  final xml.XmlElement? _element;
  Uint8List? _serialized;
  final bool isSvg;
  final double? aspectRatio;

  EpubImage({required Uint8List bytes, required this.isSvg, this.aspectRatio})
    : _originalBytes = bytes,
      _element = null;

  EpubImage._svg(xml.XmlElement element, this.aspectRatio)
    : _element = element,
      _originalBytes = null,
      isSvg = true;

  Uint8List get bytes =>
      _originalBytes ?? (_serialized ??= utf8.encode(_element!.toXmlString()));
}

/// Resolves archive/data images without basename guesses or network access.
class EpubImageResolver {
  final Map<String, Uint8List> _images;
  final Map<String, String> _stylesheets;
  final TextStyle _baseStyle;

  EpubImageResolver({
    required Map<String, Uint8List> images,
    required Map<String, String> stylesheets,
    required TextStyle baseStyle,
  }) : _images = images,
       _stylesheets = stylesheets,
       _baseStyle = baseStyle;

  /// Missing top-level resources return null. Corrupt SVGs and cycles throw
  /// [FormatException], including failures in visible embedded dependencies.
  EpubImage? resolve(String src, {required String documentPath}) {
    try {
      return _resolve(src, documentPath, <String>{});
    } on _MissingImage {
      return null;
    }
  }

  EpubImage? resolveElement(
    dom.Element element, {
    required String documentPath,
  }) {
    final source = _source(element);
    return source == null ? null : resolve(source, documentPath: documentPath);
  }

  /// Uses the chapter cascade for inline SVGs, including hidden descendants.
  ///
  /// A corrupt visible dependency throws [FormatException], rather than
  /// returning an apparently valid but incomplete image. A hidden SVG remains
  /// a valid empty SVG, even when its hidden descendants have broken resources.
  EpubImage inlineSvg(
    dom.Element element, {
    required EpubStyleResolver styles,
    required EpubStyle style,
    required String documentPath,
  }) => _svg(
    _xmlFromDom(element),
    element,
    styles,
    style,
    documentPath,
    <String>{},
  );

  EpubImage _resolve(
    String source,
    String documentPath,
    Set<String> resolving,
  ) {
    final src = source.trim();
    if (src.isEmpty) throw const _MissingImage();
    late Uint8List bytes;
    late String resourcePath;
    late String key;
    var declaredSvg = false;
    if (src.toLowerCase().startsWith('data:')) {
      final data = UriData.parse(src);
      final contents = data.contentAsBytes();
      bytes = contents;
      declaredSvg = data.mimeType.toLowerCase() == 'image/svg+xml';
      // Data SVGs have no archive path; local references retain their container.
      resourcePath = documentPath;
      key = '$documentPath\n$src';
    } else {
      final path = resolveEpubPath(documentPath, src);
      final contents = path == null ? null : _images[path];
      if (path == null || contents == null) {
        throw const _MissingImage();
      }
      bytes = contents;
      resourcePath = path;
      key = path;
      declaredSvg = path.toLowerCase().endsWith('.svg');
    }
    if (!declaredSvg && !_startsWithXml(bytes)) {
      return EpubImage(bytes: bytes, isSvg: false);
    }
    if (!resolving.add(key)) {
      throw FormatException('Cyclic SVG image reference: $resourcePath');
    }
    try {
      final document = _readSvg(bytes);
      final element = _domFromXml(document.rootElement);
      final styleDocument = dom.Document()..append(element);
      final styles = EpubStyleResolver(
        document: styleDocument,
        documentPath: resourcePath,
        stylesheets: _stylesheets,
        baseStyle: _baseStyle,
      );
      return _svg(
        document.rootElement,
        element,
        styles,
        styles.resolve(element, styles.root),
        resourcePath,
        resolving,
      );
    } finally {
      resolving.remove(key);
    }
  }

  EpubImage _svg(
    xml.XmlElement svg,
    dom.Element element,
    EpubStyleResolver styles,
    EpubStyle style,
    String documentPath,
    Set<String> resolving,
  ) {
    if (svg.name.local.toLowerCase() != 'svg') {
      throw const FormatException('Image is not an SVG document');
    }
    final ratio = _aspectRatio(svg);
    final visibleImages = <xml.XmlElement>[];
    var wrapper = true;
    void visit(
      xml.XmlElement node,
      dom.Element source,
      EpubStyle computed,
      EpubStyle? parent,
    ) {
      if (computed.hidden || _hiddenAttribute(source)) {
        node.children.clear();
        // Root must survive as a valid empty image, not a failed-file fallback.
        if (identical(node, svg)) {
          node.attributes.removeWhere(
            (attribute) => const {
              'style',
              'display',
              'visibility',
            }.contains(attribute.name.local),
          );
        } else {
          node.parent!.children.remove(node);
        }
        return;
      }
      if (!_simpleWrapperElement(node, identical(node, svg))) wrapper = false;
      if (node.name.local.toLowerCase() == 'image') visibleImages.add(node);
      _applyTypography(node, computed, parent);
      final nodes = node.childElements.toList();
      final sources = source.children.toList();
      for (var index = 0; index < nodes.length; index++) {
        visit(
          nodes[index],
          sources[index],
          styles.resolve(sources[index], computed),
          computed,
        );
      }
    }

    visit(svg, element, style, styles.root);
    EpubImage? singleImage;
    if (visibleImages.length == 1) {
      singleImage = _requiredImage(
        visibleImages.single,
        documentPath,
        resolving,
      );
      if (wrapper &&
          _fillsViewport(visibleImages.single, svg) &&
          !singleImage.isSvg) {
        return ratio == null
            ? singleImage
            : EpubImage(
                bytes: singleImage.bytes,
                isSvg: false,
                aspectRatio: ratio,
              );
      }
    }
    for (final image in visibleImages) {
      final resource =
          singleImage ?? _requiredImage(image, documentPath, resolving);
      if (resource.isSvg) {
        _inlineVector(image, resource._element!, svg);
        continue;
      }
      final bytes = resource.bytes;
      final uri = 'data:${_mimeType(bytes)};base64,${base64Encode(bytes)}';
      image.attributes.removeWhere(
        (attribute) => attribute.name.local == 'href',
      );
      _setAttribute(image, 'href', uri);
      // Both forms are supported by SVG consumers; neither leaves an external URL.
      _setAttribute(image, 'xlink:href', uri);
    }
    if (svg.getAttribute('xmlns') == null) {
      _setAttribute(svg, 'xmlns', 'http://www.w3.org/2000/svg');
    }
    _setAttribute(svg, 'xmlns:xlink', 'http://www.w3.org/1999/xlink');
    return EpubImage._svg(svg, ratio);
  }

  EpubImage _requiredImage(
    xml.XmlElement image,
    String documentPath,
    Set<String> resolving,
  ) {
    final source = _xmlSource(image);
    if (source == null) throw const FormatException('SVG image has no source');
    try {
      return _resolve(source, documentPath, resolving);
    } on _MissingImage {
      throw FormatException('Unresolved SVG image: $source');
    }
  }

  // flutter_svg cannot paint SVG data URIs in <image>. Inline vector resources
  // as isolated, clipped groups instead, preserving the image viewport.
  static void _inlineVector(
    xml.XmlElement image,
    xml.XmlElement resource,
    xml.XmlElement document,
  ) {
    final allElements = [
      document,
      ...document.descendants.whereType<xml.XmlElement>(),
    ];
    var index = 0;
    String prefix;
    do {
      prefix = '_epub_image_${index++}_';
    } while (allElements.any(
      (node) => node.getAttribute('id')?.startsWith(prefix) ?? false,
    ));
    final imported = [
      resource,
      ...resource.descendants.whereType<xml.XmlElement>(),
    ];
    final ids = <String, String>{
      for (final node in imported)
        if (node.getAttribute('id') case final String id) id: '$prefix$id',
    };
    String rewriteReferences(String value) => value.replaceAllMapped(
      RegExp(r'''url\(\s*(['"]?)#([^'")\s]+)\1\s*\)'''),
      (match) => 'url(#${ids[match[2]] ?? match[2]})',
    );
    for (final node in imported) {
      for (final attribute in node.attributes) {
        if (attribute.name.local == 'id') {
          attribute.value = ids[attribute.value]!;
        } else if (attribute.name.local == 'href' &&
            attribute.value.startsWith('#')) {
          final id = ids[attribute.value.substring(1)];
          if (id != null) attribute.value = '#$id';
        } else {
          attribute.value = rewriteReferences(attribute.value);
        }
      }
      if (node.name.local == 'style') {
        for (final text in node.children.whereType<xml.XmlText>()) {
          var css = rewriteReferences(text.value);
          // Only selector preludes are rewritten; hex colors in declarations
          // must not be mistaken for ID selectors.
          css = css.replaceAllMapped(RegExp(r'([^{}]+)\{'), (match) {
            final selector = match[1]!.replaceAllMapped(
              RegExp(r'#([a-zA-Z_][a-zA-Z0-9_-]*)'),
              (id) => '#${ids[id[1]] ?? id[1]}',
            );
            return '$selector{';
          });
          text.value = css;
        }
      }
    }
    final outerBox = _viewBox(document);
    final outerWidth = outerBox?[2] ?? _number(document.getAttribute('width'));
    final outerHeight =
        outerBox?[3] ?? _number(document.getAttribute('height'));
    final box = _viewBox(resource);
    final naturalWidth = _number(resource.getAttribute('width')) ?? box?[2];
    final naturalHeight = _number(resource.getAttribute('height')) ?? box?[3];
    final width =
        _length(image.getAttribute('width'), outerWidth) ??
        naturalWidth ??
        _length(resource.getAttribute('width'), outerWidth);
    final height =
        _length(image.getAttribute('height'), outerHeight) ??
        naturalHeight ??
        _length(resource.getAttribute('height'), outerHeight);
    if (width == null || height == null) {
      throw const FormatException('Embedded SVG image has no finite viewport');
    }
    final x = _length(image.getAttribute('x'), outerWidth) ?? 0;
    final y = _length(image.getAttribute('y'), outerHeight) ?? 0;
    final sourceWidth =
        box?[2] ?? _length(resource.getAttribute('width'), width) ?? width;
    final sourceHeight =
        box?[3] ?? _length(resource.getAttribute('height'), height) ?? height;
    final wrapper = xml.XmlElement(xml.XmlName('g'));
    for (final attribute in image.attributes.toList()) {
      if (const {
        'x',
        'y',
        'width',
        'height',
        'href',
        'preserveAspectRatio',
      }.contains(attribute.name.local))
        continue;
      image.attributes.remove(attribute);
      wrapper.attributes.add(attribute);
    }
    final parent = image.parent!;
    final position = parent.children.indexOf(image);
    parent.children[position] = wrapper;
    if (width <= 0 || height <= 0 || sourceWidth <= 0 || sourceHeight <= 0)
      return;
    final aspect =
        (image.getAttribute('preserveAspectRatio') ??
                resource.getAttribute('preserveAspectRatio') ??
                'xMidYMid meet')
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part != 'defer')
            .toList();
    var scaleX = width / sourceWidth;
    var scaleY = height / sourceHeight;
    var offsetX = 0.0;
    var offsetY = 0.0;
    if (aspect.isEmpty || aspect.first != 'none') {
      final scale = aspect.contains('slice')
          ? math.max(scaleX, scaleY)
          : math.min(scaleX, scaleY);
      scaleX = scaleY = scale;
      final alignment = aspect.isEmpty ? 'xMidYMid' : aspect.first;
      offsetX =
          (width - sourceWidth * scale) *
          (alignment.startsWith('xMin')
              ? 0
              : alignment.startsWith('xMax')
              ? 1
              : 0.5);
      offsetY =
          (height - sourceHeight * scale) *
          (alignment.endsWith('YMin')
              ? 0
              : alignment.endsWith('YMax')
              ? 1
              : 0.5);
    }
    var clipId = '${prefix}viewport';
    while (ids.values.contains(clipId)) {
      clipId = '${clipId}_';
    }
    final clip = xml.XmlElement(
      xml.XmlName('clipPath'),
      [
        xml.XmlAttribute(xml.XmlName('id'), clipId),
        xml.XmlAttribute(xml.XmlName('clipPathUnits'), 'userSpaceOnUse'),
      ],
      [
        xml.XmlElement(xml.XmlName('rect'), [
          xml.XmlAttribute(xml.XmlName('x'), '$x'),
          xml.XmlAttribute(xml.XmlName('y'), '$y'),
          xml.XmlAttribute(xml.XmlName('width'), '$width'),
          xml.XmlAttribute(xml.XmlName('height'), '$height'),
        ]),
      ],
    );
    wrapper.children.add(xml.XmlElement(xml.XmlName('defs'), [], [clip]));
    final clipped = xml.XmlElement(xml.XmlName('g'), [
      xml.XmlAttribute(xml.XmlName('clip-path'), 'url(#$clipId)'),
    ]);
    wrapper.children.add(clipped);
    final transformed = xml.XmlElement(xml.XmlName('g'), [
      xml.XmlAttribute(
        xml.XmlName('transform'),
        'translate(${x + offsetX} ${y + offsetY}) '
        'scale($scaleX $scaleY) translate(${-(box?[0] ?? 0)} ${-(box?[1] ?? 0)})',
      ),
    ]);
    clipped.children.add(transformed);
    final content = xml.XmlElement(xml.XmlName('g'));
    for (final attribute in resource.attributes.toList()) {
      if (const {
        'x',
        'y',
        'width',
        'height',
        'viewBox',
        'preserveAspectRatio',
      }.contains(attribute.name.local))
        continue;
      resource.attributes.remove(attribute);
      content.attributes.add(attribute);
    }
    // Referenced SVGs start a separate paint inheritance context.
    if (content.getAttribute('fill') == null)
      _setAttribute(content, 'fill', 'black');
    if (content.getAttribute('stroke') == null)
      _setAttribute(content, 'stroke', 'none');
    if (content.getAttribute('color') == null)
      _setAttribute(content, 'color', 'black');
    for (final child in resource.children.toList()) {
      resource.children.remove(child);
      content.children.add(child);
    }
    transformed.children.add(content);
  }

  static double? _length(String? value, double? extent) {
    if (value == null) return null;
    if (value.trim().endsWith('%')) {
      final percent = double.tryParse(
        value.trim().replaceFirst(RegExp(r'%$'), ''),
      );
      return percent == null || !percent.isFinite || extent == null
          ? null
          : extent * percent / 100;
    }
    return _number(value);
  }

  static xml.XmlDocument _readSvg(Uint8List bytes) {
    try {
      final document = xml.XmlDocument.parse(utf8.decode(bytes));
      if (document.rootElement.name.local.toLowerCase() != 'svg') {
        throw const FormatException('Image is not an SVG document');
      }
      return document;
    } on xml.XmlParserException catch (error) {
      throw FormatException('Invalid SVG: $error');
    } on xml.XmlTagException catch (error) {
      throw FormatException('Invalid SVG: $error');
    }
  }

  static bool _startsWithXml(Uint8List bytes) {
    var index =
        bytes.length >= 3 &&
            bytes[0] == 0xef &&
            bytes[1] == 0xbb &&
            bytes[2] == 0xbf
        ? 3
        : 0;
    while (index < bytes.length &&
        const [9, 10, 13, 32].contains(bytes[index])) {
      index++;
    }
    return index < bytes.length && bytes[index] == 60;
  }

  static String? _source(dom.Element element) {
    for (final name in const [
      'src',
      'data-src',
      'href',
      'xlink:href',
      'data',
    ]) {
      for (final entry in element.attributes.entries) {
        if (entry.key.toString() == name && entry.value.trim().isNotEmpty) {
          return entry.value;
        }
      }
    }
    for (final entry in element.attributes.entries) {
      if (entry.key.toString().endsWith(':href') &&
          entry.value.trim().isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  static String? _xmlSource(xml.XmlElement element) {
    for (final attribute in element.attributes) {
      if (attribute.name.qualified == 'href' &&
          attribute.value.trim().isNotEmpty) {
        return attribute.value;
      }
    }
    for (final attribute in element.attributes) {
      if (attribute.name.local == 'href' && attribute.value.trim().isNotEmpty) {
        return attribute.value;
      }
    }
    return null;
  }

  static bool _hiddenAttribute(dom.Element element) =>
      element.attributes['display']?.trim().toLowerCase() == 'none' ||
      const {
        'hidden',
        'collapse',
      }.contains(element.attributes['visibility']?.trim().toLowerCase());

  static bool _simpleWrapperElement(xml.XmlElement element, bool root) {
    final name = element.name.local.toLowerCase();
    if (!(root || const {'g', 'image', 'title', 'desc'}.contains(name)))
      return false;
    for (final attribute in element.attributes) {
      final name = attribute.name.local;
      if (const {'transform', 'clip-path', 'mask', 'filter'}.contains(name))
        return false;
      if (name == 'opacity' && double.tryParse(attribute.value) != 1)
        return false;
      if (name == 'style') {
        for (final declaration in attribute.value.split(';')) {
          if (declaration.trim().isEmpty) continue;
          final colon = declaration.indexOf(':');
          if (colon < 0) return false;
          final property = declaration.substring(0, colon).trim().toLowerCase();
          if (!const {
            'display',
            'visibility',
            'font-family',
          }.contains(property))
            return false;
        }
      }
    }
    return true;
  }

  static bool _fillsViewport(xml.XmlElement image, xml.XmlElement svg) {
    for (final element in [image, svg]) {
      final aspect = element.getAttribute('preserveAspectRatio')?.trim();
      if (aspect != null &&
          !const {'', 'xMidYMid', 'xMidYMid meet'}.contains(aspect))
        return false;
    }
    for (final axis in const ['x', 'y']) {
      final value = image.getAttribute(axis);
      if (value != null && _number(value) != 0) return false;
    }
    final viewBox = _viewBox(svg);
    if (viewBox != null && (viewBox[0] != 0 || viewBox[1] != 0)) return false;
    for (var axis = 0; axis < 2; axis++) {
      final name = axis == 0 ? 'width' : 'height';
      final value = image.getAttribute(name);
      if (value == null) return false;
      if (value.trim() == '100%') continue;
      final dimension = _number(value);
      final viewport = viewBox?[axis + 2] ?? _number(svg.getAttribute(name));
      if (dimension == null || viewport == null || dimension != viewport)
        return false;
    }
    return true;
  }

  static double? _aspectRatio(xml.XmlElement element) {
    final width = _number(element.getAttribute('width'));
    final height = _number(element.getAttribute('height'));
    if (width != null && height != null && width > 0 && height > 0) {
      final ratio = width / height;
      if (ratio.isFinite && ratio > 0) return ratio;
    }
    final viewBox = _viewBox(element);
    final ratio = viewBox == null ? null : viewBox[2] / viewBox[3];
    return ratio != null && ratio.isFinite && ratio > 0 ? ratio : null;
  }

  static double? _number(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)(?:px)?\s*$',
    ).firstMatch(value);
    final number = match == null ? null : double.tryParse(match[1]!);
    return number != null && number.isFinite ? number : null;
  }

  static List<double>? _viewBox(xml.XmlElement element) {
    final value = element.getAttribute('viewBox');
    if (value == null) return null;
    final values = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .toList();
    if (values.length != 4 ||
        values.any((value) => value == null || !value.isFinite))
      return null;
    final numbers = values.cast<double>();
    return numbers[2] > 0 && numbers[3] > 0 ? numbers : null;
  }

  static void _applyTypography(
    xml.XmlElement element,
    EpubStyle style,
    EpubStyle? parent,
  ) {
    if (const {'style', 'title', 'desc'}.contains(element.name.local)) return;
    final text = style.textStyle;
    final inherited = parent?.textStyle;
    final declarations = <String>[];
    final family = text.fontFamily;
    if (family != null && family.isNotEmpty) {
      final escaped = family
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', ' ');
      declarations.add("font-family:'$escaped' !important");
    }
    if (inherited != null) {
      if (text.fontSize != null && text.fontSize != inherited.fontSize) {
        declarations.add('font-size:${text.fontSize}px !important');
      }
      if (text.fontWeight != null && text.fontWeight != inherited.fontWeight) {
        declarations.add('font-weight:${text.fontWeight!.value} !important');
      }
      if (text.fontStyle != null && text.fontStyle != inherited.fontStyle) {
        declarations.add(
          'font-style:${text.fontStyle == FontStyle.italic ? 'italic' : 'normal'} !important',
        );
      }
    }
    if (declarations.isEmpty) return;
    // Inline important declarations keep the reader's font choice even when
    // the SVG carries descendant author font-family rules of its own.
    final existing = element.getAttribute('style') ?? '';
    _setAttribute(element, 'style', '$existing;${declarations.join(';')}');
  }

  static String _mimeType(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47)
      return 'image/png';
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46)
      return 'image/gif';
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50)
      return 'image/webp';
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d)
      return 'image/bmp';
    return 'image/jpeg';
  }

  static void _setAttribute(xml.XmlElement element, String name, String value) {
    final existing = element.attributes
        .where((attribute) => attribute.name.qualified == name)
        .firstOrNull;
    if (existing != null) {
      existing.value = value;
    } else {
      element.attributes.add(
        xml.XmlAttribute(xml.XmlName.fromString(name), value),
      );
    }
  }

  static dom.Element _domFromXml(xml.XmlElement node) {
    final element = dom.Element.tag(node.name.local);
    for (final attribute in node.attributes) {
      element.attributes[attribute.name.qualified] = attribute.value;
    }
    for (final child in node.children) {
      if (child is xml.XmlElement) {
        element.append(_domFromXml(child));
      } else if (child is xml.XmlText || child is xml.XmlCDATA) {
        element.append(dom.Text(child.value ?? ''));
      }
    }
    return element;
  }

  static xml.XmlElement _xmlFromDom(dom.Element element) => xml.XmlElement(
    xml.XmlName.fromString(element.localName!),
    element.attributes.entries.map(
      (entry) => xml.XmlAttribute(
        xml.XmlName.fromString(entry.key.toString()),
        entry.value,
      ),
    ),
    element.nodes
        .where((node) => node is dom.Element || node is dom.Text)
        .map(
          (node) => node is dom.Element
              ? _xmlFromDom(node)
              : xml.XmlText((node as dom.Text).data),
        ),
  );
}

class _MissingImage implements Exception {
  const _MissingImage();
}
