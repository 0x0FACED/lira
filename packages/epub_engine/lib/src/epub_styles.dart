import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css;
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;

import 'epub_paths.dart';

/// Reader-supported computed style. Layout declarations do not inherit.
class EpubStyle {
  final TextStyle textStyle;
  final TextAlign textAlign;
  final EdgeInsets? margin;
  final bool hidden;
  final String? display;

  const EpubStyle._({
    required this.textStyle,
    this.textAlign = TextAlign.start,
    this.margin,
    this.hidden = false,
    this.display,
  });
}

/// A local-only author cascade for typography and basic reader layout.
///
/// Selectors are deliberately bounded to tag, class, id, universal, descendant
/// and child selectors. Unsupported selectors/properties are ignored, never
/// approximated. No fonts, remote resources or browser layout are loaded.
class EpubStyleResolver {
  final EpubStyle root;
  final Map<String, String> _stylesheets;
  final List<_StyleRule> _rules = [];
  final Map<String, css.StyleSheet> _parsedStylesheets = {};
  double _rootFontSize;

  EpubStyleResolver({
    required dom.Document document,
    required String documentPath,
    required Map<String, String> stylesheets,
    required TextStyle baseStyle,
  }) : root = EpubStyle._(textStyle: baseStyle),
       _stylesheets = stylesheets,
       _rootFontSize = baseStyle.fontSize ?? 16 {
    for (final element in document.querySelectorAll('link, style')) {
      if (!_matchesMediaAttribute(element.attributes['media'])) continue;
      final type = element.attributes['type']?.trim().toLowerCase();
      if (type != null && type.isNotEmpty && type != 'text/css') continue;
      if (element.localName == 'style') {
        _addSheet(css_parser.parse(element.text), documentPath, <String>{});
      } else {
        final relationships = (element.attributes['rel'] ?? '')
            .toLowerCase()
            .split(RegExp(r'\s+'));
        if (!relationships.contains('stylesheet') ||
            relationships.contains('alternate') ||
            element.attributes.containsKey('disabled')) {
          continue;
        }
        final path = resolveEpubPath(
          documentPath,
          element.attributes['href'] ?? '',
        );
        if (path != null) _addExternalSheet(path, <String>{});
      }
    }
  }

