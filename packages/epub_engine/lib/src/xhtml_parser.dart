import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

/// Sealed class representing a content element parsed from XHTML.
sealed class ContentElement {
  final int charStart;
  final int charEnd;

  ContentElement({required this.charStart, required this.charEnd});
}

/// A block of text with inline styling.
class TextBlock extends ContentElement {
  final InlineSpan span;
  final TextBlockType type;
  final int? listIndex;

  TextBlock({
    required this.span,
    required this.type,
    this.listIndex,
    required super.charStart,
    required super.charEnd,
  });
}

/// Types of text blocks.
enum TextBlockType {
  paragraph,
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  blockquote,
  listItem,
  code,
  pre,
}

/// An image block.
class ImageBlock extends ContentElement {
  final Uint8List bytes;
  final String? alt;

  ImageBlock({
    required this.bytes,
    this.alt,
    required super.charStart,
    required super.charEnd,
  });
}

/// A horizontal divider.
class DividerBlock extends ContentElement {
  DividerBlock({required super.charStart, required super.charEnd});
}

/// A range of text that should be highlighted.
class HighlightRange {
  final int startOffset;
  final int endOffset;
  final String color; // hex color like '#BB86FC'

  HighlightRange({
    required this.startOffset,
    required this.endOffset,
    required this.color,
  });
}

/// Parses XHTML into a list of ContentElement objects.
class XhtmlParser {
  final String html;
  final Map<String, Uint8List> images;
  final List<HighlightRange> highlights;
  final TextStyle baseStyle;
  final double lineHeight;

  int _charOffset = 0;

  XhtmlParser({
    required this.html,
    required this.images,
    this.highlights = const [],
    required this.baseStyle,
    this.lineHeight = 1.5,
  });

  /// Parse the XHTML and return a list of ContentElement.
  List<ContentElement> parse() {
    _charOffset = 0;

    final xmlElements = _parseXmlDocument();
    if (xmlElements != null && xmlElements.isNotEmpty) {
      return xmlElements;
    }

    _charOffset = 0;
    final document = html_parser.parse(html);
    final body = document.body;
    if (body == null) return [];

    final elements = <ContentElement>[];
    _parseNode(body, elements, currentStyle: baseStyle);
    return elements;
  }

  List<ContentElement>? _parseXmlDocument() {
    try {
      final document = xml.XmlDocument.parse(html);
      final body = _firstXmlDescendantByLocalName(document, 'body');
      if (body == null) return null;

      final elements = <ContentElement>[];
      _parseXmlNode(body, elements, currentStyle: baseStyle);
      return elements;
    } catch (_) {
      return null;
    }
  }

