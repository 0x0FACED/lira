import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'epub_parser.dart';

/// Native Flutter EPUB reader — continuous vertical scroll
class EpubReaderView extends StatefulWidget {
  final ParsedEpub epub;
  final double initialScrollOffset;
  final void Function(double scrollOffset, double percentage)? onScrollProgress;

  const EpubReaderView({
    super.key,
    required this.epub,
    this.initialScrollOffset = 0.0,
    this.onScrollProgress,
  });

  @override
  State<EpubReaderView> createState() => EpubReaderViewState();
}

class EpubReaderViewState extends State<EpubReaderView> {
  late ScrollController _scrollController;
  bool _isRestoringPosition = false;
  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Restore position after content is rendered
    if (widget.initialScrollOffset > 0) {
      _isRestoringPosition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restorePosition();
      });
    }
  }

  void _restorePosition() {
    // Wait for a few frames so ListView can calculate content size
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = widget.initialScrollOffset.clamp(0.0, maxScroll);

      _scrollController.jumpTo(targetOffset);

      // Allow a moment for the jump to settle before enabling progress tracking
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isRestoringPosition = false;
          // Report initial position
          _reportProgress();
        }
      });
    });
  }

  void _onScroll() {
    if (_isRestoringPosition) return;
    if (!_scrollController.hasClients) return;

    // Debounce progress updates to avoid rapid state changes
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: widget.epub.chapters.length,
      itemBuilder: (context, index) {
        return _buildChapterView(widget.epub.chapters[index], index);
      },
    );
  }

  Widget _buildChapterView(EpubChapter chapter, int index) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chapter.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Text(
                  chapter.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            HtmlWidget(
              chapter.htmlContent,
              textStyle: const TextStyle(fontSize: 16, height: 1.7),
              onTapUrl: (url) {
                final chapterIdx = _findChapterByFileName(url);
                if (chapterIdx != null) {
                  // TODO: scroll to chapter
                }
                return true;
              },
              customWidgetBuilder: (element) {
                if (element.localName == 'img') {
                  final src = element.attributes['src'];
                  if (src != null) {
                    final imageData = _resolveImage(src);
                    if (imageData != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Image.memory(imageData, fit: BoxFit.contain),
                      );
                    }
                  }
                }
                return null;
              },
            ),
            if (index < widget.epub.chapters.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Divider(color: Colors.grey.withAlpha(80)),
              ),
          ],
        ),
      ),
    );
  }

  int? _findChapterByFileName(String fileName) {
    final cleanName = fileName.split('#').first;
    for (int i = 0; i < widget.epub.chapters.length; i++) {
      if (widget.epub.chapters[i].fileName == cleanName ||
          widget.epub.chapters[i].fileName.endsWith(cleanName)) {
        return i;
      }
    }
    return null;
  }

  Uint8List? _resolveImage(String src) {
    if (widget.epub.images.containsKey(src)) {
      return widget.epub.images[src];
    }
    final filename = src.split('/').last;
    for (final entry in widget.epub.images.entries) {
      if (entry.key.endsWith(filename)) {
        return entry.value;
      }
    }
    return null;
  }
}
