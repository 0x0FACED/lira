import 'dart:convert';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/core/widgets/app_text_scaling.dart';
import 'package:lira/features/settings/data/interface_font_scale_provider.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/features/settings/presentation/settings_screen.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SystemTextCurve extends TextScaler {
  const _SystemTextCurve();

  @override
  double scale(double fontSize) => fontSize * (fontSize < 20 ? 1.4 : 1.15);

  @override
  double get textScaleFactor => scale(14) / 14;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    await sharedPrefs.clear();
    await sharedPrefs.setString(
      'reader_settings',
      jsonEncode(const ReaderSettings(fontSize: 24).toJson()),
    );
  });

  test(
    'interface size survives reopening independently of reader size',
    () async {
      final interface = InterfaceFontScaleNotifier(sharedPrefs);
      addTearDown(interface.dispose);
      await interface.setPercent(80);
      await sharedPrefs.reload();
      final reopened = InterfaceFontScaleNotifier(sharedPrefs);
      final reader = ReaderSettingsNotifier(sharedPrefs);
      addTearDown(reopened.dispose);
      addTearDown(reader.dispose);
      expect(reopened.state, 80);
      expect(reader.state.fontSize, 24);
      await reader.updateSettings(reader.state.copyWith(fontSize: 30));
      await reader.flush();
      await sharedPrefs.reload();
      final afterReaderEdit = InterfaceFontScaleNotifier(sharedPrefs);
      addTearDown(afterReaderEdit.dispose);
      expect(afterReaderEdit.state, 80);
    },
  );

  testWidgets(
    'interface size preserves nonlinear system accessibility scaling',
    (tester) async {
      await sharedPrefs.setInt(InterfaceFontScaleNotifier.storageKey, 140);
      late TextScaler effective;
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: _SystemTextCurve()),
            child: AppTextScaling(
              child: Builder(
                builder: (context) {
                  effective = MediaQuery.textScalerOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(effective.scale(16), closeTo(31.36, 0.001));
      expect(effective.scale(28), closeTo(45.08, 0.001));
    },
  );

  testWidgets('font size control keeps its title readable on a narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await sharedPrefs.setInt(InterfaceFontScaleNotifier.storageKey, 140);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppTextScaling(child: child!),
          home: const TickerMode(enabled: false, child: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.text('Interface font size');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(title);
    final firstWord = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 9),
    );
    expect(
      firstWord,
      hasLength(1),
      reason: 'The value must not squeeze the label into fragments',
    );
    expect(tester.takeException(), isNull);
  });

  for (final mode in ReadingMode.values) {
    testWidgets(
      'interface scaling leaves ${mode.name} reader glyphs unchanged',
      (tester) async {
        final book = ParsedEpub(
          title: 'Independent typography',
          author: 'Lira',
          language: 'en',
          chapters: [
            EpubChapter(
              title: 'Text',
              fileName: 'text.xhtml',
              htmlContent:
                  '<html><body><p>Independent reader paragraph. '
                  '${'Text size belongs to the book reader. ' * 12}'
                  '</p></body></html>',
            ),
          ],
          toc: const [],
          images: const {},
        );
        await sharedPrefs.setString(
          'reader_settings',
          jsonEncode(
            ReaderSettings(
              fontSize: 24,
              readingMode: mode,
              enableDualPageSpread: false,
            ).toJson(),
          ),
        );
        final readerKey = GlobalKey<EpubNativeViewState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const _SystemTextCurve()),
                child: AppTextScaling(child: child!),
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 340,
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 80,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text('Interface label'),
                          ),
                        ),
                        SizedBox(
                          height: 400,
                          child: Consumer(
                            builder: (context, ref, _) => EpubNativeView(
                              key: readerKey,
                              epub: book,
                              settings: ref.watch(readerSettingsProvider),
                              theme: Theme.of(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppTextScaling)),
        );
        final state = readerKey.currentState;
        final originalGlyph = _readerGlyph(tester);
        final originalLabelHeight = tester
            .getSize(find.text('Interface label'))
            .height;
        await container
            .read(interfaceFontScaleProvider.notifier)
            .setPercent(140);
        await tester.pumpAndSettle();
        expect(_readerGlyph(tester), originalGlyph);
        expect(readerKey.currentState, same(state));
        expect(
          tester.getSize(find.text('Interface label')).height,
          greaterThan(originalLabelHeight),
        );
        final settings = container.read(readerSettingsProvider.notifier);
        await settings.updateSettings(settings.state.copyWith(fontSize: 30));
        await settings.flush();
        await tester.pumpAndSettle();
        expect(_readerGlyph(tester).height, greaterThan(originalGlyph.height));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Rect _readerGlyph(WidgetTester tester) {
  final paragraph = find
      .descendant(
        of: find.byType(EpubNativeView),
        matching: find.byType(RichText),
      )
      .evaluate()
      .map((element) => element.renderObject!)
      .whereType<RenderParagraph>()
      .firstWhere(
        (paragraph) =>
            paragraph.text.toPlainText().contains('Independent reader'),
      );
  final start = paragraph.text.toPlainText().indexOf('Independent reader');
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 1),
      )
      .first
      .toRect();
}