  EpubStyle resolve(
    dom.Element element,
    EpubStyle parent, {
    TextStyle? defaultTextStyle,
  }) {
    final winners = <String, _CascadeValue>{};
    for (final rule in _rules) {
      _Specificity? specificity;
      for (final selector in rule.selectors) {
        if (selector.matches(element) &&
            (specificity == null ||
                selector.specificity.compareTo(specificity) > 0)) {
          specificity = selector.specificity;
        }
      }
      if (specificity == null) continue;
      for (final declaration in rule.declarations) {
        _offer(winners, declaration, specificity);
      }
    }
    final inline = element.attributes['style'];
    if (inline != null && inline.trim().isNotEmpty) {
      final sheet = css_parser.parse('* {$inline}');
      for (final rule in sheet.topLevels.whereType<css.RuleSet>()) {
        for (final declaration in _declarations(rule.declarationGroup)) {
          _offer(winners, declaration, const _Specificity(inline: true));
        }
      }
    }
    String? value(String property) => winners[property]?.value;

    var style = parent.textStyle.merge(defaultTextStyle);
    final inheritedSize = parent.textStyle.fontSize ?? 16;
    if (element.localName == 'font') {
      final color = element.attributes['color'];
      final size = element.attributes['size'];
      if (color != null) {
        style = style.copyWith(color: _parseColor(color.trim().toLowerCase()));
      }
      if (size != null) {
        final multiplier = double.tryParse(size) ?? 1.0;
        style = style.copyWith(
          fontSize: (style.fontSize ?? 16) * multiplier / 3.0,
        );
      }
    }
    final fontSize = value('font-size');
    if (fontSize != null) {
      style = style.copyWith(fontSize: _fontSize(fontSize, inheritedSize));
    }
    final weight = value('font-weight');
    if (weight != null) {
      style = style.copyWith(
        fontWeight: _fontWeight(weight, parent.textStyle.fontWeight),
      );
    }
    final fontStyle = value('font-style');
    if (fontStyle != null) {
      style = style.copyWith(
        fontStyle: fontStyle == 'inherit'
            ? parent.textStyle.fontStyle ?? FontStyle.normal
            : fontStyle == 'normal'
            ? FontStyle.normal
            : FontStyle.italic,
      );
    }
    final decoration = value('text-decoration');
    if (decoration != null) {
      style = style.copyWith(
        decoration: decoration == 'inherit'
            ? parent.textStyle.decoration ?? TextDecoration.none
            : TextDecoration.combine([
                if (decoration.contains('underline')) TextDecoration.underline,
                if (decoration.contains('line-through'))
                  TextDecoration.lineThrough,
                if (decoration.contains('overline')) TextDecoration.overline,
              ]),
      );
    }
    final color = value('color');
    if (color != null) {
      style = style.copyWith(
        color: color == 'inherit' ? parent.textStyle.color : _parseColor(color),
      );
    }
    final verticalAlign = value('vertical-align');
    if (verticalAlign == 'super' || verticalAlign == 'sub') {
      final semanticScript =
          defaultTextStyle?.fontFeatures?.any(
            (feature) =>
                feature == const FontFeature.superscripts() ||
                feature == const FontFeature.subscripts(),
          ) ??
          false;
      style = style.copyWith(
        fontSize: fontSize == null && !semanticScript
            ? (style.fontSize ?? 16) * 0.75
            : style.fontSize,
        fontFeatures: [
          if (verticalAlign == 'super')
            const FontFeature.superscripts()
          else
            const FontFeature.subscripts(),
        ],
      );
    } else if (verticalAlign == 'baseline') {
      style = style.copyWith(fontFeatures: const []);
    }

    // Reader spacing is a multiplier of each run's computed font size. Author
    // line-height (including !important and absolute lengths) must not defeat
    // it, or a book's body rule makes the spacing control ineffective.
    style = style.copyWith(height: root.textStyle.height ?? 1.5);
    if (element.localName == 'html') _rootFontSize = style.fontSize ?? 16;

    final alignment = value('text-align');
    final display = value('display');
    final visibility = value('visibility');
    final hasMargin = const [
      'top',
      'right',
      'bottom',
      'left',
    ].any((side) => winners.containsKey('margin-$side'));
    double margin(String side) {
      final cssValue = value('margin-$side');
      if (cssValue == 'inherit') {
        return switch (side) {
          'top' => parent.margin?.top ?? 0,
          'right' => parent.margin?.right ?? 0,
          'bottom' => parent.margin?.bottom ?? 0,
          _ => parent.margin?.left ?? 0,
        };
      }
      if (cssValue == null || cssValue == 'auto') return 0;
      return _length(cssValue, style.fontSize ?? 16, _rootFontSize) ?? 0;
    }

    return EpubStyle._(
      textStyle: style,
      textAlign: alignment == null || alignment == 'inherit'
          ? parent.textAlign
          : _textAlignments[alignment]!,
      margin: hasMargin
          ? EdgeInsets.fromLTRB(
              margin('left'),
              margin('top'),
              margin('right'),
              margin('bottom'),
            )
          : null,
      hidden:
          parent.hidden ||
          display == 'none' ||
          visibility == 'hidden' ||
          visibility == 'collapse',
      display: display == 'inherit' ? parent.display : display,
    );
  }

  void _offer(
    Map<String, _CascadeValue> winners,
    _Declaration declaration,
    _Specificity specificity,
  ) {
    final previous = winners[declaration.property];
    if (previous == null ||
        (declaration.important && !previous.important) ||
        (declaration.important == previous.important &&
            specificity.compareTo(previous.specificity) >= 0)) {
      winners[declaration.property] = _CascadeValue(
        declaration.value,
        declaration.important,
        specificity,
      );
    }
  }

