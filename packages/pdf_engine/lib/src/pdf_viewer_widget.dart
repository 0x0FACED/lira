import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// PDF viewer widget backed by pdfrx (all platforms including Linux).
///
/// Now supports: background color, page tracking with total pages,
/// TOC extraction via [onDocumentLoaded], and programmatic navigation
/// via [controller].
class PdfViewerWidget extends StatefulWidget {
  final Uint8List data;
  final int initialPage;
  final Color backgroundColor;
  final PdfViewerController? controller;
  final void Function(int page, int totalPages)? onPageChanged;
  final void Function(PdfDocument document)? onDocumentLoaded;

  const PdfViewerWidget({
    super.key,
    required this.data,
    this.initialPage = 1,
    this.backgroundColor = Colors.white,
    this.controller,
    this.onPageChanged,
    this.onDocumentLoaded,
  });

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  late final PdfViewerController _controller;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PdfViewerController();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: PdfViewer.data(
        widget.data,
        sourceName: 'book.pdf',
        controller: _controller,
        initialPageNumber: widget.initialPage,
        params: PdfViewerParams(
          enableTextSelection: true,
          backgroundColor: widget.backgroundColor,
          onViewerReady: (document, controller) {
            _totalPages = document.pages.length;
            widget.onDocumentLoaded?.call(document);
          },
          onPageChanged: (pageNumber) {
            if (widget.onPageChanged != null && pageNumber != null) {
              widget.onPageChanged!(pageNumber, _totalPages);
            }
          },
        ),
      ),
    );
  }
}
