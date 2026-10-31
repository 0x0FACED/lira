import 'package:flutter/widgets.dart';

import 'hyphenation_patterns.dart';

const _indentGlyphStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 1,
  fontWeight: FontWeight.normal,
  fontStyle: FontStyle.normal,
  color: Color(0x00000000),
  height: 1,
  letterSpacing: 0,
);

// Reserve the indent with a real glyph advance, not tracking. SkParagraph's
// justification handles leading letterSpacing differently from caret layout,
// so a tracking-based spacer can push the first line past the right margin.
// The transparent run stays one pixel high; zero height means the font's normal
// height in SkParagraph and would enlarge the first line.
final double _indentGlyphAdvance = _measureIndentGlyph();

double _measureIndentGlyph() {
  final painter = TextPainter(
    text: const TextSpan(text: 'x', style: _indentGlyphStyle),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final advance = painter.width;
  painter.dispose();
  return advance;
}

TextSpan _buildIndentSpan(double width) {
  final fontSize = width / _indentGlyphAdvance;
  return TextSpan(
    text: 'x',
    semanticsLabel: '',
    style: _indentGlyphStyle.copyWith(fontSize: fontSize, height: 1 / fontSize),
  );
}

class _PatternNode {
  final children = <int, _PatternNode>{};
  List<int>? weights;
}

/// Liang's pattern algorithm. Pattern data is initialized once per language;
/// cached words never require a second trie traversal during layout or paint.
class _PatternHyphenator {
  final _PatternNode root = _PatternNode();
  final int rightMinimum;
  final _words = <String, List<int>>{};
  final _exceptions = <String, List<int>>{};

  _PatternHyphenator(String source, this.rightMinimum) {
    source = source.replaceAll(RegExp(r'%[^\n]*'), '');
    final patterns = RegExp(
      r'\\patterns\s*\{([^}]*)\}',
    ).firstMatch(source)![1]!;
    for (final pattern in patterns.split(RegExp(r'\s+'))) {
      if (pattern.isEmpty) continue;
      var node = root;
      final weights = <int>[0];
      for (final unit in pattern.codeUnits) {
        if (unit >= 48 && unit <= 57) {
          weights[weights.length - 1] = unit - 48;
        } else {
          node = node.children.putIfAbsent(unit, _PatternNode.new);
          weights.add(0);
        }
      }
      node.weights = weights;
    }
    final exceptions = RegExp(
      r'\\hyphenation\s*\{([^}]*)\}',
    ).firstMatch(source)?[1];
    for (final exception in exceptions?.split(RegExp(r'\s+')) ?? <String>[]) {
      final points = <int>[];
      var offset = 0;
      for (final unit in exception.codeUnits) {
        if (unit == 45) {
          points.add(offset);
        } else {
          offset++;
        }
      }
      _exceptions[exception.replaceAll('-', '')] = points;
    }
  }

  List<int> positions(String word) {
    final cached = _words[word];
    if (cached != null) return cached;
    if (_words.length >= 4096) _words.remove(_words.keys.first);
    return _words.putIfAbsent(word, () {
      if (_exceptions[word] case final exception?) return exception;
      final text = '.$word.';
      final weights = List<int>.filled(text.length + 1, 0);
      for (var start = 0; start < text.length; start++) {
        var node = root;
        for (var end = start; end < text.length; end++) {
          final next = node.children[text.codeUnitAt(end)];
          if (next == null) break;
          node = next;
          final values = node.weights;
          if (values == null) continue;
          for (var index = 0; index < values.length; index++) {
            if (values[index] > weights[start + index]) {
              weights[start + index] = values[index];
            }
          }
        }
      }
      return [
        for (var offset = 2; offset <= word.length - rightMinimum; offset++)
          if (weights[offset + 1].isOdd) offset,
      ];
    });
  }
}

_PatternHyphenator? _english;
_PatternHyphenator? _russian;
final _words = RegExp(r'[A-Za-zА-Яа-яЁё]+');
final _englishWord = RegExp(r'^[a-z]+$');
final _russianWord = RegExp(r'^[а-яё]+$');
final _languageSeparator = RegExp('[-_]');

/// Source UTF-16 boundaries, including words crossing inline style boundaries.
/// Explicit unknown languages do not silently acquire English/Russian rules.
List<int> readerHyphenationOffsets(InlineSpan span) {
  final text = span.toPlainText(includeSemanticsLabels: false);
  final points = <int>[];
  final runs = <({int start, int end, String language})>[];
  var cursor = 0;
  void visit(InlineSpan current, String inherited) {
    if (current is! TextSpan) {
      cursor++;
      return;
    }
    final locale = current.locale ?? current.style?.locale;
    final language = locale == null
        ? inherited
        : locale.languageCode.toLowerCase().split(_languageSeparator).first;
    final length = current.text?.length ?? 0;
    if (length > 0)
      runs.add((start: cursor, end: cursor + length, language: language));
    cursor += length;
    for (final child in current.children ?? const <InlineSpan>[]) {
      visit(child, language);
    }
  }

  visit(span, '');
  var runIndex = 0;
  for (final match in _words.allMatches(text)) {
    while (runIndex < runs.length && runs[runIndex].end <= match.start) {
      runIndex++;
    }
    if (runIndex == runs.length) break;
    final language = runs[runIndex].language;
    var sameLanguage = true;
    for (
      var index = runIndex;
      index < runs.length && runs[index].start < match.end;
      index++
    ) {
      if (runs[index].language != language) sameLanguage = false;
    }
    if (!sameLanguage) continue;
    final word = match[0]!.toLowerCase();
    final hyphenator = switch (language) {
      'en' when _englishWord.hasMatch(word) => _english ??= _PatternHyphenator(
        englishHyphenationPatterns,
        3,
      ),
      'ru' when _russianWord.hasMatch(word) => _russian ??= _PatternHyphenator(
        russianHyphenationPatterns,
        2,
      ),
      _ => null,
    };
    if (hyphenator == null) continue;
    points.addAll(
      hyphenator.positions(word).map((point) => match.start + point),
    );
  }
  return points;
}

/// A display-only layer: all public locations continue to address the untouched
/// source string. Insertions map both of their edges to one source boundary.
class ReaderTextPresentation {
  final String sourceText;
  final TextSpan span;
  final List<int> hyphenationOffsets;
  final List<int> _sourceToDisplay;
  final List<int> _displayToSource;
  final Set<int> _insertions;
  final TextSpan? _indentSpan;

  ReaderTextPresentation._(
    this.sourceText,
    this.span,
    this.hyphenationOffsets,
    this._sourceToDisplay,
    this._displayToSource,
    this._insertions,
    this._indentSpan,
  );

  factory ReaderTextPresentation({
    required InlineSpan source,
    List<int> hyphenationOffsets = const [],
    double firstLineIndent = 0,
    bool trailingHyphen = false,
    double? maxWidth,
    TextStyle? baseStyle,
    bool measureOpportunities = false,
    Set<int>? selectedHyphens,
    ReaderTextPresentation? reuseCoordinates,
  }) {
    final text =
        reuseCoordinates?.sourceText ??
        source.toPlainText(includeSemanticsLabels: false);
    final insertions =
        reuseCoordinates?._insertions ??
        selectedHyphens ??
        (measureOpportunities
            ? hyphenationOffsets.toSet()
            : maxWidth != null &&
                  maxWidth.isFinite &&
                  hyphenationOffsets.isNotEmpty
            ? _chooseVisibleHyphens(
                source,
                text,
                hyphenationOffsets,
                firstLineIndent,
                trailingHyphen,
                baseStyle,
                maxWidth,
              )
            : <int>{});
    final sourceToDisplay =
        reuseCoordinates?._sourceToDisplay ??
        List<int>.filled(text.length + 1, 0);
    final displayToSource = reuseCoordinates?._displayToSource ?? <int>[0];
    final indentSpan =
        reuseCoordinates?._indentSpan ??
        (firstLineIndent > 0 ? _buildIndentSpan(firstLineIndent) : null);
    if (reuseCoordinates == null) {
      var displayOffset = 0;
      for (var offset = 0; offset <= text.length; offset++) {
        if (offset == 0 && firstLineIndent > 0) {
          displayOffset++;
          displayToSource.add(0);
        }
        if (insertions.contains(offset) ||
            (offset == text.length && trailingHyphen)) {
          displayOffset++;
          displayToSource.add(offset);
        }
        sourceToDisplay[offset] = displayOffset;
        if (offset < text.length) {
          displayOffset++;
          displayToSource.add(offset + 1);
        }
      }
    }
    final displaySpan = _MappedTextSpan(
      sourceToDisplay,
      displayToSource,
      children: _readerDisplayChildren(
        source,
        insertions.toList()..sort(),
        indentSpan,
        trailingHyphen,
        measureOpportunities,
        baseStyle,
      ),
    );
    return ReaderTextPresentation._(
      text,
      displaySpan,
      hyphenationOffsets,
      sourceToDisplay,
      displayToSource,
      insertions,
      indentSpan,
    );
  }

  int toDisplay(int sourceOffset) =>
      _sourceToDisplay[sourceOffset.clamp(0, sourceText.length)];

  int toSource(int displayOffset) =>
      _displayToSource[displayOffset.clamp(0, _displayToSource.length - 1)];

  bool hasVisibleHyphenAt(int sourceOffset) =>
      _insertions.contains(sourceOffset);
}

List<InlineSpan> _readerDisplayChildren(
  InlineSpan source,
  List<int> insertions,
  TextSpan? indentSpan,
  bool trailingHyphen,
  bool measureOpportunities,
  TextStyle? baseStyle,
) {
  var cursor = 0;
  var insertionIndex = 0;
  TextStyle? lastStyle;
  InlineSpan transform(InlineSpan original, [TextStyle? inherited]) {
    if (original is! TextSpan) return original;
    final ownText = original.text ?? '';
    final effectiveStyle =
        (inherited?.merge(original.style) ??
                original.style ??
                const TextStyle())
            .copyWith(inherit: false);
    final children = <InlineSpan>[];
    var start = 0;
    while (insertionIndex < insertions.length &&
        insertions[insertionIndex] < cursor + ownText.length) {
      final local = insertions[insertionIndex++] - cursor;
      if (local < 0) continue;
      if (local > start)
        children.add(TextSpan(text: ownText.substring(start, local)));
      children.add(
        TextSpan(
          text: measureOpportunities ? '\u00ad' : '-',
          semanticsLabel: '',
          style: local == 0 ? lastStyle ?? effectiveStyle : effectiveStyle,
        ),
      );
      start = local;
    }
    if (start < ownText.length)
      children.add(TextSpan(text: ownText.substring(start)));
    if (ownText.isNotEmpty) lastStyle = effectiveStyle;
    cursor += ownText.length;
    for (final child in original.children ?? const <InlineSpan>[]) {
      children.add(transform(child, effectiveStyle));
    }
    return TextSpan(
      style: original.style,
      recognizer: original.recognizer,
      mouseCursor: original.mouseCursor,
      onEnter: original.onEnter,
      onExit: original.onExit,
      locale: original.locale,
      spellOut: original.spellOut,
      children: children,
    );
  }

  return [
    if (indentSpan != null) indentSpan,
    transform(source, baseStyle),
    if (trailingHyphen)
      TextSpan(text: '-', semanticsLabel: '', style: lastStyle),
  ];
}

class _ReaderRun {
  final int start;
  final int end;
  final TextSpan span;
  const _ReaderRun(this.start, this.end, this.span);
}

/// Flatten once, then slice only the runs in a small line window. A long styled
/// chapter must not repeatedly traverse its preceding text for every new line.
class _ReaderRuns {
  final runs = <_ReaderRun>[];

  _ReaderRuns(InlineSpan source, TextStyle? baseStyle) {
    var offset = 0;
    void visit(InlineSpan span, TextStyle? inherited, Locale? inheritedLocale) {
      if (span is! TextSpan) return;
      final style =
          (inherited?.merge(span.style) ?? span.style ?? const TextStyle())
              .copyWith(inherit: false);
      final locale = span.locale ?? inheritedLocale;
      final text = span.text ?? '';
      if (text.isNotEmpty) {
        runs.add(
          _ReaderRun(
            offset,
            offset + text.length,
            TextSpan(
              text: text,
              style: style,
              recognizer: span.recognizer,
              mouseCursor: span.mouseCursor,
              onEnter: span.onEnter,
              onExit: span.onExit,
              locale: locale,
              spellOut: span.spellOut,
            ),
          ),
        );
        offset += text.length;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style, locale);
      }
    }

    visit(source, baseStyle, null);
  }

  TextSpan slice(
    int start,
    int end, {
    List<int> hyphenationOffsets = const [],
    TextSpan? indentSpan,
    bool trailingHyphen = false,
  }) {
    var low = 0;
    var high = runs.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (runs[middle].end <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final children = <InlineSpan>[if (indentSpan != null) indentSpan];
    var opportunityIndex = 0;
    TextStyle? lastStyle;
    for (
      var index = low;
      index < runs.length && runs[index].start < end;
      index++
    ) {
      final run = runs[index];
      final span = run.span;
      final localStart = (start - run.start).clamp(0, run.end - run.start);
      final localEnd = (end - run.start).clamp(0, run.end - run.start);
      final hasOpportunities =
          opportunityIndex < hyphenationOffsets.length &&
          start + hyphenationOffsets[opportunityIndex] < run.start + localEnd;
      List<InlineSpan>? pieces;
      if (hasOpportunities) {
        pieces = <InlineSpan>[];
        var cursor = localStart;
        while (opportunityIndex < hyphenationOffsets.length &&
            start + hyphenationOffsets[opportunityIndex] <
                run.start + localEnd) {
          final local =
              start + hyphenationOffsets[opportunityIndex] - run.start;
          if (local > cursor) {
            pieces.add(TextSpan(text: span.text!.substring(cursor, local)));
          }
          pieces.add(
            TextSpan(
              text: '\u00ad',
              semanticsLabel: '',
              style: local == localStart ? lastStyle ?? span.style : span.style,
            ),
          );
          cursor = local;
          opportunityIndex++;
        }
        if (cursor < localEnd) {
          pieces.add(TextSpan(text: span.text!.substring(cursor, localEnd)));
        }
      }
      if (pieces == null &&
          localStart == 0 &&
          localEnd == run.end - run.start) {
        children.add(span);
      } else {
        children.add(
          TextSpan(
            text: pieces == null
                ? span.text!.substring(localStart, localEnd)
                : null,
            style: span.style,
            recognizer: span.recognizer,
            mouseCursor: span.mouseCursor,
            onEnter: span.onEnter,
            onExit: span.onExit,
            locale: span.locale,
            spellOut: span.spellOut,
            children: pieces,
          ),
        );
      }
      lastStyle = span.style;
    }
    if (trailingHyphen) {
      children.add(TextSpan(text: '-', semanticsLabel: '', style: lastStyle));
    }
    return TextSpan(children: children);
  }
}

/// Probe windows need only a few boundary conversions, not two UTF-16-sized
/// coordinate maps. Insertion i ends at sourceOffset + i + 1 (after the indent).
class _ReaderProbeText {
  final TextSpan span;
  final int sourceLength;
  final List<int> opportunities;
  final bool indented;
  final bool trailingHyphen;

  const _ReaderProbeText(
    this.span,
    this.sourceLength,
    this.opportunities,
    this.indented,
    this.trailingHyphen,
  );

  int get displayLength =>
      sourceLength +
      opportunities.length +
      (indented ? 1 : 0) +
      (trailingHyphen ? 1 : 0);

  int toSource(int offset) {
    final unindented = offset - (indented ? 1 : 0);
    var low = 0;
    var high = opportunities.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (opportunities[middle] + middle < unindented) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return (unindented - low).clamp(0, sourceLength);
  }

  int toDisplay(int offset) {
    var low = 0;
    var high = opportunities.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (opportunities[middle] <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return offset +
        low +
        (indented ? 1 : 0) +
        (offset == sourceLength && trailingHyphen ? 1 : 0);
  }
}

class _ReaderProbe {
  final TextStyle? baseStyle;
  final TextPainter painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    textHeightBehavior: const TextHeightBehavior(),
  );

  _ReaderProbe(this.baseStyle);

  TextPainter layout(InlineSpan span, double width) {
    painter.text = TextSpan(style: baseStyle, children: [span]);
    painter.layout(maxWidth: width);
    return painter;
  }

  void dispose() => painter.dispose();
}

List<int> _displayLineEnds(TextPainter painter, int displayLength) {
  final metrics = painter.computeLineMetrics();
  final result = <int>[];
  for (var index = 1; index < metrics.length; index++) {
    final line = metrics[index];
    final position = painter.getPositionForOffset(
      Offset(line.left + line.width / 2, line.baseline - line.ascent / 2),
    );
    final end = painter.getLineBoundary(position).start;
    if (result.isEmpty || end > result.last) result.add(end);
  }
  if (result.isEmpty || result.last < displayLength) result.add(displayLength);
  return result;
}

int _firstDisplayLineEnd(TextPainter painter, int displayLength) {
  final metrics = painter.computeLineMetrics();
  if (metrics.length < 2) return displayLength;
  final next = metrics[1];
  return painter
      .getLineBoundary(
        painter.getPositionForOffset(
          Offset(next.left + next.width / 2, next.baseline - next.ascent / 2),
        ),
      )
      .start;
}

final _naturalReaderBreak = RegExp(r'\s+|[-‐–—/]');

/// Soft hyphens are measurement opportunities only: SkParagraph can wrap there
/// without painting a glyph. Reserve a real hyphen's advance before choosing a
/// break, then let ordinary wrapping/justification paint the resulting text.
Set<int> _chooseVisibleHyphens(
  InlineSpan source,
  String text,
  List<int> candidates,
  double indent,
  bool trailingHyphen,
  TextStyle? baseStyle,
  double width,
) {
  final candidateSet = candidates.toSet();
  candidates = candidateSet.toList()..sort();
  final indentSpan = indent > 0 ? _buildIndentSpan(indent) : null;
  final probe = _ReaderProbe(baseStyle);
  try {
    final opportunities = _ReaderProbeText(
      TextSpan(
        children: _readerDisplayChildren(
          source,
          candidates,
          indentSpan,
          trailingHyphen,
          true,
          baseStyle,
        ),
      ),
      text.length,
      candidates,
      indentSpan != null,
      trailingHyphen,
    );
    final baseline = probe.layout(opportunities.span, width);
    final baselineEnds = _displayLineEnds(
      baseline,
      opportunities.displayLength,
    ).map(opportunities.toSource).where((end) => end > 0).toList();
    if (baselineEnds.length == 1) return <int>{};
    final runs = _ReaderRuns(source, baseStyle);
    final selected = <int>{};
    var start = 0;
    var baselineIndex = 0;
    var candidateIndex = 0;
    while (start < text.length) {
      while (baselineIndex + 1 < baselineEnds.length &&
          baselineEnds[baselineIndex] <= start) {
        baselineIndex++;
      }
      final windowIndex = (baselineIndex + 2).clamp(0, baselineEnds.length - 1);
      final windowEnd = baselineEnds[windowIndex];
      while (candidateIndex < candidates.length &&
          candidates[candidateIndex] <= start) {
        candidateIndex++;
      }
      final windowCandidates = <int>[];
      for (
        var index = candidateIndex;
        index < candidates.length && candidates[index] < windowEnd;
        index++
      ) {
        windowCandidates.add(candidates[index] - start);
      }
      final lineIndent = start == 0 ? indentSpan : null;
      final window = _ReaderProbeText(
        runs.slice(
          start,
          windowEnd,
          hyphenationOffsets: windowCandidates,
          indentSpan: lineIndent,
          trailingHyphen: windowEnd == text.length && trailingHyphen,
        ),
        windowEnd - start,
        windowCandidates,
        lineIndent != null,
        windowEnd == text.length && trailingHyphen,
      );
      final painter = probe.layout(window.span, width);
      final displayEnd = _firstDisplayLineEnd(painter, window.displayLength);
      var end = start + window.toSource(displayEnd);
      final tookOpportunity =
          candidateSet.contains(end) &&
          end < text.length &&
          window.toDisplay(end - start) == displayEnd;
      if (tookOpportunity) {
        final options = <int>{};
        for (
          var index = candidateIndex;
          index < candidates.length && candidates[index] <= end;
          index++
        ) {
          options.add(candidates[index]);
        }
        for (final match in _naturalReaderBreak.allMatches(
          text.substring(start, end),
        )) {
          options.add(start + match.end);
        }
        final ordered = options.toList()..sort();
        bool fits(int option) {
          final hyphen = candidateSet.contains(option);
          var measureEnd = option;
          if (!hyphen) {
            while (measureEnd > start &&
                text.substring(measureEnd - 1, measureEnd).trim().isEmpty) {
              measureEnd--;
            }
          }
          final trial = runs.slice(
            start,
            measureEnd,
            indentSpan: lineIndent,
            trailingHyphen: hyphen,
          );
          return probe.layout(trial, double.infinity).width <= width + 0.001;
        }

        var low = 0;
        var high = ordered.length;
        // Usually the soft break has room for its real hyphen already. Measure
        // that exact shaped line once before searching earlier alternatives.
        if (high > 0 && fits(ordered.last)) {
          low = high;
        } else {
          high--;
          while (low < high) {
            final middle = (low + high) ~/ 2;
            if (fits(ordered[middle])) {
              low = middle + 1;
            } else {
              high = middle;
            }
          }
        }
        if (low > 0) {
          end = ordered[low - 1];
          if (candidateSet.contains(end)) selected.add(end);
        } else {
          // Preserve Flutter's ordinary emergency wrap when no linguistic
          // break fits, without inventing a visible hyphen.
          final plain = _ReaderProbeText(
            runs.slice(
              start,
              windowEnd,
              indentSpan: lineIndent,
              trailingHyphen: windowEnd == text.length && trailingHyphen,
            ),
            windowEnd - start,
            const [],
            lineIndent != null,
            windowEnd == text.length && trailingHyphen,
          );
          final plainPainter = probe.layout(plain.span, width);
          end =
              start +
              plain.toSource(
                _firstDisplayLineEnd(plainPainter, plain.displayLength),
              );
        }
      }
      if (end <= start) {
        end = start + text.substring(start).characters.first.length;
      }
      start = end;
    }

    // Final native shaping is authoritative. Contextual kerning or a font's
    // unusual hyphen metrics must never leave a discretionary glyph mid-line.
    // Keep the original span hierarchy here, not the flattened probe runs.
    // Removal is monotonic; unused opportunities never enter the painted span.
    while (selected.isNotEmpty) {
      final ordered = selected.toList()..sort();
      final finalText = _ReaderProbeText(
        TextSpan(
          children: _readerDisplayChildren(
            source,
            ordered,
            indentSpan,
            trailingHyphen,
            false,
            baseStyle,
          ),
        ),
        text.length,
        ordered,
        indentSpan != null,
        trailingHyphen,
      );
      final painter = probe.layout(finalText.span, width);
      final ends = _displayLineEnds(painter, finalText.displayLength).toSet();
      final previousLength = selected.length;
      selected.removeWhere(
        (point) => !ends.contains(finalText.toDisplay(point)),
      );
      if (selected.length == previousLength) break;
    }
    return selected;
  } finally {
    probe.dispose();
  }
}

class _MappedTextSpan extends TextSpan {
  final List<int> sourceToDisplay;
  final List<int> displayToSource;

  const _MappedTextSpan(
    this.sourceToDisplay,
    this.displayToSource, {
    required super.children,
  });
}

_MappedTextSpan? _mappedSpan(InlineSpan span) {
  if (span is _MappedTextSpan) return span;
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      final mapped = _mappedSpan(child);
      if (mapped != null) return mapped;
    }
  }
  return null;
}