  void _addExternalSheet(String path, Set<String> importing) {
    final source = _stylesheets[path];
    if (source == null || !importing.add(path)) return;
    final sheet = _parsedStylesheets.putIfAbsent(
      path,
      () => css_parser.parse(source),
    );
    _addSheet(sheet, path, importing);
    importing.remove(path);
  }

  void _addSheet(css.StyleSheet sheet, String path, Set<String> importing) {
    _addRules(sheet.topLevels, path, importing);
  }

  void _addRules(List<css.TreeNode> nodes, String path, Set<String> importing) {
    for (final node in nodes) {
      if (node is css.ImportDirective) {
        if (!_matchesMedia(node.mediaQueries)) continue;
        // csslib retains quotes for url("..."), but not for string imports.
        var href = node.import;
        if (href.length >= 2 &&
            (href[0] == '"' || href[0] == "'") &&
            href[href.length - 1] == href[0]) {
          href = href.substring(1, href.length - 1);
        }
        final importedPath = resolveEpubPath(path, href);
        if (importedPath != null) _addExternalSheet(importedPath, importing);
      } else if (node is css.MediaDirective) {
        if (_matchesMedia(node.mediaQueries))
          _addRules(node.rules, path, importing);
      } else if (node is css.RuleSet) {
        final selectors = <_Selector>[];
        for (final selector
            in node.selectorGroup?.selectors ?? <css.Selector>[]) {
          final compiled = _Selector.compile(selector);
          if (compiled != null) selectors.add(compiled);
        }
        final declarations = _declarations(node.declarationGroup);
        if (selectors.isNotEmpty && declarations.isNotEmpty) {
          _rules.add(_StyleRule(selectors, declarations));
        }
      }
    }
  }

  double _fontSize(String value, double inherited) {
    if (value == 'inherit') return inherited;
    if (value == 'larger') return inherited * 1.2;
    if (value == 'smaller') return inherited / 1.2;
    final scale = _fontSizeKeywords[value];
    if (scale != null) return (root.textStyle.fontSize ?? 16) * scale;
    final length = _length(value, inherited, _rootFontSize);
    if (length == null) return inherited;
    if (value.endsWith('em') || value.endsWith('%')) return length;
    // CSS absolute sizes describe document proportions at the CSS default
    // 16px, not fixed reader pixels. Scale all absolute units with the reader's
    // choice while leaving em/rem/% relative to their already-scaled parents.
    return length * (root.textStyle.fontSize ?? 16) / 16;
  }
}

class _StyleRule {
  final List<_Selector> selectors;
  final List<_Declaration> declarations;
  const _StyleRule(this.selectors, this.declarations);
}

class _Declaration {
  final String property;
  final String value;
  final bool important;
  const _Declaration(this.property, this.value, this.important);
}

class _CascadeValue {
  final String value;
  final bool important;
  final _Specificity specificity;
  const _CascadeValue(this.value, this.important, this.specificity);
}

class _Specificity implements Comparable<_Specificity> {
  final bool inline;
  final int ids;
  final int classes;
  final int tags;
  const _Specificity({
    this.inline = false,
    this.ids = 0,
    this.classes = 0,
    this.tags = 0,
  });

  @override
  int compareTo(_Specificity other) {
    if (inline != other.inline) return inline ? 1 : -1;
    if (ids != other.ids) return ids.compareTo(other.ids);
    if (classes != other.classes) return classes.compareTo(other.classes);
    return tags.compareTo(other.tags);
  }
}

class _Selector {
  final List<_SelectorPart> parts;
  final _Specificity specificity;
  const _Selector(this.parts, this.specificity);

  static _Selector? compile(css.Selector selector) {
    final parts = <_SelectorPart>[];
    var ids = 0;
    var classes = 0;
    var tags = 0;
    for (final sequence in selector.simpleSelectorSequences) {
      if (!sequence.isCombinatorNone &&
          !sequence.isCombinatorDescendant &&
          !sequence.isCombinatorGreater) {
        return null;
      }
      if (parts.isEmpty || !sequence.isCombinatorNone) {
        parts.add(_SelectorPart(child: sequence.isCombinatorGreater));
      }
      final part = parts.last;
      final simple = sequence.simpleSelector;
      if (simple is css.IdSelector) {
        part.ids.add(simple.name);
        ids++;
      } else if (simple is css.ClassSelector) {
        part.classes.add(simple.name);
        classes++;
      } else if (simple is css.ElementSelector) {
        if (!simple.isWildcard) {
          part.tag = simple.name.toLowerCase();
          tags++;
        }
      } else {
        return null;
      }
    }
    return parts.isEmpty
        ? null
        : _Selector(
            parts,
            _Specificity(ids: ids, classes: classes, tags: tags),
          );
  }

