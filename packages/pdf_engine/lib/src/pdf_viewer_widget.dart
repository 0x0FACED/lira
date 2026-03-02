import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// PDF viewer widget backed by pdfrx (all platforms including Linux)
class PdfViewerWidget extends StatelessWidget {
  final Uint8List data;
  final int initialPage;
  final void Function(int page, int totalPages)? onPageChanged;

  const PdfViewerWidget({
    super.key,
    required this.data,
    this.initialPage = 1,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PdfViewer.data(
      data,
      sourceName: 'book.pdf',
      initialPageNumber: initialPage,
      params: PdfViewerParams(
        enableTextSelection: true,
        onPageChanged: (pageNumber) {
          if (onPageChanged != null && pageNumber != null) {
            onPageChanged!(pageNumber, 0);
          }
        },
      ),
    );
  }
}
