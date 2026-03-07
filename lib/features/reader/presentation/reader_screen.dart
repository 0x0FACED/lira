import 'dart:io';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/domain/models/book_dto.dart';
import '../domain/engine/book_reader_engine.dart';
import '../domain/engine/epub_book_reader_engine.dart';
import '../domain/engine/pdf_book_reader_engine.dart';
import '../domain/models/book_location.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../../highlights/domain/providers/highlights_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../../settings/presentation/settings_panel.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final BookDto book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late Future<BookReaderEngine> _engineFuture;
  BookReaderEngine? _engine;
  bool _showUi = false;
  double _readingProgress = 0.0;
  String _progressLabel = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tap detection
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;

  @override
  void initState() {
    super.initState();
    _engineFuture = _initEngine();
  }

  Future<BookReaderEngine> _initEngine() async {
    BookReaderEngine engine;

    if (widget.book.format == 'epub') {
      engine = EpubBookReaderEngine();
    } else if (widget.book.format == 'pdf') {
      engine = PdfBookReaderEngine();
    } else {
      throw UnsupportedError('Format ${widget.book.format} is not supported');
    }

    final file = File(widget.book.fileUrl!);
    final bytes = await file.readAsBytes();
    await engine.loadBook(bytes);

    _engine = engine;
    return engine;
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressAsyncValue = ref.watch(
      readingProgressControllerProvider(widget.book.id),
    );
    final settings = ref.watch(readerSettingsProvider);

    return FutureBuilder<BookReaderEngine>(
      future: _engineFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final engine = snapshot.data;
        if (engine == null) {
          return const Scaffold(
            body: Center(child: Text('Failed to initialize reader engine.')),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: _buildTocDrawer(engine),
          body: Stack(
            children: [
              // Reader content — full screen
              Positioned.fill(
                child: Container(
                  color: Color(settings.backgroundColor),
                  child: Listener(
                    onPointerDown: (e) {
                      _pointerDownPos = e.position;
                      _pointerDownTime = DateTime.now();
                    },
                    onPointerUp: (e) {
                      if (_pointerDownPos != null && _pointerDownTime != null) {
                        final dist = (e.position - _pointerDownPos!).distance;
                        final dur = DateTime.now().difference(_pointerDownTime!);
                        if (dist < 20 && dur.inMilliseconds < 300) {
                          _toggleUi();
                        }
                      }
                      _pointerDownPos = null;
                      _pointerDownTime = null;
                    },
                    child: progressAsyncValue.when(
                      data: (progress) {
                        return engine.buildReaderWidget(
                          context: context,
                          settings: settings,
                          theme: Theme.of(context),
                          initialLocation: progress != null
                              ? BookLocation(locator: progress.location)
                              : const BookLocation(locator: ''),
                          onProgressChanged: (location, percentage) {
                            setState(() {
                              _readingProgress = percentage.clamp(0, 100) / 100;
                              _progressLabel =
                                  '${percentage.toStringAsFixed(1)}%';
                            });
                            ref
                                .read(
                                  readingProgressControllerProvider(
                                    widget.book.id,
                                  ).notifier,
                                )
                                .saveProgress(
                                  location: location.locator,
                                  percentage: percentage,
                                );
                          },
                          onTextSelected: (text, location) {
                            ref
                                .read(
                                  highlightsControllerProvider(
                                    widget.book.id,
                                  ).notifier,
                                )
                                .addHighlight(
                                  text: text,
                                  location: location.locator,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Highlight saved'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) =>
                          Center(child: Text('Error loading progress')),
                    ),
                  ),
                ),
              ),

              // Top bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                top: _showUi ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black87,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.book.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                bottom: _showUi ? 0 : -120,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black87,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _readingProgress,
                                    backgroundColor: Colors.white24,
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  _progressLabel,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Buttons row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.format_list_bulleted,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: 'Table of Contents',
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: 'Settings',
                                onPressed: () => _showSettings(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Drawer _buildTocDrawer(BookReaderEngine engine) {
    final toc = engine.getToc();

    if (toc.isEmpty) {
      return Drawer(
        child: Center(
          child: Text(
            'Table of Contents is not available.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Contents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: toc.length,
                itemBuilder: (context, index) {
                  return _buildTocItem(toc[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTocItem(TOCItem item, {int depth = 0}) {
    final padding = 16.0 + (depth * 16.0);

    if (item.subItems.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: padding),
        title: Text(item.title),
        onTap: () {
          _engine?.goToLocation(BookLocation(locator: item.fileName));
          Navigator.pop(context);
          if (_showUi) _toggleUi();
        },
      );
    }

    // Parent item with separate expand arrow
    return _ExpandableTocItem(
      item: item,
      padding: padding,
      depth: depth,
      onNavigate: (fileName) {
        _engine?.goToLocation(BookLocation(locator: fileName));
        Navigator.pop(context);
        if (_showUi) _toggleUi();
      },
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettingsPanel(),
    );
  }
}

/// Expandable TOC item with separate navigate/expand controls
class _ExpandableTocItem extends StatefulWidget {
  final TOCItem item;
  final double padding;
  final int depth;
  final void Function(String fileName) onNavigate;

  const _ExpandableTocItem({
    required this.item,
    required this.padding,
    required this.depth,
    required this.onNavigate,
  });

  @override
  State<_ExpandableTocItem> createState() => _ExpandableTocItemState();
}

class _ExpandableTocItemState extends State<_ExpandableTocItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: widget.padding),
          leading: IconButton(
            icon: Icon(
              _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
          title: Text(widget.item.title),
          onTap: () => widget.onNavigate(widget.item.fileName),
        ),
        if (_expanded)
          ..._buildSubItems(widget.item.subItems),
      ],
    );
  }

  List<Widget> _buildSubItems(List<TOCItem> items) {
    return items.map((item) {
      if (item.subItems.isEmpty) {
        return ListTile(
          contentPadding: EdgeInsets.only(left: widget.padding + 16),
          title: Text(item.title),
          onTap: () => widget.onNavigate(item.fileName),
        );
      }

      // Nested expandable
      return _ExpandableTocItem(
        item: item,
        padding: widget.padding + 16,
        depth: widget.depth + 1,
        onNavigate: widget.onNavigate,
      );
    }).toList();
  }
}
