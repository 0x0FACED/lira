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
import 'features/settings/data/reader_font_catalog.dart';
import 'features/settings/data/settings_provider.dart' show sharedPrefs;

void main() async {
  HttpOverrides.global = ProxyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Load SharedPreferences before runApp so all providers
  // can read persisted state synchronously (no async race conditions).
  sharedPrefs = await SharedPreferences.getInstance();

  for (final font in bundledReaderFonts) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        font.family,
      ], await rootBundle.loadString(font.licenseAsset));
    });
  }

  configureDependencies();
  runApp(const ProviderScope(child: LiraApp()));
}

class LiraApp extends ConsumerWidget {
  const LiraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // Keep global proxy config in sync with provider state
    final proxyConfig = ref.watch(socks5ConfigProvider);
    updateGlobalProxyConfig(proxyConfig);

    return MaterialApp.router(
      title: 'Lira',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: AppMotion.duration(context),
      themeAnimationCurve: AppMotion.curve,
      locale: locale,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
