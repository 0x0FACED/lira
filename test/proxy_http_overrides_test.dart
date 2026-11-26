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

  for (final authenticated in [false, true]) {
    for (final tls in [false, true]) {
      test('strict SOCKS ${authenticated ? 'auth' : 'no-auth'} '
          '${tls ? 'reaches TLS' : 'carries HTTP'}', () async {
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
              username: authenticated ? 'читатель' : null,
              password: authenticated ? ' secret ' : null,
            ),
          ),
        );
        addTearDown(client.close);
        final serving = proxy.first.then((socket) async {
          sockets.add(socket);
          final reader = _SocketReader(socket);
          expect(
            await _acceptSocksTunnel(
              socket,
              reader,
              username: authenticated ? 'читатель' : null,
              password: authenticated ? ' secret ' : null,
            ),
            'catalog.invalid',
          );
          if (tls) {
            // A TLS ClientHello proves native TLS starts only after auth and
            // CONNECT. Closing the fixture must not trigger a direct retry.
            expect((await reader.read(1)).single, 0x16);
            socket.destroy();
            return;
          }
          await reader.readHttpHeaders();
          socket.write(
            'HTTP/1.1 200 OK\r\nContent-Length: 7\r\nConnection: close\r\n\r\nbookish',
          );
          await socket.flush();
        });
        final response = client
            .get(
              Uri.parse(
                tls ? 'https://catalog.invalid/' : 'http://catalog.invalid/',
              ),
            )
            .timeout(const Duration(seconds: 5));
        if (tls) {
          await expectLater(response, throwsA(isA<Exception>()));
        } else {
          expect((await response).body, 'bookish');
        }
        await serving;
      });
    }

    test(
      'draft ${authenticated ? 'auth' : 'no-auth'} probe reaches TLS',
      () async {
        final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <Socket>[];
        addTearDown(() async {
          for (final socket in sockets) {
            socket.destroy();
          }
          await proxy.close();
        });
        final serving = proxy.first.then((socket) async {
          sockets.add(socket);
          final reader = _SocketReader(socket);
          expect(
            await _acceptSocksTunnel(
              socket,
              reader,
              username: authenticated ? 'читатель' : null,
              password: authenticated ? ' secret ' : null,
            ),
            'catalog.invalid',
          );
          expect((await reader.read(1)).single, 0x16);
          socket.destroy();
        });
        expect(
          await checkProxyConnection(
            Socks5Config(
              host: 'localhost',
              port: proxy.port,
              username: authenticated ? 'читатель' : null,
              password: authenticated ? ' secret ' : null,
            ),
            target: Uri.https('catalog.invalid', '/'),
            timeout: const Duration(seconds: 5),
          ),
          ProxyConnectionResult.serviceUnavailable,
        );
        await serving;
      },
    );
  }

  test('draft deadline closes a stalled RFC1929 exchange', () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    Socket? accepted;
    addTearDown(() async {
      accepted?.destroy();
      await proxy.close();
    });
    final authenticating = Completer<void>();
    final closed = proxy.first.then((socket) async {
      accepted = socket;
      final reader = _SocketReader(socket);
      expect(await reader.read(3), [5, 1, 2]);
      socket.add([5, 2]);
      await socket.flush();
      await _readCredentials(reader, 'reader', 'secret');
      authenticating.complete();
      expect(await reader.drain(), 0);
    });
    final checking = checkProxyConnection(
      Socks5Config(
        host: 'localhost',
        port: proxy.port,
        username: 'reader',
        password: 'secret',
      ),
      target: Uri.https('catalog.invalid', '/'),
      timeout: const Duration(seconds: 2),
    );
    await authenticating.future.timeout(const Duration(seconds: 5));
    expect(await checking, ProxyConnectionResult.timedOut);
    await closed.timeout(const Duration(seconds: 2));
  });

  for (final probe in [false, true]) {
    for (final failure in [
      'rejected',
      'downgrade',
      'unsupported method',
      'no acceptable method',
      'invalid auth version',
      'auth required without credentials',
    ]) {
      test(
        '${probe ? 'probe' : 'transport'} refuses $failure before CONNECT',
        () async {
          final proxy = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          Socket? accepted;
          addTearDown(() async {
            accepted?.destroy();
            await proxy.close();
          });
          final hasCredentials = failure != 'auth required without credentials';
          final config = Socks5Config(
            enabled: true,
            host: 'localhost',
            port: proxy.port,
            username: hasCredentials ? 'reader' : null,
            password: hasCredentials ? 'wrong-password' : null,
          );
          final serving = proxy.first.then((socket) async {
            accepted = socket;
            final reader = _SocketReader(socket);
            expect(await reader.read(3), [5, 1, hasCredentials ? 2 : 0]);
            final method = switch (failure) {
              'downgrade' => 0,
              'unsupported method' => 1,
              'no acceptable method' => 255,
              _ => 2,
            };
            socket.add([5, method]);
            await socket.flush();
            if (failure == 'rejected' || failure == 'invalid auth version') {
              await _readCredentials(reader, 'reader', 'wrong-password');
              socket.add(failure == 'rejected' ? [1, 1] : [2, 0]);
              await socket.flush();
            }
            // No CONNECT, target request, or second authentication attempt.
            expect(await reader.drain(), 0);
          });
          if (probe) {
            expect(
              await checkProxyConnection(
                config,
                target: Uri.https('catalog.invalid', '/'),
                timeout: const Duration(seconds: 5),
              ),
              ProxyConnectionResult.authenticationFailed,
            );
          } else {
            final client = IOClient(createProxiedHttpClient(config: config));
            addTearDown(client.close);
            await expectLater(
              client
                  .get(Uri.http('catalog.invalid', '/'))
                  .timeout(const Duration(seconds: 5)),
              throwsA(isA<Exception>()),
            );
          }
          await serving.timeout(const Duration(seconds: 5));
        },
      );
    }
  }

  test(
    'unavailable or incomplete credentials fail before connecting',
    () async {
      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      var connections = 0;
      proxy.listen((socket) {
        connections++;
        socket.destroy();
      });
      addTearDown(proxy.close);
      for (final config in [
        Socks5Config(
          enabled: true,
          host: 'localhost',
          port: proxy.port,
          credentialsUnavailable: true,
        ),
        Socks5Config(
          enabled: true,
          host: 'localhost',
          port: proxy.port,
          username: 'reader',
        ),
      ]) {
        final client = IOClient(createProxiedHttpClient(config: config));
        addTearDown(client.close);
        await expectLater(
          client.get(Uri.http('catalog.invalid', '/')),
          throwsA(isA<Exception>()),
        );
        expect(
          await checkProxyConnection(config),
          ProxyConnectionResult.authenticationFailed,
        );
      }
      expect(connections, 0);
    },
  );
}

/// Minimal SOCKS fixture. Every connection and TLS peer stays on loopback.
Future<String> _acceptSocksTunnel(
  Socket socket,
  _SocketReader reader, {
  String? username,
  String? password,
}) async {
  expect(await reader.read(3), [5, 1, username == null ? 0 : 2]);
  socket.add([5, username == null ? 0 : 2]);
  await socket.flush();
  if (username != null) {
    await _readCredentials(reader, username, password!);
    socket.add([1, 0]);
  }
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

Future<void> _readCredentials(
  _SocketReader reader,
  String username,
  String password,
) async {
  expect((await reader.read(1)).single, 1);
  final userLength = (await reader.read(1)).single;
  expect(utf8.decode(await reader.read(userLength)), username);
  final passwordLength = (await reader.read(1)).single;
  expect(utf8.decode(await reader.read(passwordLength)), password);
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

  Future<int> drain() async {
    var bytes = _chunk.length - _offset;
    while (await _chunks.moveNext()) {
      bytes += _chunks.current.length;
    }
    return bytes;
  }
}
