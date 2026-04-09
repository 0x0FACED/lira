import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'epub_parser.dart';
import 'models/reader_settings.dart';
import 'models/epub_location.dart';

/// EPUB reader using WebView for perfect CSS text rendering.
///
/// Solves HTML parsing issues and text cut-offs in horizontal pagination
/// by using the browser's native `column-width` property and loading all chapters into a single DOM.
class EpubReaderView extends StatefulWidget {
  final ParsedEpub epub;
  final EpubLocation? initialLocation;
  final ReaderSettings settings;
  final ThemeData theme;
  final void Function(EpubLocation location, double percentage)?
  onLocationChanged;
  final void Function(String text, String location)? onTextSelected;
  final VoidCallback? onCenterTapped;

  /// Serialized highlight data for rendering in the WebView.
  /// Each map must contain: highlightId, chapterIndex, startOffset, endOffset, color.
  final List<Map<String, dynamic>> highlights;

  const EpubReaderView({
    super.key,
    required this.epub,
    required this.settings,
    required this.theme,
    this.initialLocation,
    this.onLocationChanged,
    this.onTextSelected,
    this.onCenterTapped,
    this.highlights = const [],
  });

  @override
  State<EpubReaderView> createState() => EpubReaderViewState();
}

class EpubReaderViewState extends State<EpubReaderView> {
  late final WebViewController _controller;

  bool _isLoading = true;
  double _webviewOpacity = 0.0;
  double _pageHeight = 0;
  double _pageWidth = 0;

  // Text weights for accurate book-wide progress
  late final List<int> _chapterWeights;
  late final int _totalWeight;

