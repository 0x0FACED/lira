import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:epub_engine/src/epub_images.dart';
import 'package:epub_engine/src/epub_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _baseStyle = TextStyle(fontSize: 16, fontFamily: 'Reader choice');

void main() {
  test('external SVG raster covers resolve from the SVG, not the chapter', () {
    final intended = Uint8List.fromList([1, 2, 3]);
    final decoy = Uint8List.fromList([9, 8, 7]);
    final resolver = _resolver({
      'OPS/images/cover.svg': _svg('''
        <svg xmlns="http://www.w3.org/2000/svg"
             xmlns:book="http://www.w3.org/1999/xlink"
             viewBox="0 0 300 500">
          <image book:href="raster/cover.png" width="300" height="500"/>
        </svg>
      '''),
      'OPS/images/raster/cover.png': intended,
      'OPS/Text/raster/cover.png': decoy,
      'Other/images/raster/cover.png': decoy,
    });

    final result = resolver.resolve(
      '../images/cover.svg',
      documentPath: 'OPS/Text/chapter.xhtml',
    )!;

    expect(result.isSvg, isFalse);
    expect(identical(result.bytes, intended), isTrue);
    expect(result.aspectRatio, closeTo(0.6, 0.000001));
  });

  test('nested simple cover wrappers reuse the original raster bytes', () {
    final intended = Uint8List.fromList([1, 2, 3]);
    final resolver = _resolver({
      'OPS/art/outer.svg': _svg('''
        <svg viewBox="0 0 10 20">
          <image href="nested/inner.svg" width="10" height="20"/>
        </svg>
      '''),
      'OPS/art/nested/inner.svg': _svg('''
        <svg viewBox="0 0 10 20">
          <image href="../raster/cover.png" width="10" height="20"/>
        </svg>
      '''),
      'OPS/art/raster/cover.png': intended,
      'OPS/Text/raster/cover.png': Uint8List.fromList([9]),
    });

    final result = resolver.resolve(
      '../art/outer.svg',
      documentPath: 'OPS/Text/c.xhtml',
    )!;
    expect(result.isSvg, isFalse);
    expect(identical(result.bytes, intended), isTrue);
  });

  test(
    'data, encoded local paths and element attributes select real resources',
    () {
      final intended = Uint8List.fromList([1, 2, 3]);
      final resolver = _resolver({
        'OPS/art/cover%20.png': intended,
        'OPS/art/cover .png': Uint8List.fromList([9]),
        'elsewhere/cover%20.png': Uint8List.fromList([8]),
      });
      final document = html_parser.parse('''
      <img src="" data-src="../art/cover%2520.png?v=1#image">
      <object data="../art/cover%2520.png"></object>
      <svg><image xlink:href="../art/cover%2520.png"/></svg>
    ''');
      for (final element in document.querySelectorAll('img, object, image')) {
        expect(
          identical(
            resolver
                .resolveElement(element, documentPath: 'OPS/Text/c.xhtml')!
                .bytes,
            intended,
          ),
          isTrue,
        );
      }
      expect(
        resolver
            .resolve('data:image/png;base64,AQID', documentPath: 'OPS/c.xhtml')!
            .bytes,
        orderedEquals(intended),
      );
      expect(
        resolver.resolve('cover%2520.png', documentPath: 'OPS/Text/c.xhtml'),
        isNull,
      );
      expect(
        resolver.resolve(
          'https://example.com/cover.png',
          documentPath: 'OPS/c.xhtml',
        ),
        isNull,
      );
      expect(
        resolver.resolve(
          '//example.com/cover.png',
          documentPath: 'OPS/c.xhtml',
        ),
        isNull,
      );
    },
  );

  test(
    'SVG dimensions supply aspect ratios without decoding raster pixels',
    () {
      final resolver = _resolver({
        'OPS/numeric.svg': _svg(
          '<svg width="120px" height="80" viewBox="0 0 1 4"/>',
        ),
        'OPS/viewbox.svg': _svg(
          '<svg width="100%" height="100%" viewBox="-5 -2 90 30"/>',
        ),
        'OPS/invalid.svg': _svg(
          '<svg width="0" height="40" viewBox="0 0 0 4"/>',
        ),
        'OPS/raster.png': Uint8List.fromList([1, 2, 3]),
      });
      expect(
        resolver
            .resolve('numeric.svg', documentPath: 'OPS/c.xhtml')!
            .aspectRatio,
        1.5,
      );
      expect(
        resolver
            .resolve('viewbox.svg', documentPath: 'OPS/c.xhtml')!
            .aspectRatio,
        3,
      );
      expect(
        resolver
            .resolve('invalid.svg', documentPath: 'OPS/c.xhtml')!
            .aspectRatio,
        isNull,
      );
      expect(
        resolver
            .resolve('raster.png', documentPath: 'OPS/c.xhtml')!
            .aspectRatio,
        isNull,
      );
    },
  );

  test(
    'cycles and malformed archive SVGs explicitly reject and do not poison later loads',
    () {
      final raster = Uint8List.fromList([1, 2, 3]);
      final resolver = _resolver({
        'OPS/a.svg': _svg('<svg><image href="nested/b.svg"/></svg>'),
        'OPS/nested/b.svg': _svg('<svg><image href="../a.svg"/></svg>'),
        'OPS/broken.svg': _svg('<svg><g></svg>'),
        'OPS/missing-child.svg': _svg('<svg><image href="absent.png"/></svg>'),
        'OPS/raster.png': raster,
      });
      for (final source in [
        'a.svg',
        'a.svg',
        'broken.svg',
        'missing-child.svg',
      ]) {
        expect(
          () => resolver.resolve(source, documentPath: 'OPS/c.xhtml'),
          throwsFormatException,
        );
      }
      expect(
        resolver.resolve('absent.svg', documentPath: 'OPS/c.xhtml'),
        isNull,
      );
      expect(
        identical(
          resolver.resolve('raster.png', documentPath: 'OPS/c.xhtml')!.bytes,
          raster,
        ),
        isTrue,
      );
      final document = html_parser.parse('<svg><image href="a.svg"/></svg>');
      final styles = _styles(document);
      final svg = document.querySelector('svg')!;
      expect(
        () => resolver.inlineSvg(
          svg,
          styles: styles,
          style: _styleFor(styles, svg),
          documentPath: 'OPS/c.xhtml',
        ),
        throwsFormatException,
      );
    },
  );

  for (final hiddenMarkup in [
    '<g class="hidden"><image href="red.png" width="40" height="40"/></g>',
    '<image class="hidden" href="red.png" width="40" height="40"/>',
  ]) {
    testWidgets('chapter CSS hides raster cover descendants: $hiddenMarkup', (
      tester,
    ) async {
      final raster = await _png(tester, const Color(0xFFFF0000));
      final resolver = _resolver({'OPS/red.png': raster});
      final document = html_parser.parse('''
        <link rel="stylesheet" href="styles/chapter.css">
        <svg width="40" height="40" viewBox="0 0 40 40">$hiddenMarkup</svg>
      ''');
      final styles = _styles(
        document,
        stylesheets: const {
          'OPS/styles/chapter.css': '.hidden { display: none; }',
        },
      );
      final svg = document.querySelector('svg')!;
      final result = resolver.inlineSvg(
        svg,
        styles: styles,
        style: _styleFor(styles, svg),
        documentPath: 'OPS/c.xhtml',
      );

      expect(
        result.isSvg,
        isTrue,
        reason: 'A CSS-hidden raster is not a cover.',
      );
      final pixels = await _render(tester, result);
      expect(_pixel(pixels, 20, 20), [0, 0, 0, 0]);
      final visibleDocument = html_parser.parse('''
        <svg width="40" height="40" viewBox="0 0 40 40">
          <image href="red.png" width="40" height="40"/>
          <rect width="1" height="1" fill="red"/>
        </svg>
      ''');
      final visibleStyles = _styles(visibleDocument);
      final visibleSvg = visibleDocument.querySelector('svg')!;
      final visible = resolver.inlineSvg(
        visibleSvg,
        styles: visibleStyles,
        style: _styleFor(visibleStyles, visibleSvg),
        documentPath: 'OPS/c.xhtml',
      );
      expect(_pixel(await _render(tester, visible), 20, 20), [255, 0, 0, 255]);
    });
  }

  testWidgets('hidden descendants are removed from a visible vector image', (
    tester,
  ) async {
    final resolver = _resolver({
      'OPS/red.png': await _png(tester, const Color(0xFFFF0000)),
    });
    final document = html_parser.parse('''
      <style>.hidden { visibility: hidden; }</style>
      <svg width="40" height="40" viewBox="0 0 40 40">
        <rect width="20" height="40" fill="blue"/>
        <g class="hidden"><image href="red.png" width="40" height="40"/></g>
      </svg>
    ''');
    final styles = _styles(document);
    final svg = document.querySelector('svg')!;
    final result = resolver.inlineSvg(
      svg,
      styles: styles,
      style: _styleFor(styles, svg),
      documentPath: 'OPS/c.xhtml',
    );
    final pixels = await _render(tester, result);
    expect(_pixel(pixels, 10, 20), [0, 0, 255, 255]);
    expect(_pixel(pixels, 30, 20), [0, 0, 0, 0]);
  });

  testWidgets(
    'hidden external roots stay empty without following cyclic children',
    (tester) async {
      final resolver = _resolver({
        'OPS/hidden.svg': _svg('''
        <svg width="40" height="40" viewBox="0 0 40 40" class="hidden">
          <style>.hidden { display:none; }</style>
          <image href="hidden.svg" width="40" height="40"/>
        </svg>
      '''),
      });
      final result = resolver.resolve(
        'hidden.svg',
        documentPath: 'OPS/c.xhtml',
      )!;
      expect(result.isSvg, isTrue);
      expect(result.aspectRatio, 1);
      expect(_pixel(await _render(tester, result), 20, 20), [0, 0, 0, 0]);
    },
  );

  testWidgets(
    'external SVG imports hide cyclic descendants using their own CSS base',
    (tester) async {
      final resolver = EpubImageResolver(
        images: {
          'OPS/art/vector.svg': _svg('''
          <svg width="40" height="40" viewBox="0 0 40 40">
            <style>@import "../styles/vector.css";</style>
            <rect width="20" height="40" fill="blue"/>
            <g class="hidden"><image href="vector.svg" width="40" height="40"/></g>
          </svg>
        '''),
        },
        stylesheets: const {
          'OPS/styles/vector.css': '.hidden { display:none; }',
          'OPS/Text/styles/vector.css': '.hidden { display:block; }',
        },
        baseStyle: _baseStyle,
      );
      final image = resolver.resolve(
        '../art/vector.svg',
        documentPath: 'OPS/Text/c.xhtml',
      )!;
      final pixels = await _render(tester, image);
      expect(_pixel(pixels, 10, 20), [0, 0, 255, 255]);
      expect(_pixel(pixels, 30, 20), [0, 0, 0, 0]);
    },
  );

  testWidgets('transformed single-raster SVGs are not flattened into covers', (
    tester,
  ) async {
    final resolver = _resolver({
      'OPS/transformed.svg': _svg('''
        <svg width="40" height="40" viewBox="0 0 40 40">
          <g transform="translate(20 0)">
            <image href="red.png" width="40" height="40"/>
          </g>
        </svg>
      '''),
      'OPS/red.png': await _png(tester, const Color(0xFFFF0000)),
    });
    final image = resolver.resolve(
      'transformed.svg',
      documentPath: 'OPS/c.xhtml',
    )!;
    expect(image.isSvg, isTrue);
    final pixels = await _render(tester, image);
    expect(_pixel(pixels, 10, 20), [0, 0, 0, 0]);
    expect(_pixel(pixels, 30, 20), [255, 0, 0, 255]);
  });

  testWidgets('vector gradient and clip-path casing survives serialization', (
    tester,
  ) async {
    final resolver = _resolver({
      'OPS/vector.svg': _svg('''
        <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
          <defs>
            <linearGradient id="shade" x1="0%" x2="100%">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
            <clipPath id="half"><rect width="20" height="40"/></clipPath>
          </defs>
          <rect width="40" height="40" fill="url(#shade)" clip-path="url(#half)"/>
        </svg>
      '''),
    });
    final result = resolver.resolve('vector.svg', documentPath: 'OPS/c.xhtml')!;
    final pixels = await _render(tester, result);
    final left = _pixel(pixels, 5, 20);
    final middle = _pixel(pixels, 15, 20);
    expect(left[0], greaterThan(left[2]));
    expect(middle[2], greaterThan(left[2]));
    expect(left[3], 255);
    expect(_pixel(pixels, 30, 20), [0, 0, 0, 0]);
  });

  testWidgets(
    'general external vectors embed rasters from their own archive directory',
    (tester) async {
      final intended = await _png(tester, const Color(0xFFFF0000));
      final resolver = _resolver({
        'OPS/art/vector.svg': _svg('''
        <svg width="40" height="40" viewBox="0 0 40 40">
          <image href="raster/pixel.png" x="20" width="20" height="40" preserveAspectRatio="none"/>
          <rect width="20" height="40" fill="blue"/>
        </svg>
      '''),
        'OPS/art/raster/pixel.png': intended,
        'OPS/Text/raster/pixel.png': await _png(tester, Colors.green),
      });
      final result = resolver.resolve(
        '../art/vector.svg',
        documentPath: 'OPS/Text/c.xhtml',
      )!;
      expect(result.isSvg, isTrue);
      final pixels = await _render(tester, result);
      expect(_pixel(pixels, 10, 20), [0, 0, 255, 255]);
      expect(_pixel(pixels, 30, 20), [255, 0, 0, 255]);
    },
  );

  for (final aspect in ['none', 'xMinYMin meet', 'xMidYMid slice']) {
    testWidgets('nested vectors preserve image viewport and IDs: $aspect', (
      tester,
    ) async {
      final resolver = _resolver({
        'OPS/art/outer.svg': _svg('''
          <svg width="40" height="40" viewBox="0 0 40 40">
            <defs>
              <linearGradient id="paint">
                <stop offset="0" stop-color="#00ff00"/>
                <stop offset="1" stop-color="#00ff00"/>
              </linearGradient>
              <clipPath id="edge"><rect width="40" height="10"/></clipPath>
            </defs>
            <rect width="40" height="10" fill="url(#paint)" clip-path="url(#edge)"/>
            <image href="nested/inner.svg" x="10" y="10" width="20" height="20"
                   preserveAspectRatio="$aspect"/>
          </svg>
        '''),
        'OPS/art/nested/inner.svg': _svg('''
          <svg width="10" height="20" viewBox="0 0 10 20">
            <defs>
              <linearGradient id="paint">
                <stop offset="0" stop-color="red"/>
                <stop offset="1" stop-color="red"/>
              </linearGradient>
              <clipPath id="edge"><rect width="5" height="20"/></clipPath>
            </defs>
            <rect width="10" height="20" fill="url(#paint)"/>
            <rect width="10" height="20" fill="blue" clip-path="url(#edge)"/>
            <image href="../raster/pixel.png" x="5" width="5" height="20"
                   preserveAspectRatio="none"/>
            <rect width="10" height="5" fill="yellow"/>
          </svg>
        '''),
        'OPS/art/raster/pixel.png': await _png(tester, const Color(0xFFFF0000)),
        'OPS/art/nested/raster/pixel.png': await _png(tester, Colors.green),
        'OPS/Text/raster/pixel.png': await _png(tester, Colors.green),
      });
      final image = resolver.resolve(
        '../art/outer.svg',
        documentPath: 'OPS/Text/c.xhtml',
      )!;
      final pixels = await _render(tester, image);
      expect(_pixel(pixels, 20, 5), [0, 255, 0, 255]);
      expect(_pixel(pixels, 5, 20), [0, 0, 0, 0]);
      expect(_pixel(pixels, 35, 20), [0, 0, 0, 0]);
      expect(_pixel(pixels, 15, 35), [0, 0, 0, 0]);
      if (aspect == 'xMinYMin meet') {
        expect(_pixel(pixels, 12, 12), [255, 255, 0, 255]);
        expect(_pixel(pixels, 12, 20), [0, 0, 255, 255]);
        expect(_pixel(pixels, 18, 20), [255, 0, 0, 255]);
        expect(_pixel(pixels, 25, 20), [0, 0, 0, 0]);
      } else {
        expect(_pixel(pixels, 15, 20), [0, 0, 255, 255]);
        expect(_pixel(pixels, 25, 20), [255, 0, 0, 255]);
        expect(
          _pixel(pixels, 15, 12),
          aspect == 'none' ? [255, 255, 0, 255] : [0, 0, 255, 255],
        );
      }
    });
  }

  testWidgets(
    'data SVG references use the containing document as their archive base',
    (tester) async {
      final resolver = _resolver({
        'OPS/art/red.png': await _png(tester, const Color(0xFFFF0000)),
      });
      final source = Uri.dataFromString('''
      <svg width="40" height="40" viewBox="0 0 40 40">
        <image href="red.png" width="40" height="40"/>
        <rect width="1" height="1" fill="blue"/>
      </svg>
    ''', mimeType: 'image/svg+xml').toString();
      final result = resolver.resolve(
        source,
        documentPath: 'OPS/art/container.svg',
      )!;
      expect(_pixel(await _render(tester, result), 20, 20), [255, 0, 0, 255]);
    },
  );
}

