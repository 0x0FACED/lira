import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'epub_parser.dart';
import 'models/reader_settings.dart';

/// Native Flutter EPUB reader — continuous vertical scroll
class EpubReaderView extends StatefulWidget {
  final ParsedEpub epub;
  final double initialScrollOffset;
  final ReaderSettings settings;
  final ThemeData theme;
  final void Function(double scrollOffset, double percentage)? onScrollProgress;
  final void Function(String text, String location)? onTextSelected;

  const EpubReaderView({
    super.key,
    required this.epub,
    required this.settings,
    required this.theme,
    this.initialScrollOffset = 0.0,
    this.onScrollProgress,
    this.onTextSelected,
  });

  @override
  State<EpubReaderView> createState() => EpubReaderViewState();
}

class EpubReaderViewState extends State<EpubReaderView> {
  late ScrollController _scrollController;
  bool _isRestoringPosition = false;
  Timer? _progressDebounce;
  
  final Map<int, GlobalKey> _chapterKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    if (widget.initialScrollOffset > 0) {
      _isRestoringPosition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restorePosition();
      });
    }
  }

  void _restorePosition() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = widget.initialScrollOffset.clamp(0.0, maxScroll);

      _scrollController.jumpTo(targetOffset);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isRestoringPosition = false;
          _reportProgress();
        }
      });
    });
  }

  void _onScroll() {
    if (_isRestoringPosition) return;
    if (!_scrollController.hasClients) return;

    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 200), () {
      _reportProgress();
    });
  }

  void _reportProgress() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final current = _scrollController.offset;
    final percentage = (current / maxScroll * 100).clamp(0.0, 100.0);

    widget.onScrollProgress?.call(current, percentage);
  }

  void scrollToChapter(String fileName) async {
    if (!_scrollController.hasClients) return;

    final index = _findChapterIndexByFileName(fileName);
    if (index == null) return;

    _isRestoringPosition = true;

    // 1. If it's already built, jump directly and accurately
    if (_chapterKeys[index]?.currentContext != null) {
      await Scrollable.ensureVisible(
        _chapterKeys[index]!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    } else {
      // 2. If not built (lazy list), jump to an estimated position.
      // Removed the chaotic scanning loop. This provides a clean jump.
      double estimatedOffset = index * 3000.0; // Rough guess per chapter
      if (estimatedOffset > _scrollController.position.maxScrollExtent) {
        estimatedOffset = _scrollController.position.maxScrollExtent;
      }
      _scrollController.jumpTo(estimatedOffset);
      
      // Wait a frame for builder to trigger, then try to lock precisely if available
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _chapterKeys[index]?.currentContext != null) {
        Scrollable.ensureVisible(
          _chapterKeys[index]!.currentContext!,
          duration: const Duration(milliseconds: 200),
          alignment: 0.0,
        );
      }
    }

    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 200), () {
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

    return Container(
      color: Color(widget.settings.backgroundColor),
      child: SelectionArea(
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: widget.settings.horizontalPadding,
            vertical: 16,
          ),
          itemCount: widget.epub.chapters.length,
          itemBuilder: (context, index) {
            _chapterKeys[index] ??= GlobalKey(debugLabel: 'chapter_$index');
            // Use our stateful KeepAlive wrapper
            return _ChapterItem(
              key: _chapterKeys[index],
              chapter: widget.epub.chapters[index],
              index: index,
              isLast: index == widget.epub.chapters.length - 1,
              settings: widget.settings,
              theme: widget.theme,
              onAnchorTap: scrollToChapter,
              resolveImage: _resolveImage,
            );
          },
        ),
      ),
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

/// A stateful wrapper that implements AutomaticKeepAliveClientMixin.
/// This PREVENTS the layout jump when scrolling upwards, because once
/// a chapter is rendered, its exact height is kept in memory!
class _ChapterItem extends StatefulWidget {
  final EpubChapter chapter;
  final int index;
  final bool isLast;
  final ReaderSettings settings;
  final ThemeData theme;
  final Function(String) onAnchorTap;
  final Uint8List? Function(String) resolveImage;

  const _ChapterItem({
    super.key,
    required this.chapter,
    required this.index,
    required this.isLast,
    required this.settings,
    required this.theme,
    required this.onAnchorTap,
    required this.resolveImage,
  });

  @override
  State<_ChapterItem> createState() => _ChapterItemState();
}

class _ChapterItemState extends State<_ChapterItem> with AutomaticKeepAliveClientMixin {
  
  // This is the magic that fixes the scroll-up jump issue.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
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
}