  bool matches(dom.Element element) => _matchesPart(element, parts.length - 1);

  bool _matchesPart(dom.Element element, int index) {
    final part = parts[index];
    if (!part.matches(element)) return false;
    if (index == 0) return true;
    var ancestor = element.parent;
    if (part.child) {
      return ancestor != null && _matchesPart(ancestor, index - 1);
    }
    while (ancestor != null) {
      if (_matchesPart(ancestor, index - 1)) return true;
      ancestor = ancestor.parent;
    }
    return false;
  }
}

class _SelectorPart {
  final bool child;
  final List<String> ids = [];
  final List<String> classes = [];
  String? tag;
  _SelectorPart({required this.child});

  bool matches(dom.Element element) =>
      (tag == null || element.localName?.toLowerCase() == tag) &&
      ids.every((id) => element.id == id) &&
      classes.every(element.classes.contains);
}

List<_Declaration> _declarations(css.DeclarationGroup group) {
  final result = <_Declaration>[];
  for (final declaration in group.declarations.whereType<css.Declaration>()) {
    final property = declaration.property.toLowerCase();
    if (!_supportedProperties.contains(property)) continue;
    final expression = declaration.expression;
    if (expression == null) continue;
    final printer = css.CssPrinter();
    expression.visit(printer);
    final value = printer.toString().trim().toLowerCase();
    if (property == 'margin') {
      final values = value.split(RegExp(r'\s+'));
      if (values.isEmpty || values.length > 4 || !values.every(_isMargin))
        continue;
      final top = values[0];
      final right = values.length > 1 ? values[1] : top;
      final bottom = values.length > 2 ? values[2] : top;
      final left = values.length > 3 ? values[3] : right;
      for (final entry in {
        'top': top,
        'right': right,
        'bottom': bottom,
        'left': left,
      }.entries) {
        result.add(
          _Declaration(
            'margin-${entry.key}',
            entry.value,
            declaration.important,
          ),
        );
      }
    } else if (_supportedValue(property, value)) {
      result.add(_Declaration(property, value, declaration.important));
    }
  }
  return result;
}

const _supportedProperties = {
  'font-size',
  'font-weight',
  'font-style',
  'text-decoration',
  'text-align',
  'margin',
  'margin-top',
  'margin-right',
  'margin-bottom',
  'margin-left',
  'vertical-align',
  'display',
  'visibility',
  'color',
};

bool _supportedValue(String property, String value) {
  switch (property) {
    case 'font-size':
      return value == 'inherit' ||
          value == 'larger' ||
          value == 'smaller' ||
          _fontSizeKeywords.containsKey(value) ||
          _isLength(value, nonnegative: true);
    case 'font-weight':
      return const [
            'inherit',
            'normal',
            'bold',
            'bolder',
            'lighter',
          ].contains(value) ||
          RegExp(r'^[1-9]00$').hasMatch(value);
    case 'font-style':
      return const ['inherit', 'normal', 'italic', 'oblique'].contains(value);
    case 'text-decoration':
      return value == 'inherit' ||
          value == 'none' ||
          value
              .split(RegExp(r'\s+'))
              .every(
                (token) => const [
                  'underline',
                  'overline',
                  'line-through',
                ].contains(token),
              );
    case 'text-align':
      return value == 'inherit' || _textAlignments.containsKey(value);
    case 'margin-top':
    case 'margin-right':
    case 'margin-bottom':
    case 'margin-left':
      return _isMargin(value);
    case 'vertical-align':
      return const ['super', 'sub', 'baseline'].contains(value);
    case 'display':
      return const [
        'inherit',
        'none',
        'block',
        'inline',
        'inline-block',
        'list-item',
        'table',
        'table-row',
        'table-cell',
        'table-row-group',
        'table-header-group',
        'table-footer-group',
      ].contains(value);
    case 'visibility':
      return const ['inherit', 'visible', 'hidden', 'collapse'].contains(value);
    case 'color':
      return value == 'inherit' || _parseColor(value) != null;
    default:
      return false;
  }
}

