import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

import 'epub_images.dart';
import 'epub_styles.dart';

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
  final double indent;
  final TextAlign textAlign;
  final EdgeInsets? margin;
  final bool isContinuation;
  final List<int>? hyphenationOffsets;
  final bool trailingHyphen;
  final bool continuesOnNextPage;

  TextBlock({
    required this.span,
    required this.type,
    this.listIndex,
    this.indent = 0,
    this.textAlign = TextAlign.start,
    this.margin,
    this.isContinuation = false,
    this.hyphenationOffsets,
    this.trailingHyphen = false,
    this.continuesOnNextPage = false,
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
  tableHeader,
}

/// An image block.
class ImageBlock extends ContentElement {
  final Uint8List bytes;
  final String? alt;
  final double indent;
  final bool isSvg;
  final double? aspectRatio;

  ImageBlock({
    required this.bytes,
    this.alt,
    this.indent = 0,
    this.isSvg = false,
    this.aspectRatio,
    required super.charStart,
    required super.charEnd,
  });
}

/// A horizontal divider.
class DividerBlock extends ContentElement {
  DividerBlock({required super.charStart, required super.charEnd});
}

/// Cells retain their reading-order offsets independently of their grid position.
class TableCellContent {
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
  final List<ContentElement> elements;

  const TableCellContent({
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.columnSpan = 1,
    required this.elements,
  });
}

class TableBlock extends ContentElement {
  final int rowCount;
  final int columnCount;
  final List<TableCellContent> cells;
  final double indent;

  TableBlock({
    required this.rowCount,
    required this.columnCount,
    required this.cells,
    this.indent = 0,
    required super.charStart,
    required super.charEnd,
  });
}

/// Rendered paragraph order, including table cells, is also selection order.
Iterable<ContentElement> contentLeaves(
  Iterable<ContentElement> elements,
) sync* {
  for (final element in elements) {
    if (element is TableBlock) {
      for (final cell in element.cells) {
        yield* contentLeaves(cell.elements);
      }
    } else {
      yield element;
    }
  }
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

/// A link range in the same chapter character space as [ContentElement].
class ContentLink {
  final int startOffset;
  final int endOffset;
  final String href;

  const ContentLink(this.startOffset, this.endOffset, this.href);
}

/// Parses XHTML into a list of ContentElement objects.
class XhtmlParser {
  final String html;
  final Map<String, Uint8List> images;
  final String documentPath;
  final Map<String, String> stylesheets;
  final List<HighlightRange> highlights;
  final TextStyle baseStyle;
  final double lineHeight;
  final String? language;
  final Map<String, int> anchors = {};
  final List<ContentLink> links = [];
  int _charOffset = 0;
  late EpubStyleResolver _styles;
  late EpubImageResolver _images;

  XhtmlParser({
    required this.html,
    required this.images,
    this.documentPath = '',
    this.stylesheets = const {},
    this.highlights = const [],
    required this.baseStyle,
    this.language,
    this.lineHeight = 1.5,
  });

  List<ContentElement> parse() {
    _charOffset = 0;
    anchors.clear();
    links.clear();
    final document = _readDocument();
    final body = document.querySelector('body');
    if (body == null) return [];
    final languageCode = language
        ?.trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .split('-')
        .first;
    _styles = EpubStyleResolver(
      document: document,
      documentPath: documentPath,
      stylesheets: stylesheets,
      baseStyle: baseStyle.copyWith(
        height: baseStyle.height ?? lineHeight,
        locale: languageCode == null
            ? baseStyle.locale
            : Locale(languageCode.isEmpty ? 'und' : languageCode),
      ),
    );
    _images = EpubImageResolver(
      images: images,
      stylesheets: stylesheets,
      baseStyle: baseStyle,
    );
    var inherited = _styles.root;
    final ancestors = <dom.Element>[];
    for (var node = body.parent; node is dom.Element; node = node.parent) {
      ancestors.add(node);
    }
    for (final ancestor in ancestors.reversed) {
      inherited = _resolveStyle(ancestor, inherited);
    }
    final style = _resolveStyle(body, inherited);
    if (style.hidden) return [];
    _recordAnchor(body);
    final elements = <ContentElement>[];
    _flow(body.nodes, elements, style);
    return elements;
  }

  // An XML <title/> must not consume the body as it would in an HTML parser.
  // Both input formats share one traversal after this lossless conversion.
  dom.Document _readDocument() {
    late final xml.XmlDocument source;
    try {
      source = xml.XmlDocument.parse(html);
    } on xml.XmlParserException {
      return _readHtml();
    } on xml.XmlTagException {
      return _readHtml();
    }
    if (!source.descendants.whereType<xml.XmlElement>().any(
      (element) => element.name.local.toLowerCase() == 'body',
    )) {
      return _readHtml();
    }
    final document = dom.Document();
    for (final node in source.children) {
      final converted = _fromXml(node);
      if (converted != null) document.append(converted);
    }
    return document;
  }

  dom.Document _readHtml() {
    final document = html_parser.parse(html);
    for (final element in document.querySelectorAll('*')) {
      if (element.attributes.keys.every((key) => key is String)) continue;
      final namespaced = element.attributes.entries
          .where((entry) => entry.key is! String)
          .toList();
      for (final entry in namespaced) {
        element.attributes.remove(entry.key);
        element.attributes[entry.key.toString()] = entry.value;
      }
    }
    return document;
  }

  dom.Node? _fromXml(xml.XmlNode node, {bool inSvg = false}) {
    if (node is xml.XmlText || node is xml.XmlCDATA) {
      return dom.Text(node.value ?? '');
    }
    if (node is! xml.XmlElement) return null;
    final svg = inSvg || node.name.local.toLowerCase() == 'svg';
    final element = dom.Element.tag(
      svg ? node.name.local : node.name.local.toLowerCase(),
    );
    for (final attribute in node.attributes) {
      element.attributes[attribute.name.qualified] = attribute.value;
    }
    for (final child in node.children) {
      final converted = _fromXml(child, inSvg: svg);
      if (converted != null) element.append(converted);
    }
    return element;
  }

  bool _heading(String tag) =>
      tag.length == 2 &&
      tag[0] == 'h' &&
      tag.codeUnitAt(1) >= 49 &&
      tag.codeUnitAt(1) <= 54;

  EpubStyle _resolveStyle(dom.Element element, EpubStyle parent) {
    var text = parent.textStyle;
    final tag = element.localName ?? '';
    if (_heading(tag)) {
      const scales = [2.0, 1.5, 1.25, 1.1, 1.0, 1.0];
      text = text.copyWith(
        fontSize: (text.fontSize ?? 16) * scales[int.parse(tag[1]) - 1],
        fontWeight: FontWeight.bold,
      );
    } else {
      switch (tag) {
        case 'b':
        case 'strong':
        case 'th':
          text = text.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'i':
        case 'em':
        case 'blockquote':
          text = text.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'u':
          text = text.copyWith(decoration: TextDecoration.underline);
          break;
        case 's':
        case 'strike':
        case 'del':
          text = text.copyWith(decoration: TextDecoration.lineThrough);
          break;
        case 'sup':
        case 'sub':
          text = text.copyWith(
            fontSize: (text.fontSize ?? 16) * 0.75,
            fontFeatures: [
              tag == 'sup'
                  ? const FontFeature.superscripts()
                  : const FontFeature.subscripts(),
            ],
          );
          break;
        case 'small':
          text = text.copyWith(fontSize: (text.fontSize ?? 16) * 0.85);
          break;
        case 'big':
          text = text.copyWith(fontSize: (text.fontSize ?? 16) * 1.2);
          break;
        case 'a':
          if ((element.attributes['href'] ?? '').isNotEmpty) {
            text = text.copyWith(
              color: text.color?.withAlpha(200),
              decoration: TextDecoration.underline,
            );
          }
          break;
        case 'code':
        case 'pre':
          text = text.copyWith(fontFamily: 'monospace');
          break;
      }
    }
    return _styles.resolve(element, parent, defaultTextStyle: text);
  }

  void _recordAnchor(dom.Element element) {
    final id = element.attributes['id'];
    final name = element.attributes['name'];
    if (id != null && id.isNotEmpty) anchors.putIfAbsent(id, () => _charOffset);
    if (name != null && name.isNotEmpty) {
      anchors.putIfAbsent(name, () => _charOffset);
    }
  }

  void _flow(
    Iterable<dom.Node> nodes,
    List<ContentElement> elements,
    EpubStyle style, {
    TextBlockType type = TextBlockType.paragraph,
    double indent = 0,
    _ListMarker? marker,
  }) {
    final run = _ParagraphRun(this, elements, style, type, indent, marker);
    for (final node in nodes) {
      _walk(node, elements, run, style, type, indent, marker);
    }
    run.flush();
  }

  static const _blockTags = {
    'p',
    'div',
    'section',
    'article',
    'main',
    'header',
    'footer',
    'figure',
    'figcaption',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'ul',
    'ol',
    'li',
    'dl',
    'dt',
    'dd',
    'table',
    'caption',
  };
  static const _ignoredTags = {
    'head',
    'script',
    'style',
    'meta',
    'link',
    'title',
    'source',
    'col',
    'colgroup',
  };

  void _walk(
    dom.Node node,
    List<ContentElement> elements,
    _ParagraphRun run,
    EpubStyle parent,
    TextBlockType type,
    double indent,
    _ListMarker? marker,
  ) {
    if (node is dom.Text) {
      run.add(node.text, parent.textStyle);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName ?? '';
    if (_ignoredTags.contains(tag)) return;
    final style = _resolveStyle(node, parent);
    if (style.hidden) return;
    _recordAnchor(node);
    final linkStart = _charOffset;
    if (tag == 'img' || tag == 'image' || tag == 'object') {
      run.flush(markerOnly: true);
      if (!_emitImage(node, elements, indent)) {
        if (tag == 'object') {
          _flow(
            node.nodes,
            elements,
            style,
            type: type,
            indent: indent,
            marker: marker,
          );
        } else {
          final alt = node.attributes['alt'];
          if (alt != null) run.add(alt, style.textStyle);
        }
      }
    } else if (tag == 'svg') {
      run.flush(markerOnly: true);
      _emitSvg(node, elements, indent, style);
    } else if (tag == 'br') {
      run.lineBreak(parent.textStyle);
    } else if (tag == 'hr') {
      run.flush(markerOnly: true);
      final start = _charOffset++;
      elements.add(DividerBlock(charStart: start, charEnd: _charOffset));
    } else if (tag == 'ul' || tag == 'ol') {
      run.flush(markerOnly: true);
      _list(node, elements, style, indent);
    } else if (tag == 'table') {
      run.flush(markerOnly: true);
      _table(node, elements, style, indent);
    } else if (style.display == 'block' ||
        (style.display != 'inline' && _blockTags.contains(tag))) {
      run.flush();
      var childType = type;
      if (tag == 'p' &&
          type != TextBlockType.blockquote &&
          type != TextBlockType.listItem &&
          type != TextBlockType.tableHeader) {
        childType = TextBlockType.paragraph;
      } else if (_heading(tag)) {
        childType = TextBlockType.values[int.parse(tag[1])];
      } else if (tag == 'blockquote') {
        childType = TextBlockType.blockquote;
      } else if (tag == 'pre') {
        childType = TextBlockType.pre;
      }
      _flow(
        node.nodes,
        elements,
        style,
        type: childType,
        indent: indent + (tag == 'blockquote' || tag == 'dd' ? 20 : 0),
        marker: marker,
      );
    } else {
      for (final child in node.nodes) {
        _walk(child, elements, run, style, type, indent, marker);
      }
    }
    final href = node.attributes['href'];
    if (tag == 'a' && href != null && href.isNotEmpty) {
      links.add(ContentLink(linkStart, _charOffset, href));
    }
  }

  void _list(
    dom.Element list,
    List<ContentElement> elements,
    EpubStyle style,
    double indent,
  ) {
    final ordered = list.localName == 'ol';
    final reversed = ordered && list.attributes.containsKey('reversed');
    final children = list.children.where((child) => child.localName == 'li');
    var index =
        int.tryParse(list.attributes['start'] ?? '') ??
        (reversed ? children.length : 1);
    for (final child in list.nodes) {
      if (child is! dom.Element || child.localName != 'li') {
        if (child is dom.Element)
          _flow([child], elements, style, indent: indent);
        continue;
      }
      final itemStyle = _resolveStyle(child, style);
      if (itemStyle.hidden) continue;
      _recordAnchor(child);
      if (ordered)
        index = int.tryParse(child.attributes['value'] ?? '') ?? index;
      final marker = _ListMarker(
        ordered ? '${_ordinal(index, list.attributes['type'])}. ' : '• ',
        ordered ? index : 0,
      );
      _flow(
        child.nodes,
        elements,
        itemStyle,
        type: TextBlockType.listItem,
        indent: indent + 20,
        marker: marker,
      );
      if (marker.pending) {
        _ParagraphRun(
          this,
          elements,
          itemStyle,
          TextBlockType.listItem,
          indent + 20,
          marker,
        ).flush(markerOnly: true);
      }
      index += reversed ? -1 : 1;
    }
  }

  String _ordinal(int value, String? type) {
    if (value <= 0) return '$value';
    if (type == 'a' || type == 'A') {
      var number = value;
      final letters = <int>[];
      while (number > 0) {
        number--;
        letters.add((type == 'a' ? 97 : 65) + number % 26);
        number ~/= 26;
      }
      return String.fromCharCodes(letters.reversed);
    }
    if ((type == 'i' || type == 'I') && value < 4000) {
      const numerals = {
        1000: 'M',
        900: 'CM',
        500: 'D',
        400: 'CD',
        100: 'C',
        90: 'XC',
        50: 'L',
        40: 'XL',
        10: 'X',
        9: 'IX',
        5: 'V',
        4: 'IV',
        1: 'I',
      };
      final result = StringBuffer();
      var number = value;
      for (final entry in numerals.entries) {
        while (number >= entry.key) {
          result.write(entry.value);
          number -= entry.key;
        }
      }
      return type == 'i' ? result.toString().toLowerCase() : result.toString();
    }
    return '$value';
  }

  bool _emitImage(
    dom.Element element,
    List<ContentElement> elements,
    double indent,
  ) {
    final image = _images.resolveElement(element, documentPath: documentPath);
    if (image == null) return false;
    _appendImage(image, elements, indent, alt: element.attributes['alt']);
    return true;
  }

  void _emitSvg(
    dom.Element element,
    List<ContentElement> elements,
    double indent,
    EpubStyle style,
  ) {
    _appendImage(
      _images.inlineSvg(
        element,
        styles: _styles,
        style: style,
        documentPath: documentPath,
      ),
      elements,
      indent,
    );
  }

  void _appendImage(
    EpubImage image,
    List<ContentElement> elements,
    double indent, {
    String? alt,
  }) {
    final start = _charOffset++;
    elements.add(
      ImageBlock(
        bytes: image.bytes,
        isSvg: image.isSvg,
        aspectRatio: image.aspectRatio,
        alt: alt,
        indent: indent,
        charStart: start,
        charEnd: _charOffset,
      ),
    );
  }

  void _table(
    dom.Element table,
    List<ContentElement> elements,
    EpubStyle style,
    double indent,
  ) {
    final rows = <(dom.Element, EpubStyle)>[];
    final groupEnds = <int>[];
    void gather(dom.Element parent, EpubStyle inherited) {
      var groupStart = rows.length;
      void closeGroup() {
        for (var row = groupStart; row < rows.length; row++) {
          groupEnds[row] = rows.length;
        }
        groupStart = rows.length;
      }

      for (final child in parent.children) {
        final childStyle = _resolveStyle(child, inherited);
        if (childStyle.hidden) continue;
        if (child.localName == 'tr') {
          rows.add((child, childStyle));
          groupEnds.add(0);
        } else if (const {
          'thead',
          'tbody',
          'tfoot',
        }.contains(child.localName)) {
          closeGroup();
          gather(child, childStyle);
          groupStart = rows.length;
        } else if (child.localName == 'caption') {
          _recordAnchor(child);
          _flow(child.nodes, elements, childStyle, indent: indent);
        }
      }
      closeGroup();
    }

    gather(table, style);
    if (rows.isEmpty) return;
    final start = _charOffset;
    final occupied = <int, Set<int>>{};
    final cells = <TableCellContent>[];
    var columns = 0;
    for (var row = 0; row < rows.length; row++) {
      final (node, rowStyle) = rows[row];
      if (node.parent is dom.Element) _recordAnchor(node.parent!);
      _recordAnchor(node);
      var column = 0;
      for (final cell in node.children) {
        if (cell.localName != 'td' && cell.localName != 'th') continue;
        final cellStyle = _resolveStyle(cell, rowStyle);
        if (cellStyle.hidden) continue;
        final columnSpan = (int.tryParse(cell.attributes['colspan'] ?? '') ?? 1)
            .clamp(1, 1000);
        var rowSpan = int.tryParse(cell.attributes['rowspan'] ?? '') ?? 1;
        rowSpan = rowSpan == 0
            ? groupEnds[row] - row
            : rowSpan.clamp(1, groupEnds[row] - row);
        while (true) {
          var free = true;
          for (var c = column; c < column + columnSpan; c++) {
            if (occupied[row]?.contains(c) ?? false) {
              free = false;
              break;
            }
          }
          if (free) break;
          column++;
        }
        for (var r = row; r < row + rowSpan; r++) {
          final used = occupied.putIfAbsent(r, () => <int>{});
          for (var c = column; c < column + columnSpan; c++) {
            used.add(c);
          }
        }
        _recordAnchor(cell);
        final content = <ContentElement>[];
        _flow(
          cell.nodes,
          content,
          cellStyle,
          type: cell.localName == 'th'
              ? TextBlockType.tableHeader
              : TextBlockType.paragraph,
        );
        cells.add(
          TableCellContent(
            row: row,
            column: column,
            rowSpan: rowSpan,
            columnSpan: columnSpan,
            elements: content,
          ),
        );
        column += columnSpan;
        if (column > columns) columns = column;
      }
    }
    if (cells.isEmpty) return;
    elements.add(
      TableBlock(
        rowCount: rows.length,
        columnCount: columns,
        cells: cells,
        indent: indent,
        charStart: start,
        charEnd: _charOffset,
      ),
    );
  }
}

class _ListMarker {
  final String text;
  final int index;
  bool pending = true;
  _ListMarker(this.text, this.index);
}

/// Flush at structural boundaries; inline descendants never swallow blocks.
class _ParagraphRun {
  final XhtmlParser parser;
  final List<ContentElement> elements;
  final EpubStyle style;
  final TextBlockType type;
  final double indent;
  final _ListMarker? marker;
  List<InlineSpan> _spans = [];
  int? _start;
  int? _listIndex;

  _ParagraphRun(
    this.parser,
    this.elements,
    this.style,
    this.type,
    this.indent,
    this.marker,
  );

  void _begin() {
    _start ??= parser._charOffset;
    if (marker?.pending == true) {
      _spans.add(TextSpan(text: marker!.text, style: style.textStyle));
      parser._charOffset += marker!.text.length;
      _listIndex = marker!.index;
      marker!.pending = false;
    }
  }

  void add(String text, TextStyle textStyle) {
    if (text.isEmpty) return;
    if (_spans.isEmpty &&
        text.trim().isEmpty &&
        type != TextBlockType.pre &&
        type != TextBlockType.code)
      return;
    _begin();
    _spans.add(TextSpan(text: text, style: textStyle));
    parser._charOffset += text.length;
  }

  void lineBreak(TextStyle textStyle) {
    _begin();
    _spans.add(TextSpan(text: '\n', style: textStyle));
    parser._charOffset++;
  }

  void flush({bool markerOnly = false}) {
    if (markerOnly && marker?.pending == true) _begin();
    if (_spans.isEmpty) return;
    final span = _spans.length == 1
        ? _spans.single
        : TextSpan(children: _spans);
    elements.add(
      TextBlock(
        span: applyHighlightRanges(span, _start!, parser.highlights),
        type: type,
        listIndex: _listIndex,
        indent: indent,
        textAlign: style.textAlign,
        margin: style.margin,
        charStart: _start!,
        charEnd: parser._charOffset,
      ),
    );
    _spans = [];
    _start = null;
    _listIndex = null;
  }
}

/// Splits each original text run once. Later ranges win where colors overlap;
/// nested, duplicate and crossing ranges never change the underlying text.
InlineSpan applyHighlightRanges(
  InlineSpan span,
  int startOffset,
  List<HighlightRange> ranges,
) {
  if (span is! TextSpan || ranges.isEmpty) return span;
  final children = <InlineSpan>[];
  final text = span.text ?? '';
  final endOffset = startOffset + text.length;
  final relevant = ranges
      .where(
        (range) =>
            range.startOffset < endOffset &&
            range.endOffset > startOffset &&
            range.startOffset < range.endOffset,
      )
      .toList(growable: false);
  if (text.isNotEmpty) {
    final boundaries = <int>{startOffset, endOffset};
    for (final range in relevant) {
      boundaries.add(range.startOffset.clamp(startOffset, endOffset));
      boundaries.add(range.endOffset.clamp(startOffset, endOffset));
    }
    final sorted = boundaries.toList()..sort();
    for (var index = 0; index + 1 < sorted.length; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      Color? color;
      for (final range in relevant) {
        if (range.startOffset <= start && range.endOffset >= end) {
          final hex = range.color.replaceFirst('#', '');
          final value = hex.length == 6
              ? int.tryParse('FF$hex', radix: 16)
              : null;
          if (value != null) color = Color(value).withAlpha(90);
        }
      }
      children.add(
        TextSpan(
          text: text.substring(start - startOffset, end - startOffset),
          style: color == null ? null : TextStyle(backgroundColor: color),
          recognizer: span.recognizer,
          mouseCursor: span.mouseCursor,
        ),
      );
    }
  }
  var cursor = endOffset;
  for (final child in span.children ?? const <InlineSpan>[]) {
    children.add(applyHighlightRanges(child, cursor, ranges));
    cursor += child.toPlainText(includeSemanticsLabels: false).length;
  }
  return TextSpan(
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    locale: span.locale,
    semanticsLabel: span.semanticsLabel,
    spellOut: span.spellOut,
    children: children,
  );
}
