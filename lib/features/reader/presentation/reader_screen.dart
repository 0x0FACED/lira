import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/domain/models/book_dto.dart';
import '../domain/engine/book_reader_engine.dart';
import '../domain/engine/epub_book_reader_engine.dart';
import '../domain/engine/pdf_book_reader_engine.dart';
import '../domain/models/book_location.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../../highlights/domain/providers/highlights_provider.dart';

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
          body: Stack(
            children: [
              // Reader content — full screen
              Positioned.fill(
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
                                onPressed: () => _showToc(context),
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

  void _showToc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Table of Contents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'TOC will be available in a future update.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reader Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Font size, theme, and other settings will be available in a future update.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
