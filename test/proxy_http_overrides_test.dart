import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
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
}
