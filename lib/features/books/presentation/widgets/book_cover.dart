import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/models/book_dto.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book});

  static const aspectRatio = 2 / 3;

  final BookDto book;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Semantics(
        image: true,
        label: book.title,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: _buildArtwork(context),
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context) {
    final path = book.coverUrl;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => TypographicBookCover(
          title: book.title,
          author: book.author,
          format: book.format,
        ),
      );
    }
    return TypographicBookCover(
      title: book.title,
      author: book.author,
      format: book.format,
    );
  }
}

class TypographicBookCover extends StatelessWidget {
  const TypographicBookCover({
    super.key,
    required this.title,
    required this.author,
    required this.format,
  });

  final String title;
  final String author;
  final String format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final paper = switch (title.hashCode.abs() % 3) {
      0 => colors.surfaceContainer,
      1 => colors.surfaceContainerHigh,
      _ => colors.surfaceContainerHighest,
    };
    // Generated artwork behaves like an image; accessible text outside the
    // cover retains the full title/author and follows interface text scaling.
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = (constraints.maxWidth * 0.1).clamp(8.0, 24.0);
            return ColoredBox(
              color: paper,
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: (constraints.maxWidth * 0.055).clamp(
                          9.0,
                          12.0,
                        ),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title.trim(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: (constraints.maxWidth * 0.12).clamp(
                              12.0,
                              26.0,
                            ),
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      format.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
