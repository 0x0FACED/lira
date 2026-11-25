import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:lira/core/network/proxy_connection_check.dart';
import 'package:lira/core/network/proxy_http_overrides.dart';
import 'package:lira/core/providers/preferences_provider.dart';

void main() {
  test(
    'explicit direct mode does not leak requests through an ambient HTTP proxy',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ambientProxy = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        await origin.close(force: true);
        await ambientProxy.close(force: true);
      });
      var proxyRequests = 0;
      final servedPaths = <String>[];
      origin.listen((request) async {
        servedPaths.add(request.uri.path);
        request.response.write('origin response');
        await request.response.close();
      });
      ambientProxy.listen((request) async {
        proxyRequests++;
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      });

      await HttpOverrides.runZoned(
        () async {
          final client = IOClient(
            createProxiedHttpClient(config: const Socks5Config(enabled: false)),
          );
          addTearDown(client.close);
          final response = await client.get(
            Uri.parse('http://127.0.0.1:${origin.port}/catalog'),
          );
          expect(response.statusCode, HttpStatus.ok);
          expect(servedPaths, ['/catalog']);
          expect(proxyRequests, 0);
        },
        findProxyFromEnvironment: (_, __) =>
            'PROXY 127.0.0.1:${ambientProxy.port}',
      );
    },
  );

  test(
    'proxy hostnames resolve lazily and target DNS stays with SOCKS',
    () async {
      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await proxy.close();
      });
      final client = IOClient(
        createProxiedHttpClient(
          config: Socks5Config(
            enabled: true,
            host: 'localhost',
            port: proxy.port,
          ),
        ),
      );
      addTearDown(client.close);
      final serving = proxy.first.then((socket) async {
        sockets.add(socket);
        final reader = _SocketReader(socket);
        final destination = await _acceptSocksTunnel(socket, reader);
        expect(destination, 'catalog.invalid');
        await reader.readHttpHeaders();
        socket.write(
          'HTTP/1.1 200 OK\r\nContent-Length: 7\r\nConnection: close\r\n\r\nbookish',
        );
        await socket.flush();
      });

      final response = await client.get(
        Uri.parse('http://catalog.invalid/catalog'),
      );
      expect(response.body, 'bookish');
      await serving;
    },
  );

  test('an unavailable proxy never falls back to the origin', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final unavailable = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unavailable.port;
    await unavailable.close();
    var originRequests = 0;
    origin.listen((request) async {
      originRequests++;
      await request.response.close();
    });
    addTearDown(() => origin.close(force: true));
    final client = IOClient(
      createProxiedHttpClient(
        config: Socks5Config(enabled: true, host: 'localhost', port: port),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      client.get(Uri.parse('http://127.0.0.1:${origin.port}/catalog')),
      throwsA(isA<Exception>()),
    );
    expect(originRequests, 0);
    expect(
      await checkProxyConnection(
        Socks5Config(enabled: false, host: 'localhost', port: port),
        target: Uri.parse('https://catalog.invalid/'),
      ),
      ProxyConnectionResult.proxyUnavailable,
    );
  });

  for (final stallInTls in [false, true]) {
    test(
      'draft check closes a stalled ${stallInTls ? 'TLS' : 'SOCKS'} socket',
      () async {
        final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        Socket? accepted;
        addTearDown(() async {
          accepted?.destroy();
          await proxy.close();
        });
        final negotiationStarted = Completer<void>();
        final socketClosed = proxy.first.then((socket) async {
          accepted = socket;
          final reader = _SocketReader(socket);
          if (stallInTls) {
            await _acceptSocksTunnel(socket, reader);
            expect((await reader.read(1)).single, 0x16);
          } else {
            expect((await reader.read(1)).single, 0x05);
          }
          negotiationStarted.complete();
          await reader.drain();
        });
        final checking = checkProxyConnection(
          Socks5Config(enabled: false, host: 'localhost', port: proxy.port),
          target: Uri.parse('https://catalog.invalid/'),
          timeout: const Duration(seconds: 2),
        );
        await negotiationStarted.future.timeout(const Duration(seconds: 5));
        expect(await checking, ProxyConnectionResult.timedOut);
        // The deadline must close the peer, not merely stop awaiting a Future.
        await socketClosed.timeout(const Duration(seconds: 2));
      },
    );
  }
}

/// Minimal local-only SOCKS fixture; production negotiation uses socks5_proxy.
Future<String> _acceptSocksTunnel(Socket socket, _SocketReader reader) async {
  final greeting = await reader.read(2);
  expect(greeting.first, 5);
  await reader.read(greeting[1]);
  socket.add([5, 0]);
  await socket.flush();
  final command = await reader.read(4);
  expect(command.sublist(0, 3), [5, 1, 0]);
  final String destination;
  switch (command[3]) {
    case 1:
      destination = InternetAddress.fromRawAddress(
        Uint8List.fromList(await reader.read(4)),
      ).address;
      break;
    case 3:
      final length = (await reader.read(1)).single;
      destination = utf8.decode(await reader.read(length));
      break;
    case 4:
      destination = InternetAddress.fromRawAddress(
        Uint8List.fromList(await reader.read(16)),
      ).address;
      break;
    default:
      throw StateError('Unexpected address type ${command[3]}');
  }
  await reader.read(2);
  socket.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
  await socket.flush();
  return destination;
}

class _SocketReader {
  _SocketReader(Socket socket) : _chunks = StreamIterator(socket);

  final StreamIterator<Uint8List> _chunks;
  List<int> _chunk = const [];
  var _offset = 0;

  Future<List<int>> read(int count) async {
    final bytes = <int>[];
    while (bytes.length < count) {
      if (_offset == _chunk.length) {
        if (!await _chunks.moveNext()) {
          throw StateError('Peer closed during SOCKS negotiation');
        }
        _chunk = _chunks.current;
        _offset = 0;
      }
      final remaining = count - bytes.length;
      final available = _chunk.length - _offset;
      final take = remaining < available ? remaining : available;
      bytes.addAll(_chunk.getRange(_offset, _offset + take));
      _offset += take;
    }
    return bytes;
  }

  Future<void> readHttpHeaders() async {
    var tail = 0;
    while (tail != 0x0d0a0d0a) {
      tail = ((tail << 8) | (await read(1)).single) & 0xffffffff;
    }
  }

  Future<void> drain() async {
    while (await _chunks.moveNext()) {}
  }
}
