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
    if (config.enabled) {
      client.connectionFactory = (uri, _, __) {
        final connection = _SocksConnection(config, uri, context);
        return Future.value(
          ConnectionTask.fromSocket(connection.open(), connection.cancel),
        );
      };
    }

    return client;
  }
}

/// Creates a one-off HttpClient with current SOCKS5 settings applied.
/// Use this when you need a fresh HttpClient (e.g. for Dio downloads).
HttpClient createProxiedHttpClient({Socks5Config? config}) {
  return ProxyHttpOverrides(config: config).createHttpClient(null);
}

/// Accepts bare or bracketed IPv6 alongside numeric IPv4 and DNS names.
String socks5ProxyHost(String host) =>
    host.startsWith('[') && host.endsWith(']')
    ? host.substring(1, host.length - 1)
    : host;

class _SocksConnection {
  _SocksConnection(this.config, this.uri, this.context);

  final Socks5Config config;
  final Uri uri;
  final SecurityContext? context;
  ConnectionTask<Socket>? _tcpTask;
  Socket? _socket;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _tcpTask?.cancel();
    _socket?.destroy();
  }

  void _checkCancelled() {
    if (_cancelled) throw const SocketException('Connection cancelled');
  }

  Future<Socket> open() async {
    try {
      _checkCancelled();
      final host = socks5ProxyHost(config.host);
      if (host.isEmpty || config.port < 1 || config.port > 65535) {
        throw ArgumentError('A proxy host and port 1–65535 are required');
      }
      // Let the native connector resolve hostnames lazily and try IPv4/IPv6.
      _tcpTask = await Socket.startConnect(host, config.port);
      if (_cancelled) _tcpTask!.cancel();
      final socket = await _tcpTask!.socket;
      _socket = socket;
      if (_cancelled) socket.destroy();
      _checkCancelled();

      // The package owns negotiation, but not TCP establishment. Supplying
      // our already-connected socket keeps stalled SOCKS negotiation
      // cancellable; the package's normal connect API hides it until done.
      final tunnel = await IOOverrides.runZoned(
        () => socks.SocksTCPClient.connect(
          [socks.ProxySettings(socket.remoteAddress, config.port)],
          InternetAddress(uri.host, type: InternetAddressType.unix),
          uri.port,
        ),
        socketConnect:
            (host, port, {sourceAddress, sourcePort = 0, timeout}) async =>
                socket,
      );
      _checkCancelled();
      // Keep native certificate/hostname verification and the caller's
      // SecurityContext. Never accept bad certificates or retry directly.
      final Socket connectedSocket = uri.scheme == 'https'
          ? await tunnel.secure(uri.host, context: context)
          : tunnel;
      _socket = connectedSocket;
      if (_cancelled) connectedSocket.destroy();
      _checkCancelled();
      return connectedSocket;
    } catch (_) {
      cancel();
      rethrow;
    }
  }
}