  void _parseXmlNode(
    xml.XmlNode node,
    List<ContentElement> elements, {
    required TextStyle currentStyle,
  }) {
    if (node is xml.XmlText || node is xml.XmlCDATA) {
      final text = node.value ?? '';
      if (text.trim().isEmpty) return;
      _charOffset += text.length;
      return;
    }

    if (node is! xml.XmlElement) return;

    final tag = node.name.local.toLowerCase();
    final effectiveStyle = _resolveXmlElementStyle(node, currentStyle);

    switch (tag) {
      case 'p':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.paragraph,
          style: effectiveStyle,
        );
        break;
      case 'h1':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.h1,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 2.0,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h2':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.h2,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 1.5,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h3':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.h3,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 1.25,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h4':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.h4,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 1.1,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h5':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.h5,
          style: effectiveStyle.copyWith(
            fontSize: effectiveStyle.fontSize,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h6':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.h6,
          style: effectiveStyle.copyWith(
            fontSize: effectiveStyle.fontSize,
            fontWeight: FontWeight.bold,
            color: effectiveStyle.color?.withAlpha(180),
          ),
        );
        break;
      case 'blockquote':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.blockquote,
          style: effectiveStyle.copyWith(fontStyle: FontStyle.italic),
        );
        break;
      case 'pre':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.pre,
          style: effectiveStyle.copyWith(fontFamily: 'monospace'),
        );
        break;
      case 'code':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.code,
          style: effectiveStyle.copyWith(fontFamily: 'monospace'),
        );
        break;
      case 'ul':
        int idx = 0;
        for (final child in node.childElements) {
          if (child.name.local.toLowerCase() == 'li') {
            _parseXmlTextBlock(
              child,
              elements,
              type: TextBlockType.listItem,
              style: effectiveStyle,
              listIndex: idx,
            );
            idx++;
          } else {
            _parseXmlNode(child, elements, currentStyle: effectiveStyle);
          }
        }
        break;
      case 'ol':
        int idx = 1;
        for (final child in node.childElements) {
          if (child.name.local.toLowerCase() == 'li') {
            _parseXmlTextBlock(
              child,
              elements,
              type: TextBlockType.listItem,
              style: effectiveStyle,
              listIndex: idx,
            );
            idx++;
          } else {
            _parseXmlNode(child, elements, currentStyle: effectiveStyle);
          }
        }
        break;
      case 'li':
        _parseXmlTextBlock(
          node,
          elements,
          type: TextBlockType.listItem,
          style: effectiveStyle,
        );
        break;
      case 'hr':
        final start = _charOffset;
        _charOffset += 1;
        elements.add(DividerBlock(charStart: start, charEnd: _charOffset));
        break;
      case 'img':
        _parseXmlImage(node, elements);
        break;
      case 'br':
        _charOffset += 1;
        break;
      case 'span':
      case 'body':
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'header':
      case 'footer':
      case 'figure':
      case 'figcaption':
        if (_shouldPromoteXmlContainerToParagraph(node)) {
          _parseXmlTextBlock(
            node,
            elements,
            type: TextBlockType.paragraph,
            style: effectiveStyle,
          );
        } else {
          for (final child in node.children) {
            _parseXmlNode(child, elements, currentStyle: effectiveStyle);
          }
        }
        break;
      case 'head':
      case 'script':
      case 'style':
      case 'meta':
      case 'link':
        break;
      default:
        if (_shouldPromoteXmlContainerToParagraph(node)) {
          _parseXmlTextBlock(
            node,
            elements,
            type: TextBlockType.paragraph,
            style: effectiveStyle,
          );
        } else {
          for (final child in node.children) {
            _parseXmlNode(child, elements, currentStyle: effectiveStyle);
          }
        }
    }
  }

  void _parseNode(
    dom.Node node,
    List<ContentElement> elements, {
    required TextStyle currentStyle,
  }) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.trim().isEmpty) return;
      _charOffset += text.length;
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    final effectiveStyle = _resolveElementStyle(node, currentStyle);

    switch (tag) {
      case 'p':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.paragraph,
          style: effectiveStyle,
        );
        break;
      case 'h1':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.h1,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 2.0,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h2':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.h2,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 1.5,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h3':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.h3,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 1.25,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h4':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.h4,
          style: effectiveStyle.copyWith(
            fontSize: (effectiveStyle.fontSize ?? 16) * 1.1,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h5':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.h5,
          style: effectiveStyle.copyWith(
            fontSize: effectiveStyle.fontSize,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case 'h6':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.h6,
          style: effectiveStyle.copyWith(
            fontSize: effectiveStyle.fontSize,
            fontWeight: FontWeight.bold,
            color: effectiveStyle.color?.withAlpha(180),
          ),
        );
        break;
      case 'blockquote':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.blockquote,
          style: effectiveStyle.copyWith(fontStyle: FontStyle.italic),
        );
        break;
      case 'pre':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.pre,
          style: effectiveStyle.copyWith(fontFamily: 'monospace'),
        );
        break;
      case 'code':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.code,
          style: effectiveStyle.copyWith(fontFamily: 'monospace'),
        );
        break;
      case 'ul':
        int idx = 0;
        for (final child in node.children) {
          if (child.localName?.toLowerCase() == 'li') {
            _parseTextBlock(
              child,
              elements,
              type: TextBlockType.listItem,
              style: effectiveStyle,
              listIndex: idx,
            );
            idx++;
          } else {
            _parseNode(child, elements, currentStyle: effectiveStyle);
          }
        }
        break;
      case 'ol':
        int idx = 1;
        for (final child in node.children) {
          if (child.localName?.toLowerCase() == 'li') {
            _parseTextBlock(
              child,
              elements,
              type: TextBlockType.listItem,
              style: effectiveStyle,
              listIndex: idx,
            );
            idx++;
          } else {
            _parseNode(child, elements, currentStyle: effectiveStyle);
          }
        }
        break;
      case 'li':
        _parseTextBlock(
          node,
          elements,
          type: TextBlockType.listItem,
          style: effectiveStyle,
        );
        break;
      case 'hr':
        final start = _charOffset;
        _charOffset += 1;
        elements.add(DividerBlock(charStart: start, charEnd: _charOffset));
        break;
      case 'img':
        _parseImage(node, elements);
        break;
      case 'br':
        _charOffset += 1;
        break;
      case 'span':
      case 'body':
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'header':
      case 'footer':
      case 'figure':
      case 'figcaption':
        if (_shouldPromoteContainerToParagraph(node)) {
          _parseTextBlock(
            node,
            elements,
            type: TextBlockType.paragraph,
            style: effectiveStyle,
          );
        } else {
          for (final child in node.nodes) {
            _parseNode(child, elements, currentStyle: effectiveStyle);
          }
        }
        break;
      case 'head':
      case 'script':
      case 'style':
      case 'meta':
      case 'link':
        // Skip these
        break;
      default:
        if (_shouldPromoteContainerToParagraph(node)) {
          _parseTextBlock(
            node,
            elements,
            type: TextBlockType.paragraph,
            style: effectiveStyle,
          );
        } else {
          for (final child in node.nodes) {
            _parseNode(child, elements, currentStyle: effectiveStyle);
          }
        }
    }
  }

  bool _hasTextContent(dom.Node node) {
    if (node is dom.Text) return node.text.trim().isNotEmpty;
    if (node is! dom.Element) return false;
    for (final child in node.nodes) {
      if (_hasTextContent(child)) return true;
    }
    return false;
  }

  bool _hasXmlTextContent(xml.XmlNode node) {
    if (node is xml.XmlText || node is xml.XmlCDATA) {
      return (node.value ?? '').trim().isNotEmpty;
    }
    if (node is! xml.XmlElement) return false;
    for (final child in node.children) {
      if (_hasXmlTextContent(child)) return true;
    }
    return false;
  }

  bool _shouldPromoteContainerToParagraph(dom.Element element) {
    if (!_hasTextContent(element)) return false;
    return !_containsBlockDescendant(element);
  }

  bool _shouldPromoteXmlContainerToParagraph(xml.XmlElement element) {
    if (!_hasXmlTextContent(element)) return false;
    return !_containsXmlBlockDescendant(element);
  }

  bool _containsBlockDescendant(dom.Element element) {
    for (final child in element.children) {
      final tag = child.localName?.toLowerCase() ?? '';
      if (_isBlockLikeTag(tag)) {
        return true;
      }
      if (_containsBlockDescendant(child)) {
        return true;
      }
    }
    return false;
  }

  bool _containsXmlBlockDescendant(xml.XmlElement element) {
    for (final child in element.childElements) {
      final tag = child.name.local.toLowerCase();
      if (_isBlockLikeTag(tag)) {
        return true;
      }
      if (_containsXmlBlockDescendant(child)) {
        return true;
      }
    }
    return false;
  }

  bool _isBlockLikeTag(String tag) {
    switch (tag) {
      case 'p':
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'header':
      case 'footer':
      case 'figure':
      case 'figcaption':
      case 'blockquote':
      case 'pre':
      case 'ul':
      case 'ol':
      case 'li':
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'table':
      case 'thead':
      case 'tbody':
      case 'tfoot':
      case 'tr':
      case 'td':
      case 'th':
      case 'dl':
      case 'dt':
      case 'dd':
      case 'hr':
      case 'img':
        return true;
      default:
        return false;
    }
  }

  void _parseTextBlock(
    dom.Element element,
    List<ContentElement> elements, {
    required TextBlockType type,
    required TextStyle style,
    int? listIndex,
  }) {
    final startOffset = _charOffset;
    final spans = <InlineSpan>[];

    // Add list marker if needed
    if (listIndex != null) {
      final marker = type == TextBlockType.listItem && listIndex > 0
          ? '$listIndex. '
          : '• ';
      spans.add(TextSpan(text: marker, style: style));
      _charOffset += marker.length;
    }

    _buildSpans(element, spans, style);

    final endOffset = _charOffset;
    if (spans.isEmpty) return;

    // Apply highlights to the combined span
    final combinedSpan = spans.length == 1
        ? spans.first
        : TextSpan(children: spans);
    final highlightedSpan = _applyHighlightsToSpan(
      combinedSpan,
      startOffset,
      endOffset,
    );

    elements.add(
      TextBlock(
        span: highlightedSpan,
        type: type,
        listIndex: listIndex,
        charStart: startOffset,
        charEnd: endOffset,
      ),
    );
  }

  void _parseXmlTextBlock(
    xml.XmlElement element,
    List<ContentElement> elements, {
    required TextBlockType type,
    required TextStyle style,
    int? listIndex,
  }) {
    final startOffset = _charOffset;
    final spans = <InlineSpan>[];

    if (listIndex != null) {
      final marker = type == TextBlockType.listItem && listIndex > 0
          ? '$listIndex. '
          : '• ';
      spans.add(TextSpan(text: marker, style: style));
      _charOffset += marker.length;
    }

    _buildXmlSpans(element, spans, style);

    final endOffset = _charOffset;
    if (spans.isEmpty) return;

    final combinedSpan = spans.length == 1
        ? spans.first
        : TextSpan(children: spans);
    final highlightedSpan = _applyHighlightsToSpan(
      combinedSpan,
      startOffset,
      endOffset,
    );

    elements.add(
      TextBlock(
        span: highlightedSpan,
        type: type,
        listIndex: listIndex,
        charStart: startOffset,
        charEnd: endOffset,
      ),
    );
  }

  void _buildSpans(
    dom.Node node,
    List<InlineSpan> spans,
    TextStyle parentStyle,
  ) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return;
      _charOffset += text.length;
      spans.add(TextSpan(text: text, style: parentStyle));
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'br') {
      _charOffset += 1;
      spans.add(TextSpan(text: '\n', style: parentStyle));
      return;
    }

    if (tag == 'img') return;

    final style = _resolveElementStyle(node, parentStyle);

    for (final child in node.nodes) {
      _buildSpans(child, spans, style);
    }
  }

  void _buildXmlSpans(
    xml.XmlNode node,
    List<InlineSpan> spans,
    TextStyle parentStyle,
  ) {
    if (node is xml.XmlText || node is xml.XmlCDATA) {
      final text = node.value ?? '';
      if (text.isEmpty) return;
      _charOffset += text.length;
      spans.add(TextSpan(text: text, style: parentStyle));
      return;
    }

    if (node is! xml.XmlElement) return;

    final tag = node.name.local.toLowerCase();
    if (tag == 'br') {
      _charOffset += 1;
      spans.add(TextSpan(text: '\n', style: parentStyle));
      return;
    }

    if (tag == 'img') return;

    final style = _resolveXmlElementStyle(node, parentStyle);
    for (final child in node.children) {
      _buildXmlSpans(child, spans, style);
    }
  }

  TextStyle _resolveElementStyle(dom.Element node, TextStyle parentStyle) {
    final tag = node.localName?.toLowerCase() ?? '';
    var style = parentStyle;

    switch (tag) {
      case 'b':
      case 'strong':
        style = style.copyWith(fontWeight: FontWeight.bold);
        break;
      case 'i':
      case 'em':
        style = style.copyWith(fontStyle: FontStyle.italic);
        break;
      case 'u':
        style = style.copyWith(decoration: TextDecoration.underline);
        break;
      case 's':
      case 'strike':
      case 'del':
        style = style.copyWith(decoration: TextDecoration.lineThrough);
        break;
      case 'sup':
        style = style.copyWith(
          fontSize: (style.fontSize ?? 16) * 0.75,
          fontFeatures: [const FontFeature.superscripts()],
        );
        break;
      case 'sub':
        style = style.copyWith(
          fontSize: (style.fontSize ?? 16) * 0.75,
          fontFeatures: [const FontFeature.subscripts()],
        );
        break;
      case 'small':
        style = style.copyWith(fontSize: (style.fontSize ?? 16) * 0.85);
        break;
      case 'big':
        style = style.copyWith(fontSize: (style.fontSize ?? 16) * 1.2);
        break;
      case 'a':
        final href = node.attributes['href'] ?? '';
        if (href.isNotEmpty) {
          style = style.copyWith(
            color: style.color?.withAlpha(200),
            decoration: TextDecoration.underline,
          );
        }
        break;
      case 'font':
        final color = node.attributes['color'];
        final size = node.attributes['size'];
        if (color != null) {
          style = style.copyWith(color: _parseColor(color));
        }
        if (size != null) {
          final multiplier = double.tryParse(size) ?? 1.0;
          style = style.copyWith(
            fontSize: (style.fontSize ?? 16) * multiplier / 3.0,
          );
        }
        break;
    }

    final inlineStyle = node.attributes['style'] ?? '';
    if (inlineStyle.trim().isNotEmpty) {
      style = _parseInlineStyle(inlineStyle, style);
    }

    return style;
  }

  TextStyle _resolveXmlElementStyle(
    xml.XmlElement node,
    TextStyle parentStyle,
  ) {
    final tag = node.name.local.toLowerCase();
    var style = parentStyle;

    switch (tag) {
      case 'b':
      case 'strong':
        style = style.copyWith(fontWeight: FontWeight.bold);
        break;
      case 'i':
      case 'em':
        style = style.copyWith(fontStyle: FontStyle.italic);
        break;
      case 'u':
        style = style.copyWith(decoration: TextDecoration.underline);
        break;
      case 's':
      case 'strike':
      case 'del':
        style = style.copyWith(decoration: TextDecoration.lineThrough);
        break;
      case 'sup':
        style = style.copyWith(
          fontSize: (style.fontSize ?? 16) * 0.75,
          fontFeatures: [const FontFeature.superscripts()],
        );
        break;
      case 'sub':
        style = style.copyWith(
          fontSize: (style.fontSize ?? 16) * 0.75,
          fontFeatures: [const FontFeature.subscripts()],
        );
        break;
      case 'small':
        style = style.copyWith(fontSize: (style.fontSize ?? 16) * 0.85);
        break;
      case 'big':
        style = style.copyWith(fontSize: (style.fontSize ?? 16) * 1.2);
        break;
      case 'a':
        final href = _xmlAttribute(node, 'href') ?? '';
        if (href.isNotEmpty) {
          style = style.copyWith(
            color: style.color?.withAlpha(200),
            decoration: TextDecoration.underline,
          );
        }
        break;
      case 'font':
        final color = _xmlAttribute(node, 'color');
        final size = _xmlAttribute(node, 'size');
        if (color != null) {
          style = style.copyWith(color: _parseColor(color));
        }
        if (size != null) {
          final multiplier = double.tryParse(size) ?? 1.0;
          style = style.copyWith(
            fontSize: (style.fontSize ?? 16) * multiplier / 3.0,
          );
        }
        break;
    }

    final inlineStyle = _xmlAttribute(node, 'style') ?? '';
    if (inlineStyle.trim().isNotEmpty) {
      style = _parseInlineStyle(inlineStyle, style);
    }

    return style;
  }

  TextStyle _parseInlineStyle(String cssStyle, TextStyle base) {
    var style = base;
    final declarations = cssStyle.split(';');
    for (final decl in declarations) {
      final parts = decl.split(':');
      if (parts.length != 2) continue;
      final prop = parts[0].trim().toLowerCase();
      final value = parts[1].trim();

      switch (prop) {
        case 'color':
          style = style.copyWith(color: _parseColor(value));
          break;
        case 'font-size':
          final size = _parseCssSize(value, base.fontSize ?? 16);
          style = style.copyWith(fontSize: size);
          break;
        case 'font-weight':
          if (value == 'bold' || value == '700' || value == '600') {
            style = style.copyWith(fontWeight: FontWeight.bold);
          }
          break;
        case 'font-style':
          if (value == 'italic') {
            style = style.copyWith(fontStyle: FontStyle.italic);
          }
          break;
        case 'text-decoration':
          if (value.contains('underline')) {
            style = style.copyWith(decoration: TextDecoration.underline);
          }
          if (value.contains('line-through')) {
            style = style.copyWith(decoration: TextDecoration.lineThrough);
          }
          break;
      }
    }
    return style;
  }

  double _parseCssSize(String value, double baseSize) {
    // Handle px, em, rem, %, pt
    if (value.endsWith('px')) {
      return double.tryParse(value.substring(0, value.length - 2)) ?? baseSize;
    } else if (value.endsWith('em')) {
      final mult = double.tryParse(value.substring(0, value.length - 2)) ?? 1.0;
      return baseSize * mult;
    } else if (value.endsWith('rem')) {
      final mult = double.tryParse(value.substring(0, value.length - 3)) ?? 1.0;
      return baseSize * mult;
    } else if (value.endsWith('pt')) {
      final pt = double.tryParse(value.substring(0, value.length - 2)) ?? 12.0;
      return pt * 1.333; // pt to px
    } else if (value.endsWith('%')) {
      final pct =
          double.tryParse(value.substring(0, value.length - 1)) ?? 100.0;
      return baseSize * pct / 100.0;
    }
    return double.tryParse(value) ?? baseSize;
  }

  Color? _parseColor(String value) {
    value = value.trim();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 3) {
        final expanded = hex.split('').map((c) => c + c).join();
        return Color(int.parse('FF$expanded', radix: 16));
      }
    } else if (value.startsWith('rgb')) {
      final match = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(value);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        return Color.fromARGB(255, r, g, b);
      }
    }
    // Named colors
    const namedColors = {
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'yellow': 0xFFFFFF00,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'silver': 0xFFC0C0C0,
      'maroon': 0xFF800000,
      'olive': 0xFF808000,
      'lime': 0xFF00FF00,
      'aqua': 0xFF00FFFF,
      'teal': 0xFF008080,
      'navy': 0xFF000080,
      'fuchsia': 0xFFFF00FF,
      'purple': 0xFF800080,
    };
    final named = namedColors[value.toLowerCase()];
    if (named != null) return Color(named);
    return null;
  }

  void _parseImage(dom.Element element, List<ContentElement> elements) {
    final src =
        element.attributes['src'] ?? element.attributes['data-src'] ?? '';
    final alt = element.attributes['alt'];
    if (src.isEmpty) return;

    // Find image in images map
    final filename = src.split('/').last;
    Uint8List? imgBytes;
    for (final entry in images.entries) {
      if (entry.key.endsWith(filename)) {
        imgBytes = entry.value;
        break;
      }
    }

    if (imgBytes == null) return;

    final start = _charOffset;
    _charOffset += 1; // Count image as 1 char for offset tracking
    elements.add(
      ImageBlock(
        bytes: imgBytes,
        alt: alt,
        charStart: start,
        charEnd: _charOffset,
      ),
    );
  }

  void _parseXmlImage(xml.XmlElement element, List<ContentElement> elements) {
    final src =
        _xmlAttribute(element, 'src') ??
        _xmlAttribute(element, 'data-src') ??
        '';
    final alt = _xmlAttribute(element, 'alt');
    if (src.isEmpty) return;

    final filename = src.split('/').last;
    Uint8List? imgBytes;
    for (final entry in images.entries) {
      if (entry.key.endsWith(filename)) {
        imgBytes = entry.value;
        break;
      }
    }

    if (imgBytes == null) return;

    final start = _charOffset;
    _charOffset += 1;
    elements.add(
      ImageBlock(
        bytes: imgBytes,
        alt: alt,
        charStart: start,
        charEnd: _charOffset,
      ),
    );
  }

  xml.XmlElement? _firstXmlDescendantByLocalName(
    xml.XmlNode root,
    String name,
  ) {
    final normalized = name.toLowerCase();
    for (final node in root.descendants.whereType<xml.XmlElement>()) {
      if (node.name.local.toLowerCase() == normalized) {
        return node;
      }
    }
    return null;
  }

  String? _xmlAttribute(xml.XmlElement element, String attributeName) {
    final normalized = attributeName.toLowerCase();
    for (final attribute in element.attributes) {
      final local = attribute.name.local.toLowerCase();
      final qualified = attribute.name.qualified.toLowerCase();
      if (local == normalized || qualified == normalized) {
        return attribute.value;
      }
    }
    return null;
  }

  /// Apply highlights to a span tree based on character offsets.
  InlineSpan _applyHighlightsToSpan(
    InlineSpan span,
    int blockStart,
    int blockEnd,
  ) {
    // Find highlights that overlap with this block
    final relevant = highlights
        .where((h) => h.startOffset < blockEnd && h.endOffset > blockStart)
        .toList();

    if (relevant.isEmpty) return span;

    // For simplicity, we apply highlights by wrapping the span.
    // A more sophisticated approach would split spans at highlight boundaries.
    // For now, we check if the span is a TextSpan and apply the first matching highlight.
    if (span is! TextSpan) return span;

    // Calculate the offset of this span relative to the block start
    final spanText = span.text ?? '';
    if (spanText.isEmpty && span.children == null) return span;

    // If the span has children, recursively apply highlights
    if (span.children != null && span.children!.isNotEmpty) {
      final newChildren = <InlineSpan>[];
      var childOffset = blockStart;
      for (final child in span.children!) {
        final childSpan = _applyHighlightsToSpan(
          child,
          childOffset,
          childOffset + (child is TextSpan ? (child.text?.length ?? 0) : 0),
        );
        newChildren.add(childSpan);
        childOffset += child is TextSpan ? (child.text?.length ?? 0) : 0;
      }
      return TextSpan(
        style: span.style,
        recognizer: span.recognizer,
        children: newChildren,
      );
    }

    // Leaf span — check if it should be highlighted
    final text = span.text ?? '';
    if (text.isEmpty) return span;

    // Find the highlight that covers this span's text
    final highlight = relevant.firstWhere(
      (h) => h.startOffset <= blockStart && h.endOffset >= blockEnd,
      orElse: () => relevant.firstWhere(
        (h) => h.startOffset < blockEnd && h.endOffset > blockStart,
        orElse: () => relevant.first,
      ),
    );

    final bgColor = _parseColor(highlight.color)?.withAlpha(90); // 35% opacity
    if (bgColor == null) return span;

    return TextSpan(
      text: text,
      style:
          span.style?.copyWith(backgroundColor: bgColor) ??
          TextStyle(backgroundColor: bgColor),
      recognizer: span.recognizer,
    );
  }
}
