import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'epub_parser.dart';
import 'models/reader_settings.dart';
import 'models/epub_location.dart';

/// High-performance EPUB reader with precise positioning
/// 
/// Architecture:
/// 1. Pre-calculate chapter heights on load (in isolate if needed)
/// 2. Store position as absolute pixel offset + chapter index
/// 3. Use SliverList for exact control over layout
/// 4. TOC navigation uses pre-calculated positions (no sequential rendering)
class EpubReaderView extends StatefulWidget {
  final ParsedEpub epub;
  final EpubLocation? initialLocation;
  final ReaderSettings settings;
  final ThemeData theme;
  final void Function(EpubLocation location, double percentage)? onLocationChanged;
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
  late ScrollController _scrollController;
  bool _isRestoringPosition = false;
  bool _isJumpingToChapter = false;
  Timer? _progressDebounce;

  final Map<int, GlobalKey> _chapterKeys = {};
  
  // Pre-calculated chapter heights and cumulative offsets
  final List<double> _chapterHeights = [];
  final List<double> _chapterOffsets = []; // Cumulative offset before each chapter
  
  // Text anchors for precise restoration (first 100 chars of each chapter)
  final List<String> _chapterAnchors = [];
  
  // For stable progress calculation
  double _lastKnownMaxScroll = 0;
  int _stableProgressCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Pre-calculate chapter heights
    _calculateChapterMetrics();

