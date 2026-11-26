import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/presentation/book_page_progress.dart';
import 'package:lira/features/books/presentation/widgets/book_card.dart';
import 'package:lira/l10n/app_localizations.dart';

void main() {
  BookDto book({String format = 'epub', int total = 9999}) => BookDto(
    id: 'pages',
    title: 'A long book title that must still keep its two reserved lines',
    author: 'Author',
    format: format,
    pageCount: total,
    createdAt: DateTime(2026),
  );

  test('PDF pages use saved page locators, not percentage estimates', () {
    final pdf = book(format: 'pdf', total: 200);
    expect(bookPageProgress(book: pdf, percentage: 15, location: '37'), (
      current: 37,
      total: 200,
      approximate: false,
    ));
    for (final location in [null, '', 'invalid', '0', '201']) {
      expect(bookPageProgress(book: pdf, percentage: 15, location: location), (
        current: null,
        total: 200,
        approximate: false,
      ));
    }
    expect(
      bookPageProgress(
        book: pdf,
        percentage: 15,
        location:
            '{"pdf":1,"p":37,"s":[{"p":37,"r":[[0,2]],'
            '"q":[[1,2,2,1]]}]}',
      ),
      (current: 37, total: 200, approximate: false),
    );
  });

  test('EPUB pages remain estimates from actual reading percentage', () {
    final epub = book(total: 200);
    expect(bookPageProgress(book: epub, percentage: 15), (
      current: 30,
      total: 200,
      approximate: true,
    ));
    expect(bookPageProgress(book: epub), (
      current: null,
      total: 200,
      approximate: true,
    ));
    expect(bookPageProgress(book: epub, percentage: double.nan), (
      current: null,
      total: 200,
      approximate: true,
    ));
    expect(bookPageProgress(book: epub, percentage: 0), (
      current: 1,
      total: 200,
      approximate: true,
    ));
    expect(bookPageProgress(book: book(total: 0), percentage: 15), isNull);
  });

  for (final compact in [false, true]) {
    for (final width in compact ? [160.0, 312.0] : [72.0, 88.0, 136.0, 300.0]) {
      for (final scale in [0.8, 1.0, 2.0, 2.5]) {
        for (final total in [1234, 9999]) {
          testWidgets(
            '${compact ? 'list' : 'grid'} $total pages fit $width at $scale',
            (tester) async {
              final value = book(total: total);
              late String progressLabel;
              late String compactProgressLabel;
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.darkTheme,
                  locale: const Locale('ru'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            final counts = NumberFormat.decimalPattern(
                              l10n.localeName,
                            );
                            final current = (42.79 * total / 100).ceil();
                            final coordinates =
                                '≈${counts.format(current)}/${counts.format(total)}';
                            progressLabel =
                                '${l10n.bookPageCountCompact(coordinates)} · 42,7%';
                            compactProgressLabel = '$coordinates · 42,7%';
                            final contentWidth = width - 2 * BookCard.hitInset;
                            return SizedBox(
                              width: width,
                              height: compact
                                  ? null
                                  : contentWidth / BookCard.coverAspectRatio +
                                        BookCard.metadataExtent(context) +
                                        2 * BookCard.hitInset,
                              child: BookCard(
                                book: value,
                                compact: compact,
                                readingPercentage: 42.79,
                                onTap: () {},
                                onLongPress: (_) {},
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
              expect(tester.takeException(), isNull);
              final label = find.byKey(
                const ValueKey('book-card-progress-label'),
              );
              final visibleLabel = tester.widget<Text>(label);
              expect(
                visibleLabel.data,
                anyOf(progressLabel, compactProgressLabel),
              );
              final semantics = tester.widget<Semantics>(
                find
                    .ancestor(of: label, matching: find.byType(Semantics))
                    .first,
              );
              expect(semantics.properties.value, progressLabel);
              final metadata = find.byKey(const ValueKey('book-card-format'));
              expect(metadata, findsOneWidget);
              expect(tester.widget<Text>(metadata).data, 'EPUB');
              expect(
                tester
                    .renderObject<RenderParagraph>(metadata)
                    .didExceedMaxLines,
                isFalse,
              );
              expect(find.byIcon(Icons.check), findsNothing);
              final progress = tester.widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              );
              expect(progress.value, closeTo(0.4279, 0.00001));
              final card = tester.getRect(find.byType(BookCard));
              final paragraph = tester.renderObject<RenderParagraph>(label);
              expect(paragraph.didExceedMaxLines, isFalse);
              final text = tester.getRect(label);
              final formatRect = tester.getRect(metadata);
              final row = tester.getRect(
                find.byKey(const ValueKey('book-card-metadata-row')),
              );
              expect(text.left, greaterThan(formatRect.right));
              expect(text.right, closeTo(row.right, 0.01));
              expect(formatRect.left, closeTo(row.left, 0.01));
              expect(text.top, greaterThanOrEqualTo(row.top - 0.01));
              expect(text.bottom, lessThanOrEqualTo(row.bottom + 0.01));
              expect(text.bottom, lessThanOrEqualTo(card.bottom));
              expect(formatRect.top, lessThan(text.bottom));
              expect(text.top, lessThan(formatRect.bottom));
              final track = tester.getRect(
                find.byType(LinearProgressIndicator),
              );
              expect(track.top, greaterThan(row.bottom));
            },
          );
        }
      }
    }
  }

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets(
      'metadata keeps full units and directional edges in $direction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: SizedBox(
                  width: 600,
                  child: BookCard(
                    book: book(total: 300),
                    compact: true,
                    readingPercentage: 15,
                    onTap: () {},
                    onLongPress: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(BookCard));
        final l10n = AppLocalizations.of(context)!;
        final label = find.byKey(const ValueKey('book-card-progress-label'));
        final text = tester.widget<Text>(label);
        expect(text.data, '${l10n.bookPageCountCompact('≈45/300')} · 15,0%');
        expect(text.textDirection, TextDirection.ltr);
        final formatRect = tester.getRect(
          find.byKey(const ValueKey('book-card-format')),
        );
        final labelRect = tester.getRect(label);
        final rowRect = tester.getRect(
          find.byKey(const ValueKey('book-card-metadata-row')),
        );
        expect(formatRect.top, closeTo(labelRect.top, 0.01));
        if (direction == TextDirection.ltr) {
          expect(formatRect.left, closeTo(rowRect.left, 0.01));
          expect(labelRect.right, closeTo(rowRect.right, 0.01));
        } else {
          expect(formatRect.right, closeTo(rowRect.right, 0.01));
          expect(labelRect.left, closeTo(rowRect.left, 0.01));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('no saved position retains the total without a progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: BookCard(
              book: book(total: 200),
              compact: true,
              onTap: () {},
              onLongPress: (_) {},
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(BookCard));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.bookPageCountCompact('≈200')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
