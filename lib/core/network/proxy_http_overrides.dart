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
  ProxyHttpOverrides({Socks5Config? config}) : _config = config;

  final Socks5Config? _config;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // The app's explicit configuration is the only application-level proxy.
    // An ambient HTTP proxy would add CONNECT inside the SOCKS connection.
    client.findProxy = (_) => 'DIRECT';
    final config = _config ?? _currentConfig;
    if (config.enabled && config.host.isNotEmpty) {
      socks.SocksTCPClient.assignToHttpClientWithSecureOptions(client, [
        socks.ProxySettings(InternetAddress(config.host), config.port),
      ]);
    }

    return client;
  }
}

/// Creates a one-off HttpClient with current SOCKS5 settings applied.
/// Use this when you need a fresh HttpClient (e.g. for Dio downloads).
HttpClient createProxiedHttpClient({Socks5Config? config}) {
  return ProxyHttpOverrides(config: config).createHttpClient(null);
}
