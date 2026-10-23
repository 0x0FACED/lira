# epub_engine

Native Flutter EPUB rendering for Lira. No WebView or embedded JavaScript; EPUB container parsing uses ZIP/XML directly.

## Content and rendering

`EpubParser.parse(bytes)` reads ZIP/container/OPF, preserves spine reading order and builds a separate NCX/EPUB3 navigation tree. Spine documents are not filtered by filename. UTF-8 and UTF-16 text are decoded without silent replacement of malformed characters.

`XhtmlParser` produces styled text, image and divider blocks with character ranges, anchors and links. `EpubNativeView` renders them with native Flutter text selection:

- chapter-indexed vertical scrolling;
- measured horizontal pagination and optional two-page spreads;
- content-position restoration across mode, typography and viewport changes;
- overlapping highlights without modifying the original text;
- internal document/fragment navigation and external HTTP(S) links.

This is a native block renderer, not a complete browser HTML/CSS implementation.

## Locations

`initialLocation` is an opening seed. Use `EpubNativeViewState.goToLocation` or `scrollToChapter` for later navigation.

`EpubLocation` serializes an application-specific JSON locator. Despite its historical `EpubCfi` class name, it is not a standard EPUB CFI string. New renderer positions include `v:2` and an exact parsed-content UTF-16 offset. Legacy JSON remains readable; `hasExactCharOffset` must be explicit when constructing an exact offset programmatically.

The renderer captures the current logical text position before layout invalidation. A page number or previous pixel offset is not the primary reflow anchor. Selection ranges use start-inclusive/end-exclusive text offsets.

## Verification

From the Lira repository root:

```bash
flutter test packages/epub_engine/test

dart --packages=.dart_tool/package_config.json \
  packages/epub_engine/bin/debug_epub_parser.dart path/to/book.epub
```

See the repository's `READER.md` for the shared screen, persistence lifecycle and PDF integration.