  @override
  void initState() {
    super.initState();

    _chapterWeights = widget.epub.chapters
        .map((c) => c.htmlContent.length)
        .toList();
    _totalWeight = _chapterWeights.fold(0, (s, w) => s + w);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'LiraApp',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _onBookLoaded();
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('file://')) {
              // Allow navigation to our local temp file
              return NavigationDecision.navigate;
            } else if (request.url.startsWith('http')) {
              // External link (can launch in external browser if needed)
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('lira://')) {
              // Internal EPUB TOC link caught by our JS interceptor
              final target = request.url.replaceFirst('lira://', '');
              scrollToChapter(target);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // setBackgroundColor is not supported on macOS WKWebView (throws "opaque is not implemented")
    // Background color is already applied via CSS in the generated HTML
    if (Platform.isAndroid) {
      _controller.setBackgroundColor(Color(widget.settings.backgroundColor));
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // TOC Navigation API
  // ---------------------------------------------------------------------------

  void scrollToChapter(String fileName) {
    if (fileName.isEmpty) return;

    // Parse anchor
    final hashIndex = fileName.indexOf('#');
    final baseFile = hashIndex >= 0
        ? fileName.substring(0, hashIndex)
        : fileName;
    final anchor = hashIndex >= 0 ? fileName.substring(hashIndex + 1) : null;

    final index = _findChapterIndex(baseFile);
    if (index == null) return;

    if (anchor != null && anchor.isNotEmpty) {
      _controller.runJavaScript("scrollToAnchor('$anchor', $index)");
    } else {
      _controller.runJavaScript("scrollToChapter($index)");
    }
  }

  int? _findChapterIndex(String fileName) {
    var target = fileName;
    while (target.startsWith('.') || target.startsWith('/')) {
      target = target.substring(1);
    }
    target = target.split('#').first;

    for (int i = 0; i < widget.epub.chapters.length; i++) {
      var current = widget.epub.chapters[i].fileName;
      while (current.startsWith('.') || current.startsWith('/')) {
        current = current.substring(1);
      }
      if (current == target ||
          current.endsWith(target) ||
          target.endsWith(current)) {
        return i;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // JavaScript -> Dart callbacks
  // ---------------------------------------------------------------------------

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      final String type = data['type'];

      switch (type) {
        case 'progress':
          final int activeChapterIndex = data['chapterIndex'] as int;
          final double chapterFraction = (data['chapterFraction'] as num)
              .toDouble();

          if (!mounted || _totalWeight == 0) return;

          int prevWeight = 0;
          for (int i = 0; i < activeChapterIndex; i++) {
            prevWeight += _chapterWeights[i];
          }
          final curWeight =
              _chapterWeights[activeChapterIndex] * chapterFraction;
          final percentage = ((prevWeight + curWeight) / _totalWeight * 100)
              .clamp(0.0, 100.0);

          final charOffset =
              (widget.epub.chapters[activeChapterIndex].htmlContent.length *
                      chapterFraction)
                  .round();
          final location = EpubLocation.fromPosition(
            chapterIndex: activeChapterIndex,
            charOffset: charOffset,
            scrollFraction: chapterFraction,
          );
          widget.onLocationChanged?.call(location, percentage);
          break;
        case 'link':
          final String href = data['href'];
          scrollToChapter(href);
          break;
        case 'tap':
          widget.onCenterTapped?.call();
          break;
        case 'textSelected':
          final String text = data['text'] ?? '';
          final int chapterIndex = data['chapterIndex'] ?? 0;
          final int startOffset = data['startOffset'] ?? 0;
          final int endOffset = data['endOffset'] ?? 0;
          if (text.length < 2) break;
          final location = EpubLocation.fromPosition(
            chapterIndex: chapterIndex,
            charOffset: startOffset,
            scrollFraction: 0,
            startOffset: startOffset,
            endOffset: endOffset,
          );
          widget.onTextSelected?.call(text, location.toJson());
          break;
      }
    } catch (e) {
      debugPrint("Error parsing JS message: $e\nData: ${message.message}");
    }
  }

  // ---------------------------------------------------------------------------
  // HTML / CSS Generation & Injection
  // ---------------------------------------------------------------------------

  void _onBookLoaded() {
    if (!mounted) return;

    // Attempt to restore location
    if (widget.initialLocation != null) {
      final idx = widget.initialLocation!.chapterIndex;
      final frac = widget.initialLocation!.scrollFraction;
      _controller.runJavaScript("scrollToChapterFraction($idx, $frac)");
    }

    // Apply initial brightness via CSS filter
    if (widget.settings.brightness < 1.0) {
      _applyBrightnessViaJS(widget.settings.brightness);
    }

    // Render saved highlights
    _renderHighlights();

    // Slight delay to allow CSS columns to render before fading in
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _webviewOpacity = 1.0;
        });
      }
    });
  }

  void _loadFullBook() {
    if (_pageHeight <= 0) return; // Wait for layout

    final isHorizontal = widget.settings.readingMode == ReadingMode.horizontal;
    // Two-page spread when window is wide enough (>= 900px)
    final isTwoPage = isHorizontal && _pageWidth >= 900;

    // Color conversion — compute text color from background luminance
    final bgColor = Color(widget.settings.backgroundColor);
    final bgColorStr = '#${widget.settings.backgroundColor.toRadixString(16).padLeft(8, '0').substring(2)}';
    final textColor = bgColor.computeLuminance() > 0.5 ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);
    final textColorStr = '#${textColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final linkColor = bgColor.computeLuminance() > 0.5 ? '#6200EE' : '#BB86FC';
    final divColorStr = bgColor.computeLuminance() > 0.5 ? '#CCCCCC' : '#444444';
    final paddingH = widget.settings.horizontalPadding.toInt();

    // Define the img replacement regex
    final imgRegex = RegExp(
      r'<img[^>]+src=["' + "'" + r']([^"' + "'" + r']+)["' + "'" + r'][^>]*>',
      caseSensitive: false,
    );

    // Build the complete HTML shell
    final buffer = StringBuffer();
    buffer.write('''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body {
    margin: 0;
    padding: 0;
    width: 100vw;
    background-color: $bgColorStr;
    color: $textColorStr;
    font-family: ${widget.settings.fontFamily}, sans-serif;
    font-size: ${widget.settings.fontSize}px;
    line-height: ${widget.settings.lineHeight};
  }
  
  img {
    max-width: 100%;
    height: auto;
    display: block;
    margin: 1em auto;
  }
  
  a {
    color: $linkColor;
    text-decoration: underline;
  }
  
  .chapter-title {
    text-align: center;
    margin-top: 1em;
    margin-bottom: 2em;
    font-size: 1.5em;
    font-weight: bold;
  }
  
  .chapter-divider {
    border: none;
    border-top: 1px solid $divColorStr;
    margin: 3em auto;
    width: 60%;
    opacity: 0.3;
  }
  
  pre, code {
    white-space: pre-wrap !important;
    word-break: break-all !important;
    max-width: 100% !important;
    overflow-x: hidden !important;
  }

  mark {
    background-color: transparent;
    border-radius: 2px;
    padding: 0 1px;
  }
''');

    // Add layout-specific CSS
    // Two-page: each column = 50vw, gap between columns
    final colWidth = isTwoPage ? '50vw' : '100vw';
    final colGap = isTwoPage ? '0px' : '0px';
    // Step size: how much translateX moves per "page turn"
    // Single page: 100vw, Two-page: 100vw (two columns = one spread)
    if (isHorizontal) {
      buffer.write('''
  /* HORIZONTAL PAGINATION CSS */
  html, body {
    height: ${_pageHeight}px;
    overflow: hidden;
  }

  #content-container {
    height: ${_pageHeight}px;
    padding: 24px 0;
    box-sizing: border-box;
  }

  #content {
    column-width: $colWidth;
    column-gap: $colGap;
    column-fill: auto;
    height: 100%;
    padding: 0;
    box-sizing: border-box;
    transition: transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
    will-change: transform;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }

  .chapter-block {
    padding-left: ${paddingH}px;
    padding-right: ${paddingH}px;
  }

  p, div, blockquote {
    max-width: 100%;
  }

''');
    } else {
      buffer.write('''
  /* VERTICAL SCROLL CSS */
  html, body {
    overflow-y: auto;
    overflow-x: hidden;
  }
  
  #content-container {
    padding: 16px ${paddingH}px 64px ${paddingH}px;
    box-sizing: border-box;
    max-width: 800px;
    margin: 0 auto;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }
''');
    }

    // Add Javascript
    buffer.write('''
</style>
<script>
  let isHorizontal = ${isHorizontal ? 'true' : 'false'};
  let isTwoPage = ${isTwoPage ? 'true' : 'false'};
  let currentPage = 0;
  let totalPages = 1;
  let pageStride = window.innerWidth;

  function throttle(func, limit) {
    let inThrottle;
    return function() {
      const args = arguments;
      const context = this;
      if (!inThrottle) {
        func.apply(context, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    }
  }

  function sendMessage(type, data) {
    if (window.LiraApp) {
      window.LiraApp.postMessage(JSON.stringify(Object.assign({ type: type }, data || {})));
    }
  }

  function reportProgress() {
    let activeChapterIndex = 0;
    let chapterFraction = 0;

    if (isHorizontal) {
      const viewportCenter = (currentPage * window.innerWidth) + (window.innerWidth / 2);
      
      const chapters = document.querySelectorAll('.chapter-block');
      for(let i = 0; i < chapters.length; i++) {
         const ch = chapters[i];
         const left = ch.offsetLeft;
         const width = ch.getBoundingClientRect().width;
         if (viewportCenter >= left && viewportCenter <= left + width) {
            activeChapterIndex = parseInt(ch.getAttribute('data-index'));
            chapterFraction = width > 0 ? (viewportCenter - left) / width : 0;
            break;
         }
      }
    } else {
      const viewportCenter = window.scrollY + (window.innerHeight / 2);
      
      const chapters = document.querySelectorAll('.chapter-block');
      for(let i = 0; i < chapters.length; i++) {
         const ch = chapters[i];
         const top = ch.offsetTop;
         const height = ch.offsetHeight;
         if (viewportCenter >= top && viewportCenter <= top + height) {
            activeChapterIndex = parseInt(ch.getAttribute('data-index'));
            chapterFraction = height > 0 ? (viewportCenter - top) / height : 0;
            break;
         }
      }
    }
    
    chapterFraction = Math.max(0, Math.min(1, chapterFraction));
    
    sendMessage('progress', { 
        chapterIndex: activeChapterIndex, 
        chapterFraction: chapterFraction 
    });
  }

  const throttledProgress = throttle(reportProgress, 200);

  function recalcHorizontalPages() {
    if (!isHorizontal) return;
    const content = document.getElementById('content');
    if (!content) return;
    const sw = content.scrollWidth;
    const vw = window.innerWidth;
    if (isTwoPage) {
      // Each column is 50vw; a "page" (spread) = 2 columns = 100vw
      const totalCols = Math.ceil(sw / (vw / 2)) || 1;
      totalPages = Math.ceil(totalCols / 2) || 1;
      pageStride = vw; // one spread = full viewport width
    } else {
      totalPages = Math.ceil(sw / vw) || 1;
      pageStride = totalPages > 1 ? (sw / totalPages) : vw;
    }
  }

  function applyHorizontalTransform() {
    if (!isHorizontal) return;
    const content = document.getElementById('content');
    if (content) {
      currentPage = Math.round(currentPage);
      currentPage = Math.max(0, Math.min(currentPage, totalPages - 1));
      // Use pageStride instead of window.innerWidth to avoid cumulative drift
      const xOffset = -(currentPage * pageStride);
      content.style.transform = `translateX(\${xOffset}px)`;
      reportProgress();
    }
  }

  function snapToNearestPage() {
    if (!isHorizontal) return;
    const content = document.getElementById('content');
    if (!content) return;
    const style = window.getComputedStyle(content);
    const matrix = new DOMMatrix(style.transform);
    const currentX = -matrix.m41;
    const exactPage = currentX / pageStride;
    currentPage = Math.round(exactPage);
    currentPage = Math.max(0, Math.min(currentPage, totalPages - 1));
    content.style.transition = '';
    applyHorizontalTransform();
  }

  // --- External API called by Dart ---
  
  function scrollToChapterFraction(index, fraction) {
    const ch = document.getElementById('chapter-' + index);
    if (!ch) return;

    if (isHorizontal) {
      recalcHorizontalPages();
      const left = ch.offsetLeft;
      const width = ch.getBoundingClientRect().width;
      const targetX = left + (width * fraction);
      
      // Use Math.round to snap to nearest page boundary
      currentPage = Math.round(targetX / pageStride);
      currentPage = Math.max(0, Math.min(currentPage, totalPages - 1));
      
      const content = document.getElementById('content');
      if(content) {
        content.style.transition = 'none';
        applyHorizontalTransform();
        content.offsetHeight; // force reflow
        content.style.transition = '';
      }
    } else {
      const top = ch.offsetTop;
      const height = ch.offsetHeight;
      const targetY = top + (height * fraction);
      window.scrollTo(0, targetY);
    }
  }
  
  function scrollToChapter(index) {
     scrollToChapterFraction(index, 0);
  }

  function scrollToAnchor(id, index) {
    // some anchors might be 'chapter_1.xhtml#id', so try exact id or name
    let el = document.getElementById(id) || document.querySelector(`[name="\${id}"]`);
    if (!el && id.includes('#')) {
       const subId = id.split('#').pop();
       el = document.getElementById(subId) || document.querySelector(`[name="\${subId}"]`);
    }
    
    if (el) {
      if (isHorizontal) {
        recalcHorizontalPages();
        const absoluteLeft = el.offsetLeft; 
        // Use Math.round to snap to nearest page boundary
        currentPage = Math.round(absoluteLeft / pageStride);
        currentPage = Math.max(0, Math.min(currentPage, totalPages - 1));
        applyHorizontalTransform();
      } else {
        el.scrollIntoView();
      }
    } else {
      // Fallback
      scrollToChapterFraction(index, 0);
    }
  }

  // --- Highlight rendering ---

  // Convert hex color (#RRGGBB) to rgba with alpha
  function hexToRgba(hex, alpha) {
    const h = hex.replace('#', '');
    const r = parseInt(h.substring(0, 2), 16);
    const g = parseInt(h.substring(2, 4), 16);
    const b = parseInt(h.substring(4, 6), 16);
    return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
  }

  function styleMark(mark, color, highlightId) {
    mark.setAttribute('data-highlight-id', highlightId);
    mark.style.backgroundColor = hexToRgba(color, 0.35);
    mark.style.borderRadius = '2px';
    mark.style.padding = '0 1px';
  }

  function applyHighlight(chapterIndex, startOffset, endOffset, color, highlightId) {
    const chapterEl = document.getElementById('chapter-' + chapterIndex);
    if (!chapterEl) return;

    const walker = document.createTreeWalker(chapterEl, NodeFilter.SHOW_TEXT, null);
    let charCount = 0;
    let startNode = null, startNodeOffset = 0;
    let endNode = null, endNodeOffset = 0;

    while (walker.nextNode()) {
      const tn = walker.currentNode;
      const len = tn.length;
      if (!startNode && charCount + len > startOffset) {
        startNode = tn;
        startNodeOffset = startOffset - charCount;
      }
      if (!endNode && charCount + len >= endOffset) {
        endNode = tn;
        endNodeOffset = endOffset - charCount;
        break;
      }
      charCount += len;
    }

    if (!startNode || !endNode) return;

    try {
      const range = document.createRange();
      range.setStart(startNode, Math.min(startNodeOffset, startNode.length));
      range.setEnd(endNode, Math.min(endNodeOffset, endNode.length));

      const mark = document.createElement('mark');
      styleMark(mark, color, highlightId);
      range.surroundContents(mark);
    } catch(e) {
      // surroundContents fails if range crosses element boundaries;
      // fall back to extractContents + insertNode
      try {
        const range = document.createRange();
        range.setStart(startNode, Math.min(startNodeOffset, startNode.length));
        range.setEnd(endNode, Math.min(endNodeOffset, endNode.length));
        const frag = range.extractContents();
        const mark = document.createElement('mark');
        styleMark(mark, color, highlightId);
        mark.appendChild(frag);
        range.insertNode(mark);
      } catch(e2) { /* skip broken ranges */ }
    }
  }

  function removeHighlight(highlightId) {
    const mark = document.querySelector('mark[data-highlight-id="' + highlightId + '"]');
    if (mark) {
      const parent = mark.parentNode;
      while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
      parent.removeChild(mark);
      parent.normalize();
    }
  }

  // --- Event Listeners ---
  
  window.onload = function() {
    if (isHorizontal) {
      const imgs = document.querySelectorAll('img');
      imgs.forEach(img => {
         img.style.maxHeight = "${_pageHeight * 0.9}px";
      });
      recalcHorizontalPages();
    }
    
    document.querySelectorAll("a").forEach(a => {
      a.addEventListener("click", function(e) {
        e.preventDefault();
        const href = this.getAttribute("href");
        if (href) {
          sendMessage('link', { href: href });
        }
      });
    });
    
    reportProgress();
  };

  // Swipe handling
  let touchStartX = 0;
  let touchEndX = 0;
  
  function handleSwipe() {
    if (!isHorizontal) return;
    const SWIPE_THRESHOLD = 80;
    if (touchEndX < touchStartX - SWIPE_THRESHOLD) {
      // Swipe Left (Next)
      if (currentPage < totalPages - 1) {
        currentPage++;
        applyHorizontalTransform();
      }
    } else if (touchEndX > touchStartX + SWIPE_THRESHOLD) {
      // Swipe Right (Prev)
      if (currentPage > 0) {
        currentPage--;
        applyHorizontalTransform();
      }
    }
  }

  window.addEventListener('touchstart', e => {
    if (!isHorizontal) return;
    touchStartX = e.changedTouches[0].clientX;
  }, {passive: true});
  
  window.addEventListener('touchend', e => {
    if (!isHorizontal) return;
    touchEndX = e.changedTouches[0].clientX;
    handleSwipe();
  }, {passive: true});
  
  let isMouseDown = false;
  window.addEventListener('mousedown', e => {
    if (!isHorizontal) return;
    isMouseDown = true;
    touchStartX = e.clientX;
  }, {passive: true});
  
  window.addEventListener('mouseup', e => {
    if (!isHorizontal) return;
    if (isMouseDown) {
      touchEndX = e.clientX;
      isMouseDown = false;
      handleSwipe();
    }
  }, {passive: true});
  
  window.addEventListener('mouseleave', () => { isMouseDown = false; });

  // Trackpad / mouse wheel support for horizontal mode (macOS, desktop)
  let wheelAccum = 0;
  let wheelLocked = false;
  const WHEEL_PAGE_THRESHOLD = 300;
  const WHEEL_LOCK_MS = 400;
  window.addEventListener('wheel', e => {
    if (!isHorizontal) return;
    e.preventDefault();
    if (wheelLocked) return;
    const delta = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
    wheelAccum += delta;
    if (Math.abs(wheelAccum) > WHEEL_PAGE_THRESHOLD) {
      const dir = wheelAccum > 0 ? 1 : -1;
      wheelAccum = 0;
      wheelLocked = true;
      setTimeout(() => { wheelLocked = false; wheelAccum = 0; }, WHEEL_LOCK_MS);
      const next = currentPage + dir;
      if (next >= 0 && next < totalPages) { currentPage = next; applyHorizontalTransform(); }
    }
  }, {passive: false});

  // Arrow keys for horizontal navigation
  window.addEventListener('keydown', e => {
    if (!isHorizontal) return;
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      if (currentPage < totalPages - 1) { currentPage++; applyHorizontalTransform(); }
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      if (currentPage > 0) { currentPage--; applyHorizontalTransform(); }
    }
  });

  // Tap detection (for toggling UI bars)
  let tapStartX = 0, tapStartY = 0, tapStartTime = 0;
  window.addEventListener('pointerdown', e => {
    tapStartX = e.clientX;
    tapStartY = e.clientY;
    tapStartTime = Date.now();
  });
  window.addEventListener('pointerup', e => {
    const dx = e.clientX - tapStartX;
    const dy = e.clientY - tapStartY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const elapsed = Date.now() - tapStartTime;
    if (dist < 20 && elapsed < 400) {
      // It's a tap, not a swipe or drag
      const sel = window.getSelection();
      if (sel && sel.toString().length > 0) return; // text selected, skip
      sendMessage('tap', {});
    }
  });

  // Text selection — send selected text + location to Dart
  function getSelectionInfo() {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed || sel.toString().trim().length < 2) return null;

    const text = sel.toString().trim();
    const range = sel.getRangeAt(0);

    // Find which chapter the selection starts in
    let chapterIndex = 0;
    let node = range.startContainer;
    while (node && node !== document.body) {
      if (node.classList && node.classList.contains('chapter-block')) {
        chapterIndex = parseInt(node.getAttribute('data-index')) || 0;
        break;
      }
      node = node.parentNode;
    }

    // Calculate character offsets within the chapter's text content
    const chapterEl = document.getElementById('chapter-' + chapterIndex);
    if (!chapterEl) return null;

    // Use TreeWalker to count text characters up to selection start/end
    const walker = document.createTreeWalker(chapterEl, NodeFilter.SHOW_TEXT, null);
    let charCount = 0;
    let startOffset = 0;
    let endOffset = 0;
    let foundStart = false;
    let foundEnd = false;

    while (walker.nextNode()) {
      const tn = walker.currentNode;
      if (tn === range.startContainer) {
        startOffset = charCount + range.startOffset;
        foundStart = true;
      }
      if (tn === range.endContainer) {
        endOffset = charCount + range.endOffset;
        foundEnd = true;
        break;
      }
      charCount += tn.length;
    }

    if (!foundStart) startOffset = charCount;
    if (!foundEnd) endOffset = startOffset + text.length;

    return { text, chapterIndex, startOffset, endOffset };
  }

  // Debounce: only send after user finishes selecting
  let selectionTimer = null;
  document.addEventListener('mouseup', () => {
    clearTimeout(selectionTimer);
    selectionTimer = setTimeout(() => {
      const info = getSelectionInfo();
      if (info) sendMessage('textSelected', info);
    }, 200);
  });
  document.addEventListener('touchend', () => {
    clearTimeout(selectionTimer);
    selectionTimer = setTimeout(() => {
      const info = getSelectionInfo();
      if (info) sendMessage('textSelected', info);
    }, 200);
  });

  window.addEventListener('resize', () => {
    if (isHorizontal) {
      recalcHorizontalPages();
      if(currentPage >= totalPages) currentPage = Math.max(0, totalPages - 1);
      applyHorizontalTransform();
    }
  });
  
  // Vertical handling
  window.addEventListener('scroll', () => {
    if (!isHorizontal) throttledProgress();
  }, {passive: true});
</script>
</head>
<body>
<div id="content-container">
<div id="content">
''');

    // Inject all chapters sequentially
    for (int i = 0; i < widget.epub.chapters.length; i++) {
      final chapter = widget.epub.chapters[i];
      var htmlContent = chapter.htmlContent;

      // Inject images directly as Base64.
      // OOM usually happens when sending this massive string via MethodChannels.
      // By writing this to a file instead, we avoid the MethodChannel limit.
      if (widget.epub.images.isNotEmpty) {
        htmlContent = htmlContent.replaceAllMapped(imgRegex, (match) {
          final src = match.group(1);
          if (src == null) return match.group(0)!;

          final filename = src.split('/').last;
          Uint8List? imgBytes;

          for (final entry in widget.epub.images.entries) {
            if (entry.key.endsWith(filename)) {
              imgBytes = entry.value;
              break;
            }
          }

          if (imgBytes != null) {
            try {
              String mime = 'image/jpeg';
              if (filename.toLowerCase().endsWith('.png')) mime = 'image/png';
              if (filename.toLowerCase().endsWith('.gif')) mime = 'image/gif';
              if (filename.toLowerCase().endsWith('.svg'))
                mime = 'image/svg+xml';

              final b64 = base64Encode(imgBytes);
              final dataUri = 'data:$mime;base64,$b64';
              return match.group(0)!.replaceFirst(src, dataUri);
            } catch (_) {}
          }
          return match.group(0)!;
        });
      }

      buffer.write(
        '<div id="chapter-$i" class="chapter-block" data-index="$i">',
      );
      if (chapter.title.isNotEmpty) {
        buffer.write('<div class="chapter-title">${chapter.title}</div>');
      }
      buffer.write(htmlContent);
      buffer.write('</div>');

      // Add visual divider between chapters
      if (i < widget.epub.chapters.length - 1) {
        buffer.write('<hr class="chapter-divider" />');
      }
    }

    buffer.write('</div></div></body></html>');

    // Write the massive HTML string to a temporary file,
    // avoiding passing a 150MB+ string across MethodChannels (which causes OOM).
    _writeToTempAndLoad(buffer.toString());
  }

  Future<void> _writeToTempAndLoad(String htmlContent) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/epub_temp_${DateTime.now().millisecondsSinceEpoch}.html',
      );
      await file.writeAsString(htmlContent, encoding: utf8);

      // Need allow file access
      if (_controller.platform is AndroidWebViewController) {
        (_controller.platform as AndroidWebViewController).setAllowFileAccess(
          true,
        );
      }

      await _controller.loadFile(file.path);
    } catch (e) {
      debugPrint('Failed to load EPUB from temp file: $e');
    }
  }

  @override
  void didUpdateWidget(EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings == oldWidget.settings) return;

    final old = oldWidget.settings;
    final cur = widget.settings;

    // Brightness — apply via CSS filter inside WebView (not a Flutter overlay,
    // because IgnorePointer over a platform view blocks trackpad on macOS).
    if (old.brightness != cur.brightness &&
        old.copyWith(brightness: cur.brightness) == cur) {
      _applyBrightnessViaJS(cur.brightness);
      return;
    }

    // Reading mode change (vertical ↔ horizontal) requires full HTML reload
    // because the CSS layout structure is fundamentally different.
    if (old.readingMode != cur.readingMode) {
      setState(() {
        _isLoading = true;
        _webviewOpacity = 0.0;
      });
      if (Platform.isAndroid) {
        _controller.setBackgroundColor(Color(cur.backgroundColor));
      }
      _loadFullBook();
      return;
    }

    // All other changes (font, size, line height, padding, bg color) —
    // update via JavaScript to avoid WKWebView reload bug on macOS
    // where a second loadFile call breaks the internal scroll view.
    _applySettingsViaJS(old, cur);
    setState(() {});
  }

  /// Update CSS properties via JavaScript without reloading the HTML.
  /// This avoids a macOS WKWebView bug where reloading content via loadFile
  /// breaks the internal NSScrollView scrolling.
  void _applySettingsViaJS(ReaderSettings old, ReaderSettings cur) {
    final js = StringBuffer();

    if (old.backgroundColor != cur.backgroundColor) {
      final bgColor = Color(cur.backgroundColor);
      final bgStr = '#${cur.backgroundColor.toRadixString(16).padLeft(8, '0').substring(2)}';
      final textColor = bgColor.computeLuminance() > 0.5 ? '#1A1A1A' : '#E0E0E0';
      final linkColor = bgColor.computeLuminance() > 0.5 ? '#6200EE' : '#BB86FC';
      final divColor = bgColor.computeLuminance() > 0.5 ? '#CCCCCC' : '#444444';
      js.writeln('''
        document.documentElement.style.backgroundColor = '$bgStr';
        document.body.style.backgroundColor = '$bgStr';
        document.body.style.color = '$textColor';
        document.querySelectorAll('a').forEach(a => a.style.color = '$linkColor');
        document.querySelectorAll('.chapter-divider').forEach(d => d.style.borderTopColor = '$divColor');
      ''');
      if (Platform.isAndroid) {
        _controller.setBackgroundColor(bgColor);
      }
    }

    if (old.fontFamily != cur.fontFamily) {
      js.writeln("document.body.style.fontFamily = '${cur.fontFamily}, sans-serif';");
    }

    if (old.fontSize != cur.fontSize) {
      js.writeln("document.body.style.fontSize = '${cur.fontSize}px';");
    }

    if (old.lineHeight != cur.lineHeight) {
      js.writeln("document.body.style.lineHeight = '${cur.lineHeight}';");
    }

    if (old.horizontalPadding != cur.horizontalPadding) {
      final paddingH = cur.horizontalPadding.toInt();
      if (cur.readingMode == ReadingMode.horizontal) {
        js.writeln('''
          document.querySelectorAll('.chapter-block').forEach(ch => {
            ch.style.paddingLeft = '${paddingH}px';
            ch.style.paddingRight = '${paddingH}px';
          });
        ''');
      } else {
        js.writeln('''
          var cc = document.getElementById('content-container');
          if (cc) { cc.style.paddingLeft = '${paddingH}px'; cc.style.paddingRight = '${paddingH}px'; }
        ''');
      }
    }

    // In horizontal mode, recalculate pagination after CSS changes
    if (cur.readingMode == ReadingMode.horizontal &&
        (old.fontSize != cur.fontSize ||
         old.fontFamily != cur.fontFamily ||
         old.lineHeight != cur.lineHeight ||
         old.horizontalPadding != cur.horizontalPadding)) {
      js.writeln('setTimeout(function() { recalcHorizontalPages(); snapToNearestPage(); }, 50);');
    }

    if (old.brightness != cur.brightness) {
      _applyBrightnessViaJS(cur.brightness);
    }

    if (js.isNotEmpty) {
      _controller.runJavaScript(js.toString());
    }
  }

  /// Apply brightness as a CSS filter inside the WebView.
  /// Using a Flutter overlay (IgnorePointer + Container) blocks trackpad
  /// gestures on macOS platform views, so we dim via CSS instead.
  void _applyBrightnessViaJS(double brightness) {
    final b = brightness.clamp(0.0, 1.0);
    _controller.runJavaScript(
      "document.body.style.filter = 'brightness($b)';",
    );
  }

  /// Render all saved highlights into the WebView.
  void _renderHighlights() {
    for (final h in widget.highlights) {
      addHighlightMark(
        highlightId: h['highlightId'] as String,
        chapterIndex: h['chapterIndex'] as int,
        startOffset: h['startOffset'] as int,
        endOffset: h['endOffset'] as int,
        color: h['color'] as String,
      );
    }
  }

  /// Add a single highlight mark to the WebView.
  void addHighlightMark({
    required String highlightId,
    required int chapterIndex,
    required int startOffset,
    required int endOffset,
    required String color,
  }) {
    _controller.runJavaScript(
      "applyHighlight($chapterIndex, $startOffset, $endOffset, '$color', '$highlightId');",
    );
  }

  /// Remove a single highlight mark from the WebView.
  void removeHighlightMark(String highlightId) {
    _controller.runJavaScript("removeHighlight('$highlightId');");
  }

  @override
  Widget build(BuildContext context) {
    if (widget.epub.chapters.isEmpty) {
      return const Center(child: Text('This EPUB has no readable chapters.'));
    }

    // Capture height for WebView generation, excluding safe areas
    final safePadding = MediaQuery.of(context).padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        // In vertical mode, JS manages height automatically.
        // In horizontal mode, we need the exact inner height to set CSS correctly.
        final newHeight =
            constraints.maxHeight - safePadding.top - safePadding.bottom;
        final newWidth = constraints.maxWidth;

        if (_pageHeight != newHeight || _pageWidth != newWidth) {
          _pageHeight = newHeight;
          _pageWidth = newWidth;
          // First frame: load full book
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadFullBook();
          });
        }

        return Container(
          color: Color(widget.settings.backgroundColor),
          child: Padding(
            padding: EdgeInsets.only(
              top: safePadding.top,
              bottom: safePadding.bottom,
            ),
            child: Stack(
              children: [
                AnimatedOpacity(
                  opacity: _webviewOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: WebViewWidget(
                    controller: _controller,
                    gestureRecognizers: {
                      Factory<EagerGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),

                // Brightness is applied via CSS filter inside WebView
                // (not a Flutter overlay — IgnorePointer blocks trackpad on macOS).

                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Color(widget.settings.backgroundColor),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
