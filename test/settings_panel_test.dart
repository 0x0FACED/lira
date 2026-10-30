import 'dart:convert';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/features/settings/data/reader_theme_catalog.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/features/settings/presentation/settings_panel.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _openSettings(
  WidgetTester tester, {
  required ReaderSettings settings,
  Locale locale = const Locale('en'),
  Size size = const Size(1200, 1000),
  Size? panelSize,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    'reader_settings': jsonEncode(settings.toJson()),
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
        locale: locale,
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: panelSize?.width,
              height: panelSize?.height,
              child: const SettingsPanel(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SettingsPanel)));
}

Finder _sliderFinder(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  ),
  matching: find.byType(Slider),
);

Slider _slider(WidgetTester tester, String label) =>
    tester.widget<Slider>(_sliderFinder(label));

DropdownButton<String> _fontSelector(WidgetTester tester) =>
    tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));

Future<void> _selectCategory(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('external reset updates every category without reopening', (
    tester,
  ) async {
    final container = await _openSettings(
      tester,
      locale: const Locale('ru'),
      settings: const ReaderSettings(
        fontSize: 28,
        fontWeight: 700,
        lineHeight: 2.2,
        horizontalPadding: 200,
        paragraphIndent: 2,
        paragraphSpacing: 1.5,
        brightness: 0.7,
        textContrast: 0.8,
      ),
    );
    expect(_slider(tester, 'Размер шрифта').value, 28);
    expect(_slider(tester, 'Насыщенность шрифта').value, 700);
    expect(_slider(tester, 'Межстрочный интервал').value, 2.2);
    await _selectCategory(tester, 'Макет');
    expect(_slider(tester, 'Отступы страницы').value, 200);
    expect(_slider(tester, 'Красная строка').value, 2);
    expect(_slider(tester, 'Интервал между абзацами').value, 1.5);
    await _selectCategory(tester, 'Цвета');
    expect(
      _slider(tester, 'Дополнительное затемнение').value,
      closeTo(0.3, 0.001),
    );
    expect(_slider(tester, 'Контраст текста').value, 0.8);

    container.read(readerSettingsProvider.notifier).resetSettings();
    await tester.pumpAndSettle();
    final defaults = container.read(readerSettingsProvider);
    expect(
      _slider(tester, 'Дополнительное затемнение').value,
      closeTo(1 - defaults.brightness, 0.001),
    );
    expect(_slider(tester, 'Контраст текста').value, defaults.textContrast);
    await _selectCategory(tester, 'Макет');
    expect(
      _slider(tester, 'Отступы страницы').value,
      defaults.horizontalPadding,
    );
    expect(_slider(tester, 'Красная строка').value, defaults.paragraphIndent);
    expect(
      _slider(tester, 'Интервал между абзацами').value,
      defaults.paragraphSpacing,
    );
    await _selectCategory(tester, 'Шрифт');
    expect(_slider(tester, 'Размер шрифта').value, defaults.fontSize);
    expect(_slider(tester, 'Насыщенность шрифта').value, defaults.fontWeight);
    expect(_slider(tester, 'Межстрочный интервал').value, defaults.lineHeight);
  });

  testWidgets(
    'phone range clamps display without rewriting saved wide margins',
    (tester) async {
      final container = await _openSettings(
        tester,
        settings: const ReaderSettings(horizontalPadding: 200),
        size: const Size(390, 844),
      );
      await _selectCategory(tester, 'Layout');
      expect(_slider(tester, 'Page margins').max, 64);
      expect(_slider(tester, 'Page margins').value, 64);
      expect(container.read(readerSettingsProvider).horizontalPadding, 200);

      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpAndSettle();
      expect(_slider(tester, 'Page margins').max, 240);
      expect(_slider(tester, 'Page margins').value, 200);
      expect(container.read(readerSettingsProvider).horizontalPadding, 200);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(_slider(tester, 'Page margins').value, 64);
      _slider(tester, 'Page margins').onChanged!(48);
      await tester.pumpAndSettle();
      expect(_slider(tester, 'Page margins').value, 48);
      expect(container.read(readerSettingsProvider).horizontalPadding, 48);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a saved system font remains selectable on Android until replaced',
    (tester) async {
      final container = await _openSettings(
        tester,
        settings: const ReaderSettings(fontFamily: 'Georgia'),
        size: const Size(390, 844),
      );
      expect(_fontSelector(tester).value, 'Georgia');
      expect(
        _fontSelector(tester).items!.any((item) => item.value == 'Georgia'),
        isTrue,
      );
      _fontSelector(tester).onChanged!('Lora');
      await tester.pumpAndSettle();
      expect(container.read(readerSettingsProvider).fontFamily, 'Lora');
      expect(_fontSelector(tester).value, 'Lora');
      expect(
        _fontSelector(tester).items!.any((item) => item.value == 'Georgia'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('font size updates while the slider is still being dragged', (
    tester,
  ) async {
    final container = await _openSettings(
      tester,
      settings: const ReaderSettings(fontSize: 22),
      size: const Size(390, 844),
      panelSize: const Size(390, 420),
    );
    final slider = _sliderFinder('Font size');
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    final changedSize = container.read(readerSettingsProvider).fontSize;
    expect(changedSize, greaterThan(22));
    expect(_slider(tester, 'Font size').value, changedSize);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('each palette sets all colors without changing extra dimming', (
    tester,
  ) async {
    final container = await _openSettings(
      tester,
      settings: const ReaderSettings(
        brightness: 0.6,
        textContrast: 0.4,
        fontSize: 26,
      ),
      panelSize: const Size(360, 520),
    );
    await _selectCategory(tester, 'Colors');
    const labels = ['Day', 'Paper', 'Readable dark', 'Warm evening'];
    for (var index = 0; index < readerThemePalettes.length; index++) {
      final palette = readerThemePalettes[index];
      await tester.tap(find.widgetWithText(OutlinedButton, labels[index]));
      await tester.pumpAndSettle();
      final settings = container.read(readerSettingsProvider);
      expect(settings.backgroundColor, palette.backgroundColor);
      expect(settings.textColor, palette.textColor);
      expect(settings.linkColor, palette.linkColor);
      expect(settings.selectionColor, palette.selectionColor);
      expect(settings.textContrast, 1);
      expect(settings.brightness, 0.6);
      expect(settings.fontSize, 26);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom text and background colors can be edited independently', (
    tester,
  ) async {
    final container = await _openSettings(
      tester,
      settings: const ReaderSettings(
        backgroundColor: 0xFFEAEAEA,
        textColor: 0xFF202020,
        brightness: 0.7,
      ),
      size: const Size(390, 844),
      panelSize: const Size(390, 420),
    );
    await _selectCategory(tester, 'Colors');
    final backgroundEditor = find.byTooltip('Edit color: Page background');
    await tester.ensureVisible(backgroundEditor);
    await tester.tap(backgroundEditor);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '#F3E7D8');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(readerSettingsProvider).backgroundColor, 0xFFF3E7D8);
    expect(container.read(readerSettingsProvider).textColor, 0xFF202020);

    final textEditor = find.byTooltip('Edit color: Text color');
    await tester.ensureVisible(textEditor);
    await tester.tap(textEditor);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '392A20');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final settings = container.read(readerSettingsProvider);
    expect(settings.textColor, 0xFF392A20);
    expect(settings.backgroundColor, 0xFFF3E7D8);
    expect(settings.brightness, 0.7);
    expect(tester.takeException(), isNull);
  });
}
