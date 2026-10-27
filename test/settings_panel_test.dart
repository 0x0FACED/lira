import 'dart:convert';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/features/settings/presentation/settings_panel.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _openSettings(
  WidgetTester tester, {
  required ReaderSettings settings,
  Locale locale = const Locale('en'),
  Size size = const Size(1200, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    'reader_settings': jsonEncode(settings.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      readerSettingsProvider.overrideWith(
        (ref) => ReaderSettingsNotifier(prefs),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SettingsPanel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Slider _slider(WidgetTester tester, String label) => tester.widget<Slider>(
  find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    ),
    matching: find.byType(Slider),
  ),
);

DropdownButton<String> _fontSelector(WidgetTester tester) =>
    tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));

void main() {
  testWidgets('external reset synchronizes all sliders without reopening', (
    tester,
  ) async {
    final container = await _openSettings(
      tester,
      locale: const Locale('ru'),
      settings: const ReaderSettings(
        fontSize: 28,
        lineHeight: 2.2,
        horizontalPadding: 200,
        brightness: 0.7,
      ),
    );
    expect(_slider(tester, 'Размер шрифта').value, 28);
    expect(_slider(tester, 'Межстрочный интервал').value, 2.2);
    expect(_slider(tester, 'Отступы страницы').value, 200);
    expect(_slider(tester, 'Отступы страницы').max, 240);
    expect(_slider(tester, 'Яркость').value, 0.7);

    container.read(readerSettingsProvider.notifier).resetSettings();
    await tester.pumpAndSettle();
    final defaults = container.read(readerSettingsProvider);
    expect(_slider(tester, 'Размер шрифта').value, defaults.fontSize);
    expect(_slider(tester, 'Межстрочный интервал').value, defaults.lineHeight);
    expect(
      _slider(tester, 'Отступы страницы').value,
      defaults.horizontalPadding,
    );
    expect(_slider(tester, 'Яркость').value, defaults.brightness);
  });

  testWidgets(
    'phone range clamps display without rewriting saved wide margins',
    (tester) async {
      final container = await _openSettings(
        tester,
        settings: const ReaderSettings(horizontalPadding: 200),
        size: const Size(390, 844),
      );
      expect(_slider(tester, 'Page margins').max, 64);
      expect(_slider(tester, 'Page margins').value, 64);
      expect(container.read(readerSettingsProvider).horizontalPadding, 200);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpAndSettle();
      expect(_slider(tester, 'Page margins').max, 240);
      expect(_slider(tester, 'Page margins').value, 200);
      expect(container.read(readerSettingsProvider).horizontalPadding, 200);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(_slider(tester, 'Page margins').value, 64);
      _slider(tester, 'Page margins').onChanged!(48);
      await tester.pump();
      expect(_slider(tester, 'Page margins').value, 48);
      expect(container.read(readerSettingsProvider).horizontalPadding, 200);
      _slider(tester, 'Page margins').onChangeEnd!(48);
      await tester.pumpAndSettle();
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
}
