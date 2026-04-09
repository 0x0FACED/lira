import 'dart:io';

import 'package:socks5_proxy/socks_client.dart' as socks;

import '../providers/preferences_provider.dart';

/// Global proxy state — updated from the UI when user toggles SOCKS5.
/// This is intentionally global (not Riverpod) because HttpOverrides
/// and ad-hoc Dio instances need access without a Ref.
Socks5Config _currentConfig = const Socks5Config();

Socks5Config get currentProxyConfig => _currentConfig;

void updateGlobalProxyConfig(Socks5Config config) {
  _currentConfig = config;
}

/// HttpOverrides that routes all traffic through SOCKS5 when enabled.
class ProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Accept self-signed certs (existing behaviour)
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    if (_currentConfig.enabled && _currentConfig.host.isNotEmpty) {
      socks.SocksTCPClient.assignToHttpClientWithSecureOptions(
        client,
        [
          socks.ProxySettings(
            InternetAddress(_currentConfig.host),
            _currentConfig.port,
          ),
        ],
      );
    }

    return client;
  }
}

/// Creates a one-off HttpClient with current SOCKS5 settings applied.
/// Use this when you need a fresh HttpClient (e.g. for Dio downloads).
HttpClient createProxiedHttpClient() {
  return ProxyHttpOverrides().createHttpClient(null);
}
