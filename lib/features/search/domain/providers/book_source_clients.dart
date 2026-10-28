import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/io_client.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

import '../../../../core/network/proxy_http_overrides.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../data/anna_archive_client.dart';
import 'anna_access_provider.dart';
import 'zlibrary_mirrors_provider.dart';

final annaArchiveClientProvider = Provider<AnnaArchiveClient>((ref) {
  final proxy = ref.watch(socks5ConfigProvider);
  final session = ref.watch(annaAccessSessionProvider);
  final dio = Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => createProxiedHttpClient(config: proxy),
    );
  final client = AnnaArchiveClient(
    dio: dio,
    cookies: session?.cookies,
    userAgent: session?.userAgent,
    sessionOrigin: session?.origin,
  );
  ref.onDispose(client.close);
  return client;
});

final zLibraryApiProvider = Provider<ZLibraryApi>((ref) {
  final proxy = ref.watch(socks5ConfigProvider);
  final mirrors = ref.watch(zLibraryMirrorsProvider);
  final credentials = ref.watch(zLibraryCredentialsProvider);
  final client = ZLibraryApi(
    mirrors: mirrors,
    cookies: credentials?.cookies,
    client: IOClient(createProxiedHttpClient(config: proxy)),
  );
  ref.onDispose(client.close);
  return client;
});

final zLibraryMirrorDirectoryProvider = Provider<ZLibraryMirrorDirectory>((
  ref,
) {
  final proxy = ref.watch(socks5ConfigProvider);
  final directory = ZLibraryMirrorDirectory(
    client: IOClient(createProxiedHttpClient(config: proxy)),
  );
  ref.onDispose(directory.close);
  return directory;
});
