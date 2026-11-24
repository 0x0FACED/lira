import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/io_client.dart';

import '../../../../core/network/proxy_http_overrides.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../data/open_library_client.dart';

final openLibraryClientProvider = Provider<OpenLibraryClient>((ref) {
  final proxy = ref.watch(socks5ConfigProvider);
  final httpClient = createProxiedHttpClient(config: proxy)
    ..connectionTimeout = const Duration(seconds: 12);
  final client = OpenLibraryClient(client: IOClient(httpClient));
  ref.onDispose(client.close);
  return client;
});
