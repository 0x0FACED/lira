import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

  const EpubReaderView({
    super.key,
    required this.epub,
    required this.settings,
    required this.theme,
    this.initialLocation,
    this.onLocationChanged,
    this.onTextSelected,
  });

  @override
  State<EpubReaderView> createState() => EpubReaderViewState();
}

class EpubReaderViewState extends State<EpubReaderView> {
  late final WebViewController _controller;

  bool _isLoading = true;
  double _webviewOpacity = 0.0;
  double _pageHeight = 0;

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
      ..setBackgroundColor(Color(widget.settings.backgroundColor))
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

    // Color conversion
    final bgColorStr =
        '#' +
        widget.settings.backgroundColor
            .toRadixString(16)
            .padLeft(8, '0')
            .substring(2);
    final textColorStr =
        '#' +
        widget.theme.colorScheme.onSurface.value
            .toRadixString(16)
            .padLeft(8, '0')
            .substring(2);
    final divColorStr =
        '#' +
        widget.theme.dividerColor.value
            .toRadixString(16)
            .padLeft(8, '0')
            .substring(2);
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
    color: $textColorStr;
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
''');

    // Add layout-specific CSS
    if (isHorizontal) {
      buffer.write('''
  /* HORIZONTAL PAGINATION CSS */
  html, body {
    height: ${_pageHeight}px; 
    overflow: hidden; /* Prevent vertical scrolling */
  }
  
  #content-container {
    height: ${_pageHeight}px;
    padding: 24px 0; /* Add top and bottom margins for text so it breathes */
    box-sizing: border-box;
  }

  #content {
    /* Each column = exactly 100vw, no gap, no padding on this element.
       This guarantees page stride == window.innerWidth exactly. */
    column-width: 100vw;
    column-gap: 0px;
    column-fill: auto;
    height: 100%;
    padding: 0;
    box-sizing: border-box;
    /* Smooth CSS slide animation */
    transition: transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
    will-change: transform;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }
  
  /* Horizontal padding is on each chapter block, not #content */
  .chapter-block {
    padding-left: ${paddingH}px;
    padding-right: ${paddingH}px;
  }
  
  /* Prevent large blocks from overflowing columns */
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
  let currentPage = 0;
  let totalPages = 1;
  let pageStride = window.innerWidth; // Actual stride per page (computed from DOM)

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
    if (content) {
      totalPages = Math.ceil(content.scrollWidth / window.innerWidth) || 1;
      // Compute the actual stride from the DOM to avoid sub-pixel drift
      pageStride = totalPages > 1 ? (content.scrollWidth / totalPages) : window.innerWidth;
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
    const SWIPE_THRESHOLD = 50;
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
      await file.writeAsString(htmlContent);

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
    // User changed settings (mode, font size, etc.)
    if (widget.settings != oldWidget.settings) {
      setState(() {
        _isLoading = true;
        _webviewOpacity = 0.0;
      });
      _controller.setBackgroundColor(Color(widget.settings.backgroundColor));
      _loadFullBook();
    }
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

        if (_pageHeight != newHeight) {
          _pageHeight = newHeight;
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
                  child: WebViewWidget(controller: _controller),
                ),

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
