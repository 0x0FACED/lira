import 'package:epub_engine/src/epub_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

void main() {
  const baseStyle = TextStyle(
    fontSize: 20,
    height: 1.5,
    fontFamily: 'Reader choice',
  );

  test(
    'external Hulinomika title classes style nested paragraphs and notes',
    () {
      final document = html_parser.parse('''
      <head><link rel="stylesheet" href="../Styles/book%20styles.css?v=2#main"></head>
      <body>
        <div class="title1"><p id="title">Хулиномика</p></div>
        <p>Сноска<a class="a" id="note">1</a></p>
      </body>
    ''');
      final resolver = EpubStyleResolver(
        document: document,
        documentPath: 'OEBPS/Text/chapter.xhtml',
        stylesheets: const {
          'OEBPS/Styles/book styles.css': '''
          div.title1 { font-size: 2em; font-weight: bold; text-align: center; margin: 1em 0; }
          a.a { vertical-align: super; text-decoration: none; }
          p { font-family: publisher-font; }
        ''',
          'Other/Styles/book styles.css': 'p { font-size: 99px; }',
        },
        baseStyle: baseStyle,
      );

      final title = _styleFor(resolver, document.querySelector('#title')!);
      expect(title.textStyle.fontSize, 40);
      expect(title.textStyle.fontWeight, FontWeight.bold);
      expect(title.textStyle.fontFamily, 'Reader choice');
      expect(title.textAlign, TextAlign.center);
      expect(
        title.margin,
        isNull,
        reason: 'Parent margins must not become paragraph margins.',
      );
      final note = _styleFor(resolver, document.querySelector('#note')!);
      expect(note.textStyle.fontSize, 15);
      expect(note.textStyle.fontFeatures, [const FontFeature.superscripts()]);
    },
  );

  test(
    'superscript preserves explicit sizing and does not repeat semantic scaling',
    () {
      final document = html_parser.parse('''
      <style>
        .note { font-size: .7em; vertical-align: super; }
        sup, sub { vertical-align: super; }
      </style>
      <p><a class="note">1</a><sup>2</sup><sub>3</sub></p>
    ''');
      final resolver = _resolver(document, const TextStyle(fontSize: 16));
      final note = _styleFor(resolver, document.querySelector('.note')!);
      expect(note.textStyle.fontSize, closeTo(11.2, 0.0001));
      expect(note.textStyle.fontFeatures, [const FontFeature.superscripts()]);
      for (final tag in ['sup', 'sub']) {
        final element = document.querySelector(tag)!;
        final parent = _styleFor(resolver, element.parent!);
        final style = resolver.resolve(
          element,
          parent,
          defaultTextStyle: parent.textStyle.copyWith(
            fontSize: 12,
            fontFeatures: [
              if (tag == 'sup')
                const FontFeature.superscripts()
              else
                const FontFeature.subscripts(),
            ],
          ),
        );
        expect(style.textStyle.fontSize, 12);
        expect(style.textStyle.fontFeatures, [
          const FontFeature.superscripts(),
        ]);
      }
    },
  );

  test(
    'specificity uses only matching selectors and is independent of source order',
    () {
      final document = html_parser.parse('''
      <style>
        #target { font-size: 31px; }
        div p.a.b.c { font-size: 26px; }
        #absent, p.a { font-weight: bold; }
        p.a.b { font-weight: normal; }
      </style>
      <div><p id="target" class="a b c">Text</p></div>
    ''');
      final resolver = _resolver(document, baseStyle);
      final style = _styleFor(resolver, document.querySelector('#target')!);
      expect(style.textStyle.fontSize, 31);
      expect(style.textStyle.fontWeight, FontWeight.normal);
    },
  );

  test(
    'important beats normal inline, while important inline wins author rules',
    () {
      final document = html_parser.parse('''
      <style>
        #target { font-size: 24px !important; font-weight: bold !important; }
        p { font-size: 50px; }
      </style>
      <p id="target" style="font-size: 18px; font-weight: normal !important">Text</p>
    ''');
      final style = _styleFor(
        _resolver(document, baseStyle),
        document.querySelector('p')!,
      );
      expect(style.textStyle.fontSize, 24);
      expect(style.textStyle.fontWeight, FontWeight.normal);
    },
  );

  test(
    'linked and inline sheets follow document order, then inline attributes',
    () {
      final document = html_parser.parse('''
      <link rel="stylesheet" href="first.css">
      <style>p { font-size: 24px; font-style: italic; }</style>
      <link rel="stylesheet" href="last.css">
      <p id="sheet">Sheet order</p>
      <p id="inline" style="font-size: 29px; font-style: normal">Inline order</p>
    ''');
      final resolver = _resolver(
        document,
        baseStyle,
        stylesheets: const {
          'OPS/first.css': 'p { font-size: 21px; font-style: normal; }',
          'OPS/last.css': 'p { font-size: 27px; }',
        },
      );
      final sheet = _styleFor(resolver, document.querySelector('#sheet')!);
      expect(sheet.textStyle.fontSize, 27);
      expect(sheet.textStyle.fontStyle, FontStyle.italic);
      final inline = _styleFor(resolver, document.querySelector('#inline')!);
      expect(inline.textStyle.fontSize, 29);
      expect(inline.textStyle.fontStyle, FontStyle.normal);
    },
  );

  test('local imports resolve from their own sheets and cycles terminate', () {
    final document = html_parser.parse('''
      <link rel="stylesheet" href="styles/book.css">
      <p id="text">Imported text</p>
    ''');
    final resolver = _resolver(
      document,
      baseStyle,
      stylesheets: const {
        'OPS/styles/book.css': '''
        @import "../shared/base.css";
        @import url("https://example.com/remote.css");
        p { font-size: 25px; }
      ''',
        'OPS/shared/base.css': '''
        @import "../styles/book.css";
        @import url("detail.css");
        p { font-size: 22px; font-weight: bold; }
      ''',
        'OPS/shared/detail.css': 'p { font-style: italic; }',
        'https://example.com/remote.css': 'p { font-size: 99px !important; }',
      },
    );
    final style = _styleFor(resolver, document.querySelector('p')!);
    expect(style.textStyle.fontSize, 25);
    expect(style.textStyle.fontWeight, FontWeight.bold);
    expect(style.textStyle.fontStyle, FontStyle.italic);
  });

  test(
    'repeated imports participate at each source location after cycle recovery',
    () {
      final document = html_parser.parse('''
      <link rel="stylesheet" href="one.css">
      <style>p { font-size: 23px; }</style>
      <link rel="stylesheet" href="two.css">
      <p>Repeated import</p>
    ''');
      final resolver = _resolver(
        document,
        baseStyle,
        stylesheets: const {
          'OPS/one.css': '@import "shared.css";',
          'OPS/two.css': '@import "shared.css";',
          'OPS/shared.css': 'p { font-size: 28px; }',
        },
      );
      expect(
        _styleFor(resolver, document.querySelector('p')!).textStyle.fontSize,
        28,
      );
    },
  );

  test('child selectors do not match deeper descendants', () {
    final document = html_parser.parse('''
      <style>
        .section p { font-size: 22px; }
        .section > p { font-size: 30px; }
      </style>
      <div class="section">
        <p id="direct">Direct</p><div><p id="nested">Nested</p></div>
      </div>
    ''');
    final resolver = _resolver(document, baseStyle);
    expect(
      _styleFor(
        resolver,
        document.querySelector('#direct')!,
      ).textStyle.fontSize,
      30,
    );
    expect(
      _styleFor(
        resolver,
        document.querySelector('#nested')!,
      ).textStyle.fontSize,
      22,
    );
  });

  test('display none and visibility hidden mark the entire subtree hidden', () {
    final document = html_parser.parse('''
      <style>
        .removed { display: none; }
        .invisible { visibility: hidden; }
        .visible { visibility: visible; }
      </style>
      <div class="removed"><p id="removed">Must not render</p></div>
      <p class="invisible" id="invisible">Also hidden</p>
      <p class="visible" id="visible">Visible</p>
    ''');
    final resolver = _resolver(document, baseStyle);
    expect(
      _styleFor(resolver, document.querySelector('#removed')!).hidden,
      isTrue,
    );
    expect(
      _styleFor(resolver, document.querySelector('#invisible')!).hidden,
      isTrue,
    );
    expect(
      _styleFor(resolver, document.querySelector('#visible')!).hidden,
      isFalse,
    );
  });

  test('margins and display do not inherit, typography and alignment do', () {
    final document = html_parser.parse('''
      <style>
        div { display: block; margin: 10px 20px 30px 40px; text-align: right; font-style: italic; }
      </style>
      <div id="parent"><p id="child">Text</p></div>
    ''');
    final resolver = _resolver(document, baseStyle);
    final parent = _styleFor(resolver, document.querySelector('#parent')!);
    expect(parent.margin, const EdgeInsets.fromLTRB(40, 10, 20, 30));
    expect(parent.display, 'block');
    final child = _styleFor(resolver, document.querySelector('#child')!);
    expect(child.margin, isNull);
    expect(child.display, isNull);
    expect(child.textAlign, TextAlign.right);
    expect(child.textStyle.fontStyle, FontStyle.italic);
  });

  test(
    'margin shorthand and longhands compete per side with important priority',
    () {
      final document = html_parser.parse('''
      <style>
        #target { margin-left: 2px; margin-bottom: 1px !important; }
        p { margin: 3px 4px 5px !important; margin-top: 6px !important; }
      </style>
      <p id="target">Text</p>
    ''');
      final style = _styleFor(
        _resolver(document, baseStyle),
        document.querySelector('p')!,
      );
      expect(style.margin, const EdgeInsets.fromLTRB(4, 6, 4, 1));
    },
  );

  test(
    'legacy font attributes retain inherited scaling and author CSS precedence',
    () {
      final document = html_parser.parse('''
      <style>#author { font-size: 25px; color: blue; font-family: publisher; }</style>
      <p>
        <font id="legacy" size="6" color="#f00" face="publisher">
          Larger red <font id="nested" size="1.5">nested</font>
        </font>
        <font id="author" size="6" color="red">Author override</font>
        <font id="inline" size="6" color="red" style="font-size: 18px; color: #123;">Inline override</font>
      </p>
    ''');
      final resolver = _resolver(document, baseStyle);
      final legacy = _styleFor(resolver, document.querySelector('#legacy')!);
      expect(legacy.textStyle.fontSize, 40);
      expect(legacy.textStyle.color, const Color(0xFFFF0000));
      expect(legacy.textStyle.fontFamily, 'Reader choice');
      final nested = _styleFor(resolver, document.querySelector('#nested')!);
      expect(nested.textStyle.fontSize, 20);
      expect(nested.textStyle.color, const Color(0xFFFF0000));
      final author = _styleFor(resolver, document.querySelector('#author')!);
      expect(author.textStyle.fontSize, 25);
      expect(author.textStyle.color, const Color(0xFF0000FF));
      final inline = _styleFor(resolver, document.querySelector('#inline')!);
      expect(inline.textStyle.fontSize, 18);
      expect(inline.textStyle.color, const Color(0xFF112233));
    },
  );

  test(
    'author styles override semantic defaults without replacing the reader font',
    () {
      final document = html_parser.parse('''
      <style>strong { font-weight: normal; font-family: publisher; }</style>
      <p><strong>Not bold</strong></p>
    ''');
      final resolver = _resolver(document, baseStyle);
      final element = document.querySelector('strong')!;
      final parent = _styleFor(resolver, element.parent!);
      final style = resolver.resolve(
        element,
        parent,
        defaultTextStyle: parent.textStyle.copyWith(
          fontWeight: FontWeight.bold,
        ),
      );
      expect(style.textStyle.fontWeight, FontWeight.normal);
      expect(style.textStyle.fontFamily, 'Reader choice');
    },
  );

  test(
    'relative sizes use parent and root sizes, and absolute line height inherits',
    () {
      final document = html_parser.parse('''
      <style>
        html { font-size: 25px; }
        div { font-size: 2em; line-height: 60px; }
        p { font-size: 1rem; }
        span { font-size: 80%; line-height: 2; }
      </style>
      <div><p id="paragraph">Text <span id="small">small</span></p></div>
    ''');
      final resolver = _resolver(document, baseStyle);
      final paragraph = _styleFor(
        resolver,
        document.querySelector('#paragraph')!,
      );
      expect(paragraph.textStyle.fontSize, 25);
      expect(paragraph.textStyle.height, 60 / 25);
      final small = _styleFor(resolver, document.querySelector('#small')!);
      expect(small.textStyle.fontSize, 20);
      expect(small.textStyle.height, 2);
    },
  );

  test(
    'reader-screen styles apply but print, alternate and remote sheets do not',
    () {
      final document = html_parser.parse('''
      <link rel="stylesheet" href="screen.css" media="screen">
      <link rel="stylesheet" href="print.css" media="print">
      <link rel="alternate stylesheet" href="alternate.css">
      <link rel="stylesheet" href="https://example.com/book.css">
      <style>
        @media screen { p { font-style: italic; } }
        @media print { p { font-size: 90px; } }
      </style>
      <p>Text</p>
    ''');
      final resolver = _resolver(
        document,
        baseStyle,
        stylesheets: const {
          'OPS/screen.css': 'p { font-size: 23px; }',
          'OPS/print.css': 'p { font-size: 99px; }',
          'OPS/alternate.css': 'p { font-size: 98px; }',
          'https://example.com/book.css': 'p { font-size: 97px; }',
        },
      );
      final style = _styleFor(resolver, document.querySelector('p')!);
      expect(style.textStyle.fontSize, 23);
      expect(style.textStyle.fontStyle, FontStyle.italic);
    },
  );

  test(
    'invalid and unsupported values do not hide earlier valid declarations',
    () {
      final document = html_parser.parse('''
      <style>
        p { font-size: 24px; font-size: bogus; text-align: center; text-align: bogus; }
        p:hover { font-size: 99px; }
      </style>
      <p style="text-decoration: underline line-through; color: #123;">Text</p>
    ''');
      final style = _styleFor(
        _resolver(document, baseStyle),
        document.querySelector('p')!,
      );
      expect(style.textStyle.fontSize, 24);
      expect(style.textAlign, TextAlign.center);
      expect(
        style.textStyle.decoration,
        TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]),
      );
      expect(style.textStyle.color, const Color(0xFF112233));
    },
  );
  test('relative font weights follow inherited numeric weight boundaries', () {
    final document = html_parser.parse('''
      <div style="font-weight:500"><span id="medium" style="font-weight:bolder">Medium</span></div>
      <div style="font-weight:600">
        <span id="bold" style="font-weight:bolder">Bold</span>
        <span id="light" style="font-weight:lighter">Light</span>
      </div>
      <div style="font-weight:800"><span id="heavy" style="font-weight:lighter">Heavy</span></div>
    ''');
    final resolver = _resolver(document, baseStyle);
    expect(
      _styleFor(
        resolver,
        document.querySelector('#medium')!,
      ).textStyle.fontWeight,
      FontWeight.w700,
    );
    expect(
      _styleFor(
        resolver,
        document.querySelector('#bold')!,
      ).textStyle.fontWeight,
      FontWeight.w900,
    );
    expect(
      _styleFor(
        resolver,
        document.querySelector('#light')!,
      ).textStyle.fontWeight,
      FontWeight.w400,
    );
    expect(
      _styleFor(
        resolver,
        document.querySelector('#heavy')!,
      ).textStyle.fontWeight,
      FontWeight.w700,
    );
  });
}

EpubStyleResolver _resolver(
  dom.Document document,
  TextStyle baseStyle, {
  Map<String, String> stylesheets = const {},
}) => EpubStyleResolver(
  document: document,
  documentPath: 'OPS/chapter.xhtml',
  stylesheets: stylesheets,
  baseStyle: baseStyle,
);

EpubStyle _styleFor(EpubStyleResolver resolver, dom.Element element) {
  final parent = element.parent;
  return resolver.resolve(
    element,
    parent == null ? resolver.root : _styleFor(resolver, parent),
  );
}
