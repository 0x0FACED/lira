import 'dart:io';
import 'dart:typed_data';

import '../providers/preferences_provider.dart';
import 'socks5_handshake.dart';
import 'socks5_socket.dart';

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
      client.connectionFactory = (uri, _, __) async {
        // Reject invalid configuration before returning a task whose socket
        // future could fail before HttpClient has subscribed to it.
        final authentication = socks5AuthenticationRequest(config);
        final host = socks5ProxyHost(config.host);
        if (host.isEmpty || config.port < 1 || config.port > 65535) {
          throw ArgumentError('A proxy host and port 1–65535 are required');
        }
        final connection = _SocksConnection(config.port, uri, context);
        return ConnectionTask.fromSocket(
          connection.open(host, authentication),
          connection.cancel,
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

class _SocksConnection {
  _SocksConnection(this.port, this.uri, this.context);

  final int port;
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

  Future<Socket> open(String host, Uint8List? authentication) async {
    try {
      // Let the native connector resolve hostnames lazily and try IPv4/IPv6.
      _tcpTask = await Socket.startConnect(host, port);
      if (_cancelled) _tcpTask!.cancel();
      final socket = await _tcpTask!.socket;
      _socket = socket;
      if (_cancelled) socket.destroy();
      _checkCancelled();

      final reader = Socks5SocketReader(socket);
      await openSocks5Tunnel(
        uri,
        authenticationRequest: authentication,
        read: reader.readExactly,
        write: (bytes) async {
          socket.add(bytes);
          await socket.flush();
        },
      );
      _checkCancelled();
      // Keep native certificate/hostname verification and the caller's
      // SecurityContext. Never accept bad certificates or retry directly.
      final Socket connectedSocket = uri.scheme == 'https'
          ? await SecureSocket.secure(socket, host: uri.host, context: context)
          : reader.tunnel(socket);
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
