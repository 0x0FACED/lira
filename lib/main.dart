import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'core/providers/preferences_provider.dart';
import 'core/network/proxy_http_overrides.dart';
import 'core/widgets/app_text_scaling.dart';
import 'features/settings/data/reader_font_catalog.dart';
import 'features/settings/data/settings_provider.dart' show sharedPrefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load SharedPreferences before runApp so all providers
  // can read persisted state synchronously (no async race conditions).
  sharedPrefs = await SharedPreferences.getInstance();
  final proxyStore = Socks5PreferencesStore(sharedPrefs);
  final proxyConfig = await proxyStore.load();
  updateGlobalProxyConfig(proxyConfig);
  HttpOverrides.global = ProxyHttpOverrides();

  for (final font in bundledReaderFonts) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        font.family,
      ], await rootBundle.loadString(font.licenseAsset));
    });
  }
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'epub_engine hyphenation',
    ], await rootBundle.loadString('packages/epub_engine/LICENSE.hyphenation'));
  });

  configureDependencies();
  runApp(
    ProviderScope(
      overrides: [
        socks5PreferencesStoreProvider.overrideWith((ref) async => proxyStore),
        initialSocks5ConfigProvider.overrideWithValue(proxyConfig),
      ],
      child: const LiraApp(),
    ),
  );
}

class LiraApp extends ConsumerWidget {
  const LiraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Update synchronously on provider changes, not on the next widget frame.
    ref.listen<Socks5Config>(socks5ConfigProvider, (_, config) {
      updateGlobalProxyConfig(config);
    });
    updateGlobalProxyConfig(ref.read(socks5ConfigProvider));
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Lira',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: AppMotion.duration(context),
      themeAnimationCurve: AppMotion.curve,
      locale: locale,
      routerConfig: router,
      builder: (context, child) => AppTextScaling(
        child: TooltipVisibility(visible: false, child: child!),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
