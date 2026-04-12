# Plan: Migrate EPUB Reader from WebView to Native Flutter Rendering

## Context

The current EPUB reader uses WebView (WKWebView on macOS, Android WebView) to render chapter HTML. This works but creates:
- Platform-specific bugs (trackpad on macOS, gesture conflicts)
- Complex JS bridge for highlights, text selection, navigation
- Two rendering worlds (Flutter UI vs WebView)
- No support for Linux/Windows without additional dependencies

The goal is to replace WebView rendering with native Flutter widgets while keeping the same features: text selection, highlights, settings, progress tracking, TOC navigation, vertical and horizontal reading modes.

## Approach

Replace `EpubReaderView` (WebView-based) with a new `EpubNativeView` that:
1. Parses chapter XHTML → Flutter widget tree using the `html` package (already a dependency)
2. Renders text via `Text.rich()` with `TextSpan` trees
3. Uses `SelectionArea` for text selection with `onSelectionChanged`
4. Applies highlights as `TextSpan` background colors at character offsets
5. Vertical mode: `ScrollController` + `ListView` of chapter widgets
6. Horizontal mode: `PageView` with pre-calculated page breaks via `TextPainter`

Keep `epubx` for parsing (epub_plus has the same API and is less maintained — last published 2+ years ago). The parsing layer (`EpubParser` → `ParsedEpub`) stays unchanged.

## Architecture

```
ParsedEpub.chapters[i].htmlContent (XHTML string)
        ↓
   XhtmlParser.parse(html, images)
        ↓
   List<ContentElement>  (TextBlock, ImageBlock, DividerBlock)
        ↓
   EpubNativeView renders as Flutter widgets
        ↓
   SelectionArea wraps everything for text selection
```

## Implementation Steps

### Step 1: Create XHTML → Content Elements Parser
**New file: `packages/epub_engine/lib/src/xhtml_parser.dart`**

Converts chapter XHTML string into a list of `ContentElement` objects:

```dart
sealed class ContentElement {
  final int charStart; // character offset within chapter text
  final int charEnd;
}

class TextBlock extends ContentElement {
  final InlineSpan span;       // TextSpan tree
  final TextBlockType type;    // paragraph, h1-h6, blockquote, listItem
  final int? listIndex;        // for ordered lists
}

class ImageBlock extends ContentElement {
  final Uint8List bytes;
  final String? alt;
}

class DividerBlock extends ContentElement {}
```

Uses `html` package to parse DOM, then walks the tree:
- `<p>` → `TextBlock(type: paragraph)`
- `<h1>`-`<h6>` → `TextBlock(type: h1..h6)`
- `<strong>/<b>` → `TextSpan(style: bold)`
- `<em>/<i>` → `TextSpan(style: italic)`
- `<a>` → `TextSpan` with `TapGestureRecognizer` (for internal links)
- `<img>` → `ImageBlock` (lookup bytes from `ParsedEpub.images`)
- `<ul>/<ol>` → series of `TextBlock(type: listItem)`
- `<blockquote>` → `TextBlock(type: blockquote)`
- `<br>` → newline in span
- `<hr>` → `DividerBlock`
- `<div>`, `<section>` → recurse into children
- `<sup>/<sub>` → font size reduction + baseline shift
- Text nodes → `TextSpan(text: ...)`

Track cumulative character count as we parse to populate `charStart`/`charEnd` on each element.

### Step 2: Highlight Overlay on TextSpan Tree
**In `xhtml_parser.dart` or separate utility**

Given a parsed chapter's `List<ContentElement>` and a list of highlight ranges `(startOffset, endOffset, color)`, modify the TextSpan tree to insert background colors:

```dart
InlineSpan applyHighlights(InlineSpan original, List<HighlightRange> highlights);
```

This walks the span tree, splits spans at highlight boundaries, and wraps highlighted portions with `TextSpan(style: TextStyle(backgroundColor: color))`.

### Step 3: Create Native Reader View
**New file: `packages/epub_engine/lib/src/epub_native_view.dart`**

Same API as current `EpubReaderView`:
```dart
class EpubNativeView extends StatefulWidget {
  final ParsedEpub epub;
  final EpubLocation? initialLocation;
  final ReaderSettings settings;
  final ThemeData theme;
  final void Function(EpubLocation, double percentage)? onLocationChanged;
  final void Function(String text, String location)? onTextSelected;
  final VoidCallback? onCenterTapped;
  final List<Map<String, dynamic>> highlights;
}
```

