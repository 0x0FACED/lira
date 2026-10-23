# epub_engine

Native Flutter EPUB rendering for Lira. No WebView or embedded JavaScript; EPUB container parsing uses ZIP/XML directly.

## Content and rendering

`EpubParser.parse(bytes)` reads ZIP/container/OPF, preserves spine reading order and builds a separate NCX/EPUB3 navigation tree. Spine documents are not filtered by filename. UTF-8 and UTF-16 text are decoded without silent replacement of malformed characters.

`XhtmlParser` produces styled text, image, table and divider blocks with character ranges, anchors and links. Valid XHTML and recovered HTML share one traversal. `EpubNativeView` renders them with native Flutter text selection:

- chapter-indexed vertical scrolling;
- measured horizontal pagination and optional two-page spreads;
- content-position restoration across mode, typography and viewport changes;
- overlapping highlights without modifying the original text;
- internal document/fragment navigation and external HTTP(S) links;
- inline raster/SVG images and SVG covers, with full document-relative resource paths rather than basename guesses;
- nested lists, explicit line breaks and separate quotation paragraphs;
- bordered table grids with row/column spans, row-group pagination and scrollable oversized rows;
- linked/inline local CSS, local imports and a bounded author cascade for typography, alignment, visibility and nonnegative paragraph margins.

This is a native block renderer, not a complete browser HTML/CSS implementation.

`ParsedEpub.images` and `stylesheets` are keyed by canonical archive paths. `XhtmlParser` needs the chapter's `documentPath` and the book's `stylesheets` when used directly. TOC `fileName` values are package-relative URI locators with escaped paths, whereas chapter `fileName` values are canonical archive paths.

CSS supports tag/class/id/universal, descendant and child selectors, specificity, source order and `!important`. The reader keeps the user's font family; remote resources, web fonts, floats/grid layout, negative/percentage margins and conditional media queries are not supported. SVG image references are resolved locally against each SVG's own document; nested vectors are inlined rather than passed to an unsupported SVG data-image decoder.

Tables use equal-width columns. Cells keep source-order text offsets for selection/highlights even with rowspans. Ordinary rows paginate together; a group taller than the viewport scrolls within its page. Image dimensions update table layout without losing the logical position.


## Locations

`initialLocation` is an opening seed. Use `EpubNativeViewState.goToLocation` or `scrollToChapter` for later navigation.

`EpubLocation` serializes an application-specific JSON locator. Despite its historical `EpubCfi` class name, it is not a standard EPUB CFI string. New renderer positions include `v:2` and an exact parsed-content UTF-16 offset. Legacy JSON remains readable; `hasExactCharOffset` must be explicit when constructing an exact offset programmatically.

The renderer captures the current logical text position before layout invalidation. A page number or previous pixel offset is not the primary reflow anchor. Selection ranges use start-inclusive/end-exclusive text offsets.

Restoring previously omitted images or correcting generated list markers changes offsets after those elements. Existing exact positions/highlights from the incomplete rendering may shift; their locator does not contain the old parsing revision or source quotation needed for unambiguous migration.


## Verification

From the Lira repository root:

```bash
flutter test packages/epub_engine/test

dart --packages=.dart_tool/package_config.json \
  packages/epub_engine/bin/debug_epub_parser.dart path/to/book.epub
```

See the repository's `READER.md` for the shared screen, persistence lifecycle and PDF integration.