/// Converts an original paragraph UTF-16 offset to RenderParagraph coordinates.
/// A plain non-reader span is an identity mapping.
int readerDisplayOffset(InlineSpan span, int sourceOffset) {
  final mapped = _mappedSpan(span);
  return mapped == null
      ? sourceOffset
      : mapped.sourceToDisplay[sourceOffset.clamp(
          0,
          mapped.sourceToDisplay.length - 1,
        )];
}

/// Converts a RenderParagraph caret/hit-test offset back to original UTF-16.
int readerSourceOffset(InlineSpan span, int displayOffset) {
  final mapped = _mappedSpan(span);
  return mapped == null
      ? displayOffset
      : mapped.displayToSource[displayOffset.clamp(
          0,
          mapped.displayToSource.length - 1,
        )];
}

/// Applies reader colors at paint time without changing the parsed author
/// structure, text metrics, or logical offsets. Link ranges remain source based.
InlineSpan applyReaderPalette(
  InlineSpan span,
  int startOffset,
  Color textColor,
  Color linkColor,
  List<(int, int)> links,
) {
  if (span is! TextSpan) return span;
  final text = span.text ?? '';
  final end = startOffset + text.length;
  final boundaries = <int>{startOffset, end};
  for (final link in links) {
    if (link.$1 < end && link.$2 > startOffset) {
      boundaries.add(link.$1.clamp(startOffset, end));
      boundaries.add(link.$2.clamp(startOffset, end));
    }
  }
  final ordered = boundaries.toList()..sort();
  final children = <InlineSpan>[];
  for (var index = 0; index + 1 < ordered.length; index++) {
    final start = ordered[index];
    final finish = ordered[index + 1];
    final linked = links.any((link) => link.$1 <= start && link.$2 >= finish);
    children.add(
      TextSpan(
        text: text.substring(start - startOffset, finish - startOffset),
        style: TextStyle(color: linked ? linkColor : textColor),
      ),
    );
  }
  var cursor = end;
  for (final child in span.children ?? const <InlineSpan>[]) {
    children.add(
      applyReaderPalette(child, cursor, textColor, linkColor, links),
    );
    cursor += child.toPlainText(includeSemanticsLabels: false).length;
  }
  return TextSpan(
    style: span.style?.copyWith(color: textColor),
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    locale: span.locale,
    spellOut: span.spellOut,
    children: children,
  );
}