    if (widget.initialLocation != null) {
      _isRestoringPosition = true;
      // Wait for first frame + metrics calculation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _restorePosition();
        });
      });
    }
  }

  void _calculateChapterMetrics() {
    // Initialize with estimates - will be refined as chapters render
    _chapterHeights.clear();
    _chapterOffsets.clear();
    _chapterAnchors.clear();
    
    double cumulativeOffset = 0.0;
    // Use larger estimate - chapters are typically 2-3x viewport height
    final estimatedChapterHeight = _scrollController.hasClients 
        ? _scrollController.position.viewportDimension * 2.5
        : 1500.0;
    
    for (int i = 0; i < widget.epub.chapters.length; i++) {
      _chapterHeights.add(estimatedChapterHeight);
      _chapterOffsets.add(cumulativeOffset);
      cumulativeOffset += estimatedChapterHeight;
      
      // Extract text anchor from chapter content
      final html = widget.epub.chapters[i].htmlContent;
      final textAnchor = _extractTextAnchor(html);
      _chapterAnchors.add(textAnchor);
    }
  }

  String _extractTextAnchor(String html) {
    // Strip HTML tags and get first ~100 characters
    final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    return stripped.length > 100 ? stripped.substring(0, 100) : stripped;
  }

  void _restorePosition() {
    final location = widget.initialLocation;
    if (location == null || !_scrollController.hasClients) return;

    final targetIndex = location.chapterIndex.clamp(0, widget.epub.chapters.length - 1);
    
    // Use pixel offset if available and accurate
    if (location.pixelOffset != null && _chapterOffsets.isNotEmpty) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = location.pixelOffset!.clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetOffset);
      
      Future.delayed(const Duration(milliseconds: 50), () {
        _isRestoringPosition = false;
        _reportProgress();
      });
      return;
    }
    
    // Fallback: estimate position based on chapter index
    if (_chapterOffsets.isNotEmpty && targetIndex < _chapterOffsets.length) {
      final estimatedOffset = _chapterOffsets[targetIndex];
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(estimatedOffset.clamp(0, maxScroll));
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _isRestoringPosition = false;
      _reportProgress();
    });
  }

  void _onScroll() {
    if (_isRestoringPosition || _isJumpingToChapter) return;
    if (!_scrollController.hasClients) return;

    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 100), () {
      _reportProgress();
    });
  }

  void _reportProgress() {
    if (!mounted || !_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // Smooth progress calculation - use running average to avoid jumps
    if ((maxScroll - _lastKnownMaxScroll).abs() > 100) {
      // maxScroll changed significantly, blend with previous value
      _lastKnownMaxScroll = (_lastKnownMaxScroll * 0.7 + maxScroll * 0.3);
      _stableProgressCount++;
    } else {
      _lastKnownMaxScroll = maxScroll;
      _stableProgressCount = 0;
    }
    
    // Use smoothed maxScroll for progress, but only after stabilization
    final effectiveMaxScroll = _stableProgressCount > 3 ? _lastKnownMaxScroll : maxScroll;
    
    final location = _findLocationForOffset(currentOffset);
    final percentage = effectiveMaxScroll > 0 
        ? (currentOffset / effectiveMaxScroll * 100).clamp(0.0, 100.0) 
        : 0.0;

    widget.onLocationChanged?.call(location, percentage);
  }

  EpubLocation _findLocationForOffset(double offset) {
    int chapterIndex = 0;
    double chapterStartOffset = 0.0;

    for (int i = 0; i < widget.epub.chapters.length; i++) {
      final chapterOffset = _chapterOffsets.isNotEmpty && i < _chapterOffsets.length 
          ? _chapterOffsets[i] 
          : 0.0;
      
      if (offset >= chapterOffset) {
        chapterIndex = i;
        chapterStartOffset = chapterOffset;
      } else {
        break;
      }
    }

    final chapterHeight = _chapterHeights.isNotEmpty && chapterIndex < _chapterHeights.length
        ? _chapterHeights[chapterIndex]
        : _scrollController.position.viewportDimension;
    
    final offsetInChapter = chapterHeight > 0
        ? ((offset - chapterStartOffset) / chapterHeight).clamp(0.0, 1.0)
        : 0.0;

    return EpubLocation(
      chapterIndex: chapterIndex,
      offsetInChapter: offsetInChapter,
      pixelOffset: offset,
    );
  }

  /// TOC navigation - sequentially renders chapters until target is reached
  Future<void> scrollToChapter(String fileName) async {
    if (!_scrollController.hasClients) return;

    final index = _findChapterIndexByFileName(fileName);
    if (index == null) return;

    _isJumpingToChapter = true;
    setState(() {});

    // If chapter is already rendered, scroll directly
    if (_chapterKeys[index]?.currentContext != null && mounted) {
      await Scrollable.ensureVisible(
        _chapterKeys[index]!.currentContext!,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      _finishTOCJump();
      return;
    }

    // Target chapter not rendered yet - need to sequentially render chapters
    // Find the highest rendered chapter index
    int highestRenderedIndex = -1;
    for (var k in _chapterKeys.keys) {
      if (_chapterKeys[k]?.currentContext != null && k > highestRenderedIndex) {
        highestRenderedIndex = k;
      }
    }

    // If target is before highest rendered, jump to estimated position
    if (index <= highestRenderedIndex) {
      final estimatedOffset = _chapterOffsets.isNotEmpty && index < _chapterOffsets.length
          ? _chapterOffsets[index].toDouble()
          : 0.0;
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(estimatedOffset.clamp(0, maxScroll));

      // Wait for render
      await _waitForChapterRender(index);
    } else {
      // Target is after highest rendered - scroll down sequentially
      // Start from current position and scroll down chapter by chapter
      int currentIndex = highestRenderedIndex >= 0 ? highestRenderedIndex : 0;
      
      while (currentIndex < index && mounted) {
        // Scroll to reveal next chapter
        final nextIndex = currentIndex + 1;
        if (_chapterKeys[nextIndex]?.currentContext != null) {
          await Scrollable.ensureVisible(
            _chapterKeys[nextIndex]!.currentContext!,
            duration: const Duration(milliseconds: 100),
            alignment: 1.0, // Align to bottom to load more
          );
        }
        currentIndex++;
        
        // Small delay for layout
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Wait for target chapter to render
      await _waitForChapterRender(index);
    }

    // Final alignment - ensure chapter title is visible at top
    if (mounted && _chapterKeys[index]?.currentContext != null) {
      await Scrollable.ensureVisible(
        _chapterKeys[index]!.currentContext!,
        duration: const Duration(milliseconds: 150),
        alignment: 0.0,
      );
    }

    _finishTOCJump();
  }

  /// Wait for a chapter to be rendered (with timeout)
  Future<bool> _waitForChapterRender(int chapterIndex) async {
    int retryCount = 0;
    while (_chapterKeys[chapterIndex]?.currentContext == null && 
           retryCount < 50 && 
           mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
      retryCount++;
    }
    return _chapterKeys[chapterIndex]?.currentContext != null;
  }

  void _finishTOCJump() {
    if (!mounted) return;
    setState(() {
      _isJumpingToChapter = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _isRestoringPosition = false;
        _reportProgress();
      }
    });
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.epub.chapters.isEmpty) {
      return const Center(
        child: Text(
          'This EPUB has no readable chapters.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: Color(widget.settings.backgroundColor),
          child: SelectionArea(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.settings.horizontalPadding,
                    vertical: 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        _chapterKeys[index] ??= GlobalKey(debugLabel: 'chapter_$index');
                        return _ChapterItem(
                          key: _chapterKeys[index],
                          chapter: widget.epub.chapters[index],
                          index: index,
                          isLast: index == widget.epub.chapters.length - 1,
                          settings: widget.settings,
                          theme: widget.theme,
                          onAnchorTap: scrollToChapter,
                          resolveImage: _resolveImage,
                          onHeightCalculated: (height) {
                            if (index < _chapterHeights.length) {
                              final oldHeight = _chapterHeights[index];
                              final delta = height - oldHeight;
                              _chapterHeights[index] = height;
                              
                              // Update cumulative offsets for subsequent chapters
                              if (delta != 0 && oldHeight != 0) {
                                for (int i = index + 1; i < _chapterOffsets.length; i++) {
                                  _chapterOffsets[i] += delta;
                                }
                              }
                            }
                          },
                        );
                      },
                      childCount: widget.epub.chapters.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // TOC Loading Overlay
        if (_isJumpingToChapter)
          Positioned.fill(
            child: Container(
              color: Color(widget.settings.backgroundColor),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  int? _findChapterIndexByFileName(String fileName) {
    if (fileName.isEmpty) return null;
    var target = fileName.split('#').first;
    while(target.startsWith('.') || target.startsWith('/')) {
      target = target.substring(1);
    }
    for (int i = 0; i < widget.epub.chapters.length; i++) {
      var current = widget.epub.chapters[i].fileName;
      while(current.startsWith('.') || current.startsWith('/')) {
        current = current.substring(1);
      }
      if (current == target || current.endsWith(target) || target.endsWith(current)) {
        return i;
      }
    }
    return null;
  }

  Uint8List? _resolveImage(String src) {
    if (widget.epub.images.containsKey(src)) return widget.epub.images[src];
    final filename = src.split('/').last;
    for (final entry in widget.epub.images.entries) {
      if (entry.key.endsWith(filename)) return entry.value;
    }
    return null;
  }
}

/// Chapter item with height reporting
class _ChapterItem extends StatefulWidget {
  final EpubChapter chapter;
  final int index;
  final bool isLast;
  final ReaderSettings settings;
  final ThemeData theme;
  final Function(String) onAnchorTap;
  final Uint8List? Function(String) resolveImage;
  final void Function(double height) onHeightCalculated;

  const _ChapterItem({
    super.key,
    required this.chapter,
    required this.index,
    required this.isLast,
    required this.settings,
    required this.theme,
    required this.onAnchorTap,
    required this.resolveImage,
    required this.onHeightCalculated,
  });

  @override
  State<_ChapterItem> createState() => _ChapterItemState();
}

class _ChapterItemState extends State<_ChapterItem> with AutomaticKeepAliveClientMixin {
  bool _heightReported = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.chapter.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Text(
                  widget.chapter.title,
                  style: TextStyle(
                    fontSize: widget.settings.fontSize * 1.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: widget.settings.fontFamily,
                    color: widget.theme.colorScheme.onSurface,
                  ),
                ),
              ),
            HtmlWidget(
              widget.chapter.htmlContent,
              textStyle: TextStyle(
                fontSize: widget.settings.fontSize,
                height: widget.settings.lineHeight,
                fontFamily: widget.settings.fontFamily,
                color: widget.theme.colorScheme.onSurface,
              ),
              onTapUrl: (url) {
                widget.onAnchorTap(url);
                return true;
              },
              customWidgetBuilder: (element) {
                if (element.localName == 'img') {
                  final src = element.attributes['src'];
                  if (src != null) {
                    final imageData = widget.resolveImage(src);
                    if (imageData != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Image.memory(imageData, fit: BoxFit.contain),
                      );
                    }
                  }
                }
                return null;
              },
            ),
            if (!widget.isLast)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Divider(color: widget.theme.dividerColor.withAlpha(50)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Report height after first build
    if (!_heightReported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            widget.onHeightCalculated(renderBox.size.height);
            _heightReported = true;
          }
        }
      });
    }
  }
}