final _lengthPattern = RegExp(
  r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+))(px|em|rem|pt|pc|in|cm|mm|%)?$',
);

bool _isLength(String value, {bool nonnegative = false}) {
  final match = _lengthPattern.firstMatch(value);
  if (match == null) return false;
  final number = double.parse(match[1]!);
  return number.isFinite &&
      (!nonnegative || number >= 0) &&
      (match[2] != null || number == 0);
}

bool _isMargin(String value) =>
    value == 'inherit' ||
    value == 'auto' ||
    (_isLength(value, nonnegative: true) && !value.endsWith('%'));

double? _length(String value, double em, double rem) {
  final match = _lengthPattern.firstMatch(value);
  if (match == null) return null;
  final number = double.parse(match[1]!);
  return number *
      (switch (match[2]) {
        'em' => em,
        'rem' => rem,
        '%' => em / 100,
        'pt' => 96 / 72,
        'pc' => 16,
        'in' => 96,
        'cm' => 96 / 2.54,
        'mm' => 96 / 25.4,
        _ => 1,
      });
}

FontWeight _fontWeight(String value, FontWeight? parent) {
  final inherited = parent ?? FontWeight.normal;
  if (value == 'inherit') return inherited;
  if (value == 'normal') return FontWeight.normal;
  if (value == 'bold') return FontWeight.bold;
  if (value == 'bolder') {
    return inherited.value < 400
        ? FontWeight.w400
        : inherited.value < 600
        ? FontWeight.w700
        : FontWeight.w900;
  }
  if (value == 'lighter') {
    return inherited.value < 600
        ? FontWeight.w100
        : inherited.value < 800
        ? FontWeight.w400
        : FontWeight.w700;
  }
  return FontWeight.values[int.parse(value) ~/ 100 - 1];
}

const _fontSizeKeywords = {
  'xx-small': 0.6,
  'x-small': 0.75,
  'small': 0.89,
  'medium': 1.0,
  'large': 1.2,
  'x-large': 1.5,
  'xx-large': 2.0,
};

const _textAlignments = {
  'start': TextAlign.start,
  'end': TextAlign.end,
  'left': TextAlign.left,
  'right': TextAlign.right,
  'center': TextAlign.center,
  'justify': TextAlign.justify,
};

bool _matchesMediaAttribute(String? value) =>
    value == null ||
    value.trim().isEmpty ||
    value
        .toLowerCase()
        .split(',')
        .any((part) => const ['all', 'screen'].contains(part.trim()));

bool _matchesMedia(List<css.MediaQuery> queries) =>
    queries.isEmpty ||
    queries.any(
      (query) =>
          query.expressions.isEmpty &&
          (!query.hasUnary || query.unary != 'NOT') &&
          (!query.hasMediaType ||
              const ['all', 'screen'].contains(query.mediaType.toLowerCase())),
    );

Color? _parseColor(String value) {
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (hex.length == 3)
      hex = hex.split('').map((character) => '$character$character').join();
    if (hex.length != 6) return null;
    final number = int.tryParse(hex, radix: 16);
    return number == null ? null : Color(0xFF000000 | number);
  }
  final rgb = RegExp(
    r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*[\d.]+)?\s*\)$',
  ).firstMatch(value);
  if (rgb != null) {
    final components = [
      for (var index = 1; index <= 3; index++) int.parse(rgb[index]!),
    ];
    if (components.any((component) => component > 255)) return null;
    return Color.fromARGB(255, components[0], components[1], components[2]);
  }
  const colors = {
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
  final color = colors[value];
  return color == null ? null : Color(color);
}