EpubImageResolver _resolver(Map<String, Uint8List> images) => EpubImageResolver(
  images: images,
  stylesheets: const {},
  baseStyle: _baseStyle,
);

Uint8List _svg(String source) => utf8.encode(source);

EpubStyleResolver _styles(
  dom.Document document, {
  Map<String, String> stylesheets = const {},
}) => EpubStyleResolver(
  document: document,
  documentPath: 'OPS/c.xhtml',
  stylesheets: stylesheets,
  baseStyle: _baseStyle,
);

EpubStyle _styleFor(EpubStyleResolver styles, dom.Element element) =>
    styles.resolve(
      element,
      element.parent == null ? styles.root : _styleFor(styles, element.parent!),
    );

Future<Uint8List> _png(WidgetTester tester, Color color) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = color);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
    }))!;

Future<ByteData> _render(WidgetTester tester, EpubImage image) async =>
    (await tester.runAsync(() async {
      final picture = await vg.loadPicture(SvgBytesLoader(image.bytes), null);
      final rendered = await picture.picture.toImage(40, 40);
      try {
        return await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        rendered.dispose();
        picture.picture.dispose();
      }
    }))!;

List<int> _pixel(ByteData pixels, int x, int y) {
  final offset = (y * 40 + x) * 4;
  return List<int>.generate(4, (channel) => pixels.getUint8(offset + channel));
}
