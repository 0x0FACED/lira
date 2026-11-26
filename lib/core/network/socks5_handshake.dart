import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../providers/preferences_provider.dart';

/// Accepts bare or bracketed IPv6 alongside numeric IPv4 and DNS names.
String socks5ProxyHost(String host) =>
    host.startsWith('[') && host.endsWith(']')
    ? host.substring(1, host.length - 1)
    : host;

/// A method refusal, authentication downgrade, or rejected RFC1929 exchange.
/// Messages deliberately exclude both credentials and server-supplied text.
class Socks5AuthenticationException implements IOException {
  const Socks5AuthenticationException();

  @override
  String toString() => 'SOCKS5 authentication failed';
}

Uint8List? socks5AuthenticationRequest(Socks5Config config) {
  if (config.credentialsUnavailable) {
    throw const Socks5AuthenticationException();
  }
  final username = config.username;
  final password = config.password;
  if (username == null && password == null) return null;
  if (username == null || password == null) {
    throw const Socks5AuthenticationException();
  }
  final user = utf8.encode(username);
  final secret = utf8.encode(password);
  if (!Socks5Config.validCredentialLength(user.length) ||
      !Socks5Config.validCredentialLength(secret.length)) {
    throw const Socks5AuthenticationException();
  }
  final passwordOffset = 2 + user.length;
  final length = passwordOffset + 1 + secret.length;
  return Uint8List(length)
    ..[0] = 1
    ..[1] = user.length
    ..setRange(2, passwordOffset, user)
    ..[passwordOffset] = secret.length
    ..setRange(passwordOffset + 1, length, secret);
}

/// Shared wire policy for the native Socket transport and RawSocket probe.
/// Exactly one method is offered: credentials can never downgrade to no-auth.
Future<void> openSocks5Tunnel(
  Uri target, {
  required Uint8List? authenticationRequest,
  required Future<List<int>> Function(int) read,
  required Future<void> Function(List<int>) write,
}) async {
  final method = authenticationRequest == null ? 0 : 2;
  await write(method == 0 ? const [5, 1, 0] : const [5, 1, 2]);
  final selection = await read(2);
  if (selection[0] != 5) {
    throw const SocketException('Invalid SOCKS5 method response');
  }
  if (selection[1] != method) {
    throw const Socks5AuthenticationException();
  }
  if (authenticationRequest != null) {
    await write(authenticationRequest);
    final auth = await read(2);
    if (auth[0] != 1 || auth[1] != 0) {
      throw const Socks5AuthenticationException();
    }
  }

  // Parse literal IPs locally; leave all target DNS resolution to the proxy.
  final host = socks5ProxyHost(target.host);
  final ip = InternetAddress.tryParse(host);
  final address = ip?.rawAddress ?? utf8.encode(host);
  if (address.isEmpty || address.length > 255) {
    throw const FormatException('Invalid SOCKS5 target length');
  }
  final type = ip == null ? 3 : (ip.type == InternetAddressType.IPv4 ? 1 : 4);
  await write([
    5,
    1,
    0,
    type,
    if (type == 3) address.length,
    ...address,
    target.port >> 8,
    target.port & 0xff,
  ]);
  final reply = await read(4);
  if (reply[0] != 5 || reply[1] != 0 || reply[2] != 0) {
    throw const SocketException('Proxy did not open the SOCKS5 tunnel');
  }
  final addressLength = switch (reply[3]) {
    1 => 4,
    3 => (await read(1)).single,
    4 => 16,
    _ => throw const FormatException('Invalid SOCKS5 reply address'),
  };
  await read(addressLength + 2);
}
