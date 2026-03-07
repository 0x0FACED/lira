import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'epub_parser.dart';
import 'models/reader_settings.dart';
import 'models/epub_location.dart';

/// EPUB reader using WebView for perfect CSS text rendering.
///
/// Solves HTML parsing issues and text cut-offs in horizontal pagination
/// by using the browser's native `column-width` property.
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

  int _currentChapterIndex = 0;
  bool _isLoading = true;
  double _webviewOpacity = 0.0;
  double _pageHeight = 0;

  // Pending navigations
  double? _pendingFraction;
  String? _pendingAnchor;
  bool _pendingScrollToEnd = false;

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

    if (widget.initialLocation != null) {
      _currentChapterIndex = widget.initialLocation!.chapterIndex.clamp(
        0,
        widget.epub.chapters.length - 1,
      );
      _pendingFraction = widget.initialLocation!.scrollFraction;
    }

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
            _onChapterLoaded();
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('http')) {
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

    if (index == _currentChapterIndex) {
      // Same chapter, just tell JS to scroll to anchor
      if (anchor != null && anchor.isNotEmpty) {
        _controller.runJavaScript("scrollToAnchor('$anchor')");
      }
    } else {
      // Different chapter, load it
      setState(() {
        _currentChapterIndex = index;
        _isLoading = true;
        _webviewOpacity = 0.0;
        _pendingAnchor = anchor;
        _pendingFraction = null;
        _pendingScrollToEnd = false;
      });
      _loadCurrentChapter();
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
        case 'next_chapter':
          if (_currentChapterIndex < widget.epub.chapters.length - 1) {
            setState(() {
              _currentChapterIndex++;
              _isLoading = true;
              _webviewOpacity = 0.0;
              _pendingScrollToEnd = false;
              _pendingFraction = null;
              _pendingAnchor = null;
            });
            _loadCurrentChapter();
          }
          break;
        case 'prev_chapter':
          if (_currentChapterIndex > 0) {
            setState(() {
              _currentChapterIndex--;
              _isLoading = true;
              _webviewOpacity = 0.0;
              _pendingScrollToEnd =
                  true; // when going back, go to end of prev chapter
              _pendingFraction = null;
              _pendingAnchor = null;
            });
            _loadCurrentChapter();
          }
          break;
        case 'progress':
          final double fraction = (data['fraction'] as num).toDouble();
          _reportProgress(fraction);
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

  void _reportProgress(double localFraction) {
    if (!mounted || _totalWeight == 0) return;

    int prevWeight = 0;
    for (int i = 0; i < _currentChapterIndex; i++) {
      prevWeight += _chapterWeights[i];
    }
    final curWeight = _chapterWeights[_currentChapterIndex] * localFraction;
    final percentage = ((prevWeight + curWeight) / _totalWeight * 100).clamp(
      0.0,
      100.0,
    );

    final charOffset =
        (widget.epub.chapters[_currentChapterIndex].htmlContent.length *
                localFraction)
            .round();
    final location = EpubLocation.fromPosition(
      chapterIndex: _currentChapterIndex,
      charOffset: charOffset,
      scrollFraction: localFraction,
    );
    widget.onLocationChanged?.call(location, percentage);
  }

  // ---------------------------------------------------------------------------
  // HTML / CSS Generation & Injection
  // ---------------------------------------------------------------------------

  void _onChapterLoaded() {
    if (!mounted) return;

    // Apply pending navigations
    if (_pendingAnchor != null && _pendingAnchor!.isNotEmpty) {
      _controller.runJavaScript("scrollToAnchor('$_pendingAnchor')");
    } else if (_pendingScrollToEnd) {
      _controller.runJavaScript("scrollToEnd()");
    } else if (_pendingFraction != null && _pendingFraction! > 0) {
      _controller.runJavaScript("scrollToFraction(${_pendingFraction!})");
    }

    _pendingAnchor = null;
    _pendingScrollToEnd = false;
    _pendingFraction = null;

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

  void _loadCurrentChapter() {
    if (_pageHeight <= 0) return; // Wait for layout

    final chapter = widget.epub.chapters[_currentChapterIndex];
    final isHorizontal = widget.settings.readingMode == ReadingMode.horizontal;

    // Base64 encode images to embed them directly in HTML
    var htmlContent = chapter.htmlContent;

    // Inject images directly
    if (widget.epub.images.isNotEmpty) {
      // Find all <img> tags and replace src
      final imgRegex = RegExp(
        r'<img[^>]+src=["' + "'" + r']([^"' + "'" + r']+)["' + "'" + r'][^>]*>',
        caseSensitive: false,
      );
      htmlContent = htmlContent.replaceAllMapped(imgRegex, (match) {
        final src = match.group(1);
        if (src == null) return match.group(0)!;

        final filename = src.split('/').last;
        Uint8List? imgBytes;

        // Match filename to epub images map
        for (final entry in widget.epub.images.entries) {
          if (entry.key.endsWith(filename)) {
            imgBytes = entry.value;
            break;
          }
        }

        if (imgBytes != null) {
          try {
            // Very basic mime type inference
            String mime = 'image/jpeg';
            if (filename.toLowerCase().endsWith('.png')) mime = 'image/png';
            if (filename.toLowerCase().endsWith('.gif')) mime = 'image/gif';
            if (filename.toLowerCase().endsWith('.svg')) mime = 'image/svg+xml';

            final b64 = base64Encode(imgBytes);
            final dataUri = 'data:$mime;base64,$b64';
            return match.group(0)!.replaceFirst(src, dataUri);
          } catch (_) {}
        }
        return match.group(0)!;
      });
    }

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
    final paddingH = widget.settings.horizontalPadding.toInt();

    // Build the complete HTML shell
    String fullHtml =
        '''
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
    color: ${textColorStr};
    text-decoration: underline;
  }
  
  .chapter-title {
    text-align: center;
    margin-top: 1em;
    margin-bottom: 2em;
    font-size: 1.5em;
    font-weight: bold;
  }
''';

    // Add layout-specific CSS
    if (isHorizontal) {
      fullHtml +=
          '''
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
    /* Multi-column layout handles text splitting natively */
    column-width: calc(100vw - ${paddingH * 2}px);
    column-gap: ${paddingH * 2}px;
    column-fill: auto;
    height: 100%; /* Fill the container minus its padding */
    padding: 0 ${paddingH}px;
    box-sizing: border-box;
    /* Smooth CSS slide animation */
    transition: transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
    will-change: transform;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }
  
  /* Prevent large blocks from overflowing columns */
  p, div, blockquote {
    max-width: 100%;
  }
''';
    } else {
      fullHtml +=
          '''
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
''';
    }

    // Add Javascript
    fullHtml +=
        '''
</style>
<script>
  let isHorizontal = ${isHorizontal ? 'true' : 'false'};
  let currentPage = 0;
  let totalPages = 1;
  
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
    let fraction = 0;
    if (isHorizontal) {
      fraction = totalPages > 1 ? currentPage / (totalPages - 1) : 0;
    } else {
      const maxScroll = Math.max(0, document.body.scrollHeight - window.innerHeight);
      fraction = maxScroll > 0 ? (window.scrollY / maxScroll) : 0;
    }
    sendMessage('progress', { fraction: fraction });
  }

  const throttledProgress = throttle(reportProgress, 200);

  function recalcHorizontalPages() {
    if (!isHorizontal) return;
    const content = document.getElementById('content');
    if (content) {
      totalPages = Math.ceil(content.scrollWidth / window.innerWidth) || 1;
    }
  }

  function applyHorizontalTransform() {
    if (!isHorizontal) return;
    const content = document.getElementById('content');
    if (content) {
      const xOffset = -(currentPage * window.innerWidth);
      content.style.transform = `translateX(\${xOffset}px)`;
      reportProgress();
    }
  }

  // --- External API called by Dart ---
  
  function scrollToEnd() {
    if (isHorizontal) {
      recalcHorizontalPages();
      currentPage = Math.max(0, totalPages - 1);
      
      const content = document.getElementById('content');
      if(content) {
        content.style.transition = 'none';
        applyHorizontalTransform();
        content.offsetHeight; // force reflow
        content.style.transition = '';
      }
    } else {
      window.scrollTo(0, document.body.scrollHeight);
    }
  }
  
  function scrollToFraction(fraction) {
    if (isHorizontal) {
      recalcHorizontalPages();
      currentPage = Math.floor(fraction * (totalPages - 1));
      currentPage = Math.max(0, Math.min(currentPage, totalPages - 1));
      
      const content = document.getElementById('content');
      if(content) {
        content.style.transition = 'none';
        applyHorizontalTransform();
        content.offsetHeight;
        content.style.transition = '';
      }
    } else {
      const maxScroll = Math.max(0, document.body.scrollHeight - window.innerHeight);
      window.scrollTo(0, maxScroll * fraction);
    }
  }

  function scrollToAnchor(id) {
    const el = document.getElementById(id) || document.querySelector(`[name="\${id}"]`);
    if (el) {
      if (isHorizontal) {
        recalcHorizontalPages();
        const absoluteLeft = el.offsetLeft; 
        currentPage = Math.floor(absoluteLeft / window.innerWidth);
        currentPage = Math.max(0, Math.min(currentPage, totalPages - 1));
        applyHorizontalTransform();
      } else {
        el.scrollIntoView();
      }
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
      } else {
        sendMessage('next_chapter', {});
      }
    } else if (touchEndX > touchStartX + SWIPE_THRESHOLD) {
      // Swipe Right (Prev)
      if (currentPage > 0) {
        currentPage--;
        applyHorizontalTransform();
      } else {
        sendMessage('prev_chapter', {});
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
  let isScrolling = false;
  window.addEventListener('scroll', () => {
    if (isHorizontal) return;
    throttledProgress();
    
    if(isScrolling) return;
    isScrolling = true;
    setTimeout(() => {
      const st = Math.ceil(window.scrollY);
      const ch = document.body.offsetHeight;
      const wh = window.innerHeight;
      
      // Prevent bouncing false triggers
      if (st <= 0) {
        // Send previous chapter request
        // Since scroll can bounce, only send if user tries to scroll up AT top
        sendMessage('prev_chapter', {});
        // Prevent immediate re-triggering
        window.scrollTo(0, 10);
      } else if (st + wh >= ch) {
        sendMessage('next_chapter', {});
        window.scrollTo(0, st - 10);
      }
      isScrolling = false;
    }, 150);
  }, {passive: true});
</script>
</head>
<body>
''';

    // Setup the DOM structure
    fullHtml += '<div id="content-container"><div id="content">';
    if (chapter.title.isNotEmpty) {
      fullHtml += '<div class="chapter-title">${chapter.title}</div>';
    }
    fullHtml += htmlContent;
    fullHtml += '</div></div></body></html>';

    // Load into WebView base utf-8
    _controller.loadHtmlString(fullHtml);
  }

  @override
  void didUpdateWidget(EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // User changed settings (mode, font size, etc.)
    if (widget.settings != oldWidget.settings) {
      // For WebView, we must reload the HTML to inject new CSS and scripts
      _controller.setBackgroundColor(Color(widget.settings.backgroundColor));
      _loadCurrentChapter();
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
          // First frame: load chapter
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadCurrentChapter();
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
                      child: const Center(child: CircularProgressIndicator()),
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
