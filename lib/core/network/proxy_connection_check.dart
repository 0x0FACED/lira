import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../providers/preferences_provider.dart';
import 'proxy_http_overrides.dart' show socks5ProxyHost;

enum ProxyConnectionResult {
  connected,
  timedOut,
  proxyUnavailable,
  serviceUnavailable,
}

/// Checks a draft without changing application routing. The default target is
/// Open Library and a successful HEAD response does not vouch for other hosts.
Future<ProxyConnectionResult> checkProxyConnection(
  Socks5Config config, {
  Uri? target,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final uri = target ?? Uri.https('openlibrary.org', '/');
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw ArgumentError.value(
      target,
      'target',
      'Credential-free HTTPS required',
    );
  }
  if (timeout <= Duration.zero) return ProxyConnectionResult.timedOut;

  ConnectionTask<RawSocket>? connecting;
  RawSocket? socket;
  var expired = false;
  var tunnelEstablished = false;

  Future<ProxyConnectionResult> request() async {
    try {
      // Retain the raw socket across TLS negotiation: SecureSocket.secure on a
      // Socket detaches it, leaving no way to close it during handshake.
      final task = connecting = await RawSocket.startConnect(
        socks5ProxyHost(config.host),
        config.port,
      );
      if (expired) task.cancel();
      final raw = socket = await task.socket;
      if (expired) {
        unawaited(raw.close());
        return ProxyConnectionResult.timedOut;
      }
      final proxy = _ProbeSocket(raw);
      await _openTunnel(proxy, uri);
      tunnelEstablished = true;
      final secure = await RawSecureSocket.secure(
        raw,
        subscription: proxy.subscription,
        host: uri.host,
      );
      final tls = _ProbeSocket(secure);
      final path = uri.path.isEmpty ? '/' : uri.path;
      final query = uri.hasQuery ? '?${uri.query}' : '';
      await tls.write(
        ascii.encode(
          'HEAD $path$query HTTP/1.1\r\nHost: ${uri.authority}\r\n'
          'Connection: close\r\n\r\n',
        ),
      );
      final status = await _readHttpStatus(tls);
      return status >= 200 && status < 400
          ? ProxyConnectionResult.connected
          : ProxyConnectionResult.serviceUnavailable;
    } catch (_) {
      return tunnelEstablished
          ? ProxyConnectionResult.serviceUnavailable
          : ProxyConnectionResult.proxyUnavailable;
    }
  }

  try {
    return await request().timeout(
      timeout,
      onTimeout: () {
        expired = true;
        return ProxyConnectionResult.timedOut;
      },
    );
  } finally {
    if (expired) connecting?.cancel();
    final raw = socket;
    if (raw != null) unawaited(raw.close());
  }
}

// This probe owns its RawSocket, so it negotiates the same unauthenticated
// SOCKS5 CONNECT without the package adapter that requires a Socket.
Future<void> _openTunnel(_ProbeSocket proxy, Uri target) async {
  await proxy.write(const [5, 1, 0]);
  final method = await proxy.readExactly(2);
  if (method[0] != 5 || method[1] != 0) {
    throw const SocketException('Proxy did not accept unauthenticated SOCKS5');
  }

  final ip = InternetAddress.tryParse(target.host);
  final address = ip?.rawAddress ?? utf8.encode(target.host);
  if (address.length > 255)
    throw const FormatException('SOCKS5 target too long');
  final type = ip == null ? 3 : (ip.type == InternetAddressType.IPv4 ? 1 : 4);
  await proxy.write([
    5,
    1,
    0,
    type,
    if (type == 3) address.length,
    ...address,
    target.port >> 8,
    target.port & 0xff,
  ]);
  final reply = await proxy.readExactly(4);
  if (reply[0] != 5 || reply[1] != 0 || reply[2] != 0) {
    throw const SocketException('Proxy did not open the SOCKS5 tunnel');
  }
  final addressLength = switch (reply[3]) {
    1 => 4,
    3 => (await proxy.readExactly(1)).single,
    4 => 16,
    _ => throw const FormatException('Invalid SOCKS5 reply address'),
  };
  await proxy.readExactly(addressLength + 2);
}

final _statusLine = RegExp(r'^HTTP/1\.[01] ([0-9]{3})(?: |\r?$)');

Future<int> _readHttpStatus(_ProbeSocket tls) async {
  final bytes = BytesBuilder(copy: false);
  // Read only the status line. Ignore response headers and do not follow
  // redirects or send application credentials.
  while (bytes.length < 1024) {
    final chunk = await tls.read(1024 - bytes.length);
    final end = chunk.indexOf(0x0a);
    if (end < 0) {
      bytes.add(chunk);
      continue;
    }
    bytes.add(Uint8List.sublistView(chunk, 0, end));
    final line = ascii.decode(bytes.takeBytes(), allowInvalid: true);
    final match = _statusLine.firstMatch(line);
    if (match != null) return int.parse(match[1]!);
    break;
  }
  throw const FormatException('Invalid HTTP status line');
}

/// Single-operation raw socket I/O. The active subscription can be handed to
/// RawSecureSocket without releasing the underlying, cancellable TCP socket.
class _ProbeSocket {
  _ProbeSocket(this._socket) {
    _socket.readEventsEnabled = false;
    _socket.writeEventsEnabled = false;
    subscription = _socket.listen(
      _handleEvent,
      onError: _close,
      onDone: _close,
    );
  }

  final RawSocket _socket;
  late final StreamSubscription<RawSocketEvent> subscription;
  Completer<void>? _ready;
  bool _closed = false;

  void _handleEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.closed || event == RawSocketEvent.readClosed) {
      _close();
    } else {
      _socket.readEventsEnabled = false;
      _socket.writeEventsEnabled = false;
      _ready?.complete();
      _ready = null;
    }
  }

  void _close([Object? error]) {
    _closed = true;
    _ready?.completeError(error ?? const SocketException('Peer closed'));
    _ready = null;
  }

  Future<void> _wait({required bool read}) {
    if (_closed) throw const SocketException('Peer closed');
    final ready = _ready = Completer<void>();
    if (read) {
      _socket.readEventsEnabled = true;
    } else {
      _socket.writeEventsEnabled = true;
    }
    return ready.future;
  }

  Future<Uint8List> read(int bytes) async {
    while (true) {
      final data = _socket.read(bytes);
      if (data != null && data.isNotEmpty) return data;
      await _wait(read: true);
    }
  }

  Future<Uint8List> readExactly(int bytes) async {
    final buffer = Uint8List(bytes);
    var offset = 0;
    while (offset < bytes) {
      final data = await read(bytes - offset);
      buffer.setRange(offset, offset + data.length, data);
      offset += data.length;
    }
    return buffer;
  }

  Future<void> write(List<int> bytes) async {
    var offset = 0;
    while (offset < bytes.length) {
      offset += _socket.write(bytes, offset);
      if (offset < bytes.length) await _wait(read: false);
    }
  }
}