**Vertical mode:**
- `ScrollController` + `ListView.builder` (or `CustomScrollView` + `SliverList`)
- Each chapter → list of widgets from parsed `ContentElement`s
- Wrap in `SelectionArea(onSelectionChanged: ...)` for text selection
- Track scroll position → compute chapter index + fraction → report progress
- `GlobalKey`s on chapter widgets to measure positions for navigation

**Horizontal mode:**
- Pre-calculate page breaks: use `TextPainter` to measure each paragraph height at screen width
- Greedily fill pages until content exceeds page height
- `PageView` with `PageController` for navigation
- Each page is a `Column` of its assigned content widgets

**Settings applied directly via `TextStyle` / `Container` properties:**
- `fontFamily` → base `TextStyle`
- `fontSize` → base `TextStyle`
- `lineHeight` → `TextStyle.height`
- `backgroundColor` → `Container` color
- `horizontalPadding` → `Padding`
- `brightness` → `ColorFiltered` or `Opacity` (no platform view issues!)

**Text selection:**
- `SelectionArea(onSelectionChanged: (SelectedContent? content) { ... })`
- When selection changes, compute chapter index + character offsets
- Call `widget.onTextSelected`

**Tap detection:**
- `GestureDetector` wrapping the reader for center-tap → toggle UI

**State:**
```dart
class EpubNativeViewState extends State<EpubNativeView> {
  // Parsed content elements per chapter (lazy, cached)
  late List<List<ContentElement>> _parsedChapters;
  
  // For vertical mode
  ScrollController? _scrollController;
  
  // For horizontal mode
  PageController? _pageController;
  List<List<Widget>> _pages = []; // pre-calculated page layout
  
  // Navigation API (called from EpubBookReaderEngine.goToLocation)
  void scrollToChapter(String fileName) { ... }
}
```

### Step 4: Wire Up in Engine
**Modify: `packages/epub_engine/lib/src/epub_book_reader_engine.dart` → `lib/features/reader/domain/engine/epub_book_reader_engine.dart`**

Change `EpubReaderView` → `EpubNativeView` in `buildReaderWidget()`. The API is identical, so this is a one-line swap (plus import change).

### Step 5: Update Exports & Dependencies
**Modify: `packages/epub_engine/lib/epub_engine.dart`**
- Export `epub_native_view.dart` instead of (or alongside) `epub_reader_view.dart`

**Modify: `packages/epub_engine/pubspec.yaml`**
- Remove: `webview_flutter`, `webview_flutter_android`, `shelf`, `shelf_static`, `path_provider`
- Keep: `epubx`, `html`, `freezed_annotation`, `json_annotation`
- Keep: `scrollable_positioned_list` (might be useful)
- `flutter_widget_from_html` can be removed (was unused anyway)

### Step 6: Clean Up
- Keep `epub_reader_view.dart` temporarily as fallback (can delete in a future PR)
- Remove `patch_script.dart` if it was WebView-specific

## Files to Create
| File | Purpose |
|------|---------|
| `packages/epub_engine/lib/src/xhtml_parser.dart` | XHTML → ContentElement list |
| `packages/epub_engine/lib/src/epub_native_view.dart` | Native Flutter reader widget |

## Files to Modify
| File | Change |
|------|--------|
| `lib/features/reader/domain/engine/epub_book_reader_engine.dart` | Swap EpubReaderView → EpubNativeView |
| `packages/epub_engine/lib/epub_engine.dart` | Update exports |
| `packages/epub_engine/pubspec.yaml` | Remove WebView deps |

## Files Unchanged
- `packages/epub_engine/lib/src/epub_parser.dart` — parsing layer stays the same
- `packages/epub_engine/lib/src/models/` — all models stay the same
- `lib/features/reader/presentation/reader_screen.dart` — no changes needed (same engine API)
- `lib/features/highlights/` — entire highlights system stays the same
- `lib/features/reader/domain/engine/book_reader_engine.dart` — interface unchanged

## Phasing

**Phase 1 (this PR):** Vertical mode with full features
- XHTML parser, native view, text selection, highlights, settings, progress, TOC nav

**Phase 2 (follow-up):** Horizontal pagination mode
- Page break calculation, PageView integration

## Verification

1. Open EPUB book → text renders correctly (paragraphs, headings, bold/italic, images)
2. Scroll → progress bar updates, location saved
3. Close & reopen → restores last position
4. Select text → selection bar appears, can highlight/copy
5. Highlights render with correct colors
6. Settings (font, size, colors, padding, brightness) apply instantly
7. TOC navigation works
8. Works on macOS, Android, iOS (no platform-specific issues)
9. No WebView — verify trackpad scrolling works perfectly on macOS
