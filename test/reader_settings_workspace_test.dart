import 'dart:convert';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/features/settings/presentation/reader_settings_workspace.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _panel = find.byKey(const ValueKey('reader-settings-surface'));

Future<void> _openPreview(
  WidgetTester tester,
  Size size, {
  bool reducedMotion = false,
  double textScale = 1,
  String fontFamily = 'sans-serif',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    'reader_settings': jsonEncode(
      ReaderSettings(
        fontFamily: fontFamily,
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: false,
        fontSize: 24,
      ).toJson(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        readerSettingsProvider.overrideWith(
          (ref) => ReaderSettingsNotifier(prefs),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReaderCustomizationScreen(),
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open preview'));
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(EpubNativeView).evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
}

String _pageText(WidgetTester tester) => tester
    .widgetList<RichText>(
      find.descendant(
        of: find.byType(EpubNativeView),
        matching: find.byType(RichText),
      ),
    )
    .map((widget) => widget.text.toPlainText())
    .join('\n');

void main() {
  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    final wide = size.width >= 760;
    for (final textScale in [1.0, 1.6]) {
      testWidgets(
        'field labels stay inside the ${wide ? 'side' : 'bottom'} viewport at ${textScale}x text',
        (tester) async {
          await _openPreview(
            tester,
            size,
            textScale: textScale,
            fontFamily: 'Lora',
          );
          final label = tester.renderObject<RenderBox>(find.text('Font'));
          final viewport = RenderAbstractViewport.of(label);
          final labelRect = MatrixUtils.transformRect(
            label.getTransformTo(null),
            label.paintBounds,
          );
          final viewportRect = MatrixUtils.transformRect(
            viewport.getTransformTo(null),
            viewport.paintBounds,
          );
          expect(labelRect.top, greaterThanOrEqualTo(viewportRect.top));
          expect(labelRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
          final header = tester.getRect(find.text('Reader preview'));
          final category = tester.getRect(
            find.widgetWithText(ChoiceChip, 'Typography'),
          );
          final field = tester.getRect(
            find.byType(DropdownButtonFormField<String>),
          );
          expect(category.left, header.left);
          expect(field.left, header.left);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'sample stays readable and settings slide ${wide ? 'from left' : 'from bottom'}',
      (tester) async {
        await _openPreview(tester, size);
        final openPanel = tester.getRect(_panel);
        final openBook = tester.getRect(find.byType(EpubNativeView));
        if (wide) {
          expect(openPanel.left, 0);
          expect(openPanel.right, lessThanOrEqualTo(openBook.left));
        } else {
          expect(openPanel.bottom, size.height);
        }
        await tester.tap(find.byTooltip('Close reader settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        final closing = tester.getRect(_panel);
        if (wide) {
          expect(closing.left, lessThan(openPanel.left));
          expect(closing.right, greaterThan(0));
        } else {
          expect(closing.top, greaterThan(openPanel.top));
          expect(closing.top, lessThan(size.height));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ReaderCustomizationScreen), findsOneWidget);
        expect(find.text('Open preview'), findsNothing);
        final fullBook = tester.getRect(find.byType(EpubNativeView));
        expect(fullBook.width, size.width);
        expect(
          tester.getRect(find.byTooltip('Reader Settings')).bottom,
          lessThanOrEqualTo(fullBook.top),
          reason:
              'Reopening controls must not cover the first line of the page',
        );
        final before = _pageText(tester);
        await tester.tapAt(Offset(fullBook.right - 12, fullBook.center.dy));
        await tester.pumpAndSettle();
        final after = _pageText(tester);
        expect(after, isNot(before));
        final passage = after.trim().substring(0, 20);
        await tester.tap(find.byTooltip('Reader Settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final opening = tester.getRect(_panel);
        if (wide) {
          expect(opening.left, lessThan(0));
          expect(opening.right, greaterThan(0));
        } else {
          expect(opening.top, greaterThan(openPanel.top));
          expect(opening.top, lessThan(size.height));
        }
        await tester.pumpAndSettle();
        expect(tester.getRect(_panel), openPanel);
        expect(_pageText(tester), contains(passage));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'reduced motion opens and closes the ${wide ? 'left' : 'bottom'} panel immediately',
      (tester) async {
        await _openPreview(tester, size, reducedMotion: true);
        final openPanel = tester.getRect(_panel);
        await tester.tap(find.byTooltip('Close reader settings'));
        await tester.pump();
        final closedPanel = tester.getRect(_panel);
        if (wide) {
          expect(closedPanel.right, lessThanOrEqualTo(0));
        } else {
          expect(closedPanel.top, greaterThanOrEqualTo(size.height));
        }
        expect(find.byType(EpubNativeView), findsOneWidget);
        await tester.tap(find.byTooltip('Reader Settings'));
        await tester.pump();
        expect(tester.getRect(_panel), openPanel);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
