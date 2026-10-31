# epub_engine

Native Flutter EPUB rendering for Lira. No WebView or embedded JavaScript; EPUB container parsing uses ZIP/XML directly.

## Content and rendering

`EpubParser.parse(bytes)` reads ZIP/container/OPF, preserves spine reading order and builds a separate NCX/EPUB3 navigation tree. Spine documents are not filtered by filename. UTF-8 and UTF-16 text are decoded without silent replacement of malformed characters.

`XhtmlParser` produces styled text, image, table and divider blocks with character ranges, anchors and links. Valid XHTML and recovered HTML share one traversal. `EpubNativeView` renders them with native Flutter text selection:

- chapter-indexed vertical scrolling;
- measured horizontal pagination and optional two-page spreads, with finger-tracked cylindrical page curls, theme-aware paper/shadows and center-spine leaf turns;
- content-position restoration across mode, typography and viewport changes;
- overlapping highlights without modifying the original text;
- internal document/fragment navigation and external HTTP(S) links;
- inline raster/SVG images and SVG covers, with full document-relative resource paths rather than basename guesses;
- nested lists, explicit line breaks and separate quotation paragraphs;
- bordered table grids with row/column spans, row-group pagination and scrollable oversized rows;
- linked/inline local CSS, local imports and a bounded author cascade for typography, alignment, visibility and nonnegative paragraph margins.

This is a native block renderer, not a complete browser HTML/CSS implementation.

`ParsedEpub.images` and `stylesheets` are keyed by canonical archive paths. `XhtmlParser` needs the chapter's `documentPath` and the book's `stylesheets` when used directly. TOC `fileName` values are package-relative URI locators with escaped paths, whereas chapter `fileName` values are canonical archive paths.

CSS supports tag/class/id/universal, descendant and child selectors, specificity, source order and `!important`. Reader font family and line spacing override author `font-family`/`line-height`; absolute author font sizes scale with the reader size from a 16px CSS reference, preserving relative heading/footnote sizing. Remote resources, web fonts, floats/grid layout, negative/percentage margins and conditional media queries are not supported. SVG image references are resolved locally against each SVG's own document; nested vectors are inlined rather than passed to an unsupported SVG data-image decoder.

Tables use equal-width columns. Cells keep source-order text offsets for selection/highlights even with rowspans. Ordinary rows paginate together; a group taller than the viewport scrolls within its page. Image dimensions update table layout without losing the logical position.

Horizontal pagination packs images using their aspect ratio, content width, padding and full-page height cap rather than reserving a page per image. Unknown raster dimensions temporarily reserve the full height; decoding triggers anchored repagination. Paragraphs fill the current page's remaining space along measured line boundaries, preserving styled text, graphemes, hard breaks and UTF-16 offsets. Continuations keep horizontal margins/indentation but do not repeat paragraph top/bottom spacing. A retained terminal hard break can contribute an extra empty measured line; fitting headings stay together and oversized individual lines remain scrollable.

Pagination starts with the requested chapter and runs in slices with a 4 ms budget checked between measured pages. Only the current page/spread and two turns ahead are prepared; idle readers do not continue measuring the whole book. Missing earlier pages are loaded on backward navigation, and a turn waiting at an unmeasured boundary resumes once its destination is ready. Spreads also measure preceding chapters to retain canonical left/right parity. Reflow cancels obsolete callbacks; background insertions preserve logical position and mounted page identities, and pause during a curl. Chapter parsing and an individual native table/layout operation are not interruptible, so the budget is not a hard per-frame deadline.

Long paragraphs use adaptively sized source windows with measured line lookahead, rather than running hyphen selection over the entire paragraph before its first page. Linguistic break offsets survive width-only reflow; temporary measurement windows are discarded. Hyphen probes reuse one painter and sparse insertion-boundary mappings; full UTF-16 maps are allocated for actual presentations, not every candidate-width trial. Visible hyphens retain the preceding run's effective style even at an inline-style boundary.

Page margins are applied independently to each page in a spread and shared by measurement and drawing. Oversized saved margins clamp to preserve at least 160 logical pixels of content, or the whole viewport when narrower, without rewriting the saved preference.

Reader typography includes first-line indent and paragraph spacing in em, font weight, paragraph alignment and optional language-aware EN/RU Liang hyphenation with bundled licensed TeX patterns (`LICENSE.hyphenation`). Language inherits from package metadata through XHTML and inline language attributes; absent/unsupported languages are not guessed. Headings, lists and preformatted blocks retain their structural layout. Continued paragraph pages do not repeat the first-line indent.

First-line indentation reserves a transparent glyph's native advance, with a one-pixel-high run and no tracking. Do not replace this with leading `letterSpacing`: SkParagraph's justification can then paint the first line beyond the content edge despite a seemingly correct starting caret. Source/display mapping still adds only one display unit. App regressions load the actual Lora, Literata, Inter and PT Serif fonts and check every visible glyph's bounds in both reading modes.

`ReaderSettings` resolves independent page/text/link/selection colors and text contrast. Palette/contrast changes repaint cached spans without reparsing XHTML or invalidating pagination; extra software dimming belongs to the application overlay and does not change engine geometry. Typography changes retain source UTF-16 positions during reflow.

Horizontal turns follow touch/stylus drags and settle or roll back on release. Edge taps, keyboard and trackpad navigation use the same animation; system reduced motion switches immediately. Progress is published only for completed turns, and navigation/reflow cancels an unfinished preview. Native long-press/mouse selection and vertical scrolling inside oversized pages remain available. Viewport snapshots are captured once per turn (an additional destination snapshot for spreads), capped at 2× pixel ratio; animation frames repaint cached images rather than rebuilding text.


## Locations

`initialLocation` is an opening seed. Use `EpubNativeViewState.goToLocation` or `scrollToChapter` for later navigation.

`EpubLocation` serializes an application-specific JSON locator. Despite its historical `EpubCfi` class name, it is not a standard EPUB CFI string. New renderer positions include `v:2` and an exact parsed-content UTF-16 offset. Legacy JSON remains readable; `hasExactCharOffset` must be explicit when constructing an exact offset programmatically.

The renderer captures the current logical text position before layout invalidation. Horizontal mode shows a themed loading indicator until the target page/spread is measured, never chapter zero as a provisional destination; loading does not publish reading progress. Vertical lists initialize at the measured target before their first paint. A page number or previous pixel offset is not the primary reflow anchor. Selection ranges use start-inclusive/end-exclusive text offsets.

Display-only indent/discretionary-hyphen insertions never enter stored coordinates or copied text. Geometry consumers must map source offsets with `readerDisplayOffset(span, sourceOffset)` before querying a `RenderParagraph`, and map display positions back with `readerSourceOffset(span, displayOffset)`. Default `toPlainText()` returns source text through empty insertion semantics labels; `includeSemanticsLabels: false` exposes layout text.

Restoring previously omitted images or correcting generated list markers changes offsets after those elements. Existing exact positions/highlights from the incomplete rendering may shift; their locator does not contain the old parsing revision or source quotation needed for unambiguous migration.


## Verification

From the Lira repository root:

```bash
flutter test packages/epub_engine/test
flutter test test/reader_justification_test.dart

dart --packages=.dart_tool/package_config.json \
  packages/epub_engine/bin/debug_epub_parser.dart path/to/book.epub
```

See the repository's `READER.md` for the shared screen, persistence lifecycle and PDF integration.
