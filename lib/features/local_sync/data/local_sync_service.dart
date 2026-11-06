import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../domain/sync_models.dart';
import 'local_sync_store.dart';

enum LocalSyncPhase {
  idle,
  preparing,
  hosting,
  awaitingApproval,
  connecting,
  syncing,
  complete,
  failed,
}

/// A foreground-only, single-pair LAN session. The invitation is a bearer secret:
/// show it only to the intended peer. HTTP carries only authenticated ciphertext.
class LocalSyncService extends ChangeNotifier {
  LocalSyncService({
    required LocalSyncStore store,
    this.bindAddress,
    this.advertisedAddress,
    this.deviceName = 'Lira',
    this.allowLoopback = false,
    this.sessionLifetime = const Duration(minutes: 5),
    this.requestTimeout = const Duration(seconds: 45),
  }) : _store = store;

  final LocalSyncStore _store;
  final InternetAddress? bindAddress;
  final InternetAddress? advertisedAddress;
  final String deviceName;
  final bool allowLoopback;
  final Duration sessionLifetime;
  final Duration requestTimeout;

  LocalSyncPhase _phase = LocalSyncPhase.idle;
  LocalSyncPhase get phase => _phase;
  String? _invitation;
  String? get invitation => _invitation;
  String? _peerName;
  String? get peerName => _peerName;
  String? _error;
  String? get error => _error;
  SyncMergeResult? _result;
  SyncMergeResult? get result => _result;
  _Session? _session;
  bool _closed = false;
  int _generation = 0;

  static const _metadataLimit = 16 * 1024 * 1024;
  static const _chunkSize = 64 * 1024;
  static const _fileLimit = 2 * 1024 * 1024 * 1024;
  static const _requestLimit = 16384;
  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{22}$');
  static final _hashPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _cipher = AesGcm.with256bits();
  static final _random = Random.secure();

  void _notify() {
    if (!_closed) notifyListeners();
  }

  bool _active(_Session session) => !_closed && identical(_session, session);

  Future<void> host() async {
    await stop();
    if (_closed) return;
    final generation = _generation;
    _phase = LocalSyncPhase.preparing;
    _notify();
    _Session? session;
    try {
      final address = advertisedAddress ?? await _localAddress();
      if (_closed || generation != _generation) return;
      if (!_allowedAddress(address) ||
          sessionLifetime <= Duration.zero ||
          sessionLifetime > const Duration(minutes: 5)) {
        throw const _SyncFailure('noLocalAddress');
      }
      session = _Session(
        host: true,
        id: _randomId(),
        ownId: _randomId(),
        key: SecretKey(_randomBytes(32)),
        expires: DateTime.now().add(sessionLifetime),
      );
      _session = session;
      await _listen(session);
      if (!_active(session)) return;
      final keyBytes = await session.key.extractBytes();
      if (!_active(session)) return;
      _invitation =
          'lira-sync:${base64Url.encode(utf8.encode(jsonEncode({'v': 1, 'a': address.address, 'p': session.server!.port, 'k': base64Url.encode(keyBytes), 's': session.id, 'h': session.ownId, 'e': session.expires.millisecondsSinceEpoch}))).replaceAll('=', '')}';
      _phase = LocalSyncPhase.hosting;
      _notify();
    } catch (error) {
      await _fail(session, error, fallback: 'connectionFailed');
    }
  }

  Future<void> connect(String invitation) async {
    await stop();
    if (_closed) return;
    _phase = LocalSyncPhase.connecting;
    _notify();
    _Session? session;
    try {
      final invite = _parseInvitation(invitation);
      session =
          _Session(
              host: false,
              id: invite.sessionId,
              ownId: _randomId(),
              key: SecretKey(invite.key),
              expires: invite.expires,
            )
            ..peerId = invite.hostId
            ..peer = Uri(
              scheme: 'http',
              host: invite.address.address,
              port: invite.port,
            );
      _session = session;
      await _listen(session);
      session.snapshot = await _store.snapshot();
      _allowSnapshot(session, session.snapshot!);
      if (!_active(session)) return;
      _phase = LocalSyncPhase.awaitingApproval;
      _notify();
      final paired = await _requestJson(session, '/pair', {
        'port': session.server!.port,
        'name': _name(deviceName),
      }, approval: true);
      if (!_active(session)) return;
      _peerName = _name(paired['name']);
      session.approved = true;
      session.expiry?.cancel();
      _phase = LocalSyncPhase.syncing;
      _notify();
      final exchanged = await _requestJson(session, '/exchange', {
        'snapshot': session.snapshot!.toJson(),
      });
      final remote = SyncSnapshot.fromJson(_map(exchanged['snapshot']));
      final result = await _store.merge(
        remote,
        fetchBook: (hash) => _fetchBook(session!, hash),
      );
      if (!_active(session)) return;
      await _requestJson(session, '/done', const {});
      if (!_active(session)) return;
      _result = result;
      _phase = LocalSyncPhase.complete;
      _notify();
      await session.shutdown();
    } catch (error) {
      await _fail(session, error, fallback: 'transferFailed');
    }
  }

  Future<void> approve() async {
    final session = _session;
    if (session == null || !session.host || session.approval == null) return;
    if (!session.approval!.isCompleted) session.approval!.complete(true);
  }

  Future<void> reject() async {
    final session = _session;
    if (session == null || !session.host || session.approval == null) return;
    if (!session.approval!.isCompleted) session.approval!.complete(false);
  }

  Future<void> stop() async {
    _generation++;
    final previous = _session;
    _session = null;
    _invitation = null;
    _peerName = null;
    _error = null;
    _result = null;
    _phase = LocalSyncPhase.idle;
    _notify();
    await previous?.shutdown();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await stop();
    super.dispose();
  }

  Future<InternetAddress> _localAddress() async {
    final bound = bindAddress;
    if (bound != null && _allowedAddress(bound)) return bound;
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: true,
    )) {
      for (final address in interface.addresses) {
        if (_allowedAddress(address) && !address.isLoopback) return address;
      }
    }
    throw const _SyncFailure('noLocalAddress');
  }

  bool _allowedAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final bytes = address.rawAddress;
    return (allowLoopback && address.isLoopback) ||
        bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }

  _Invitation _parseInvitation(String source) {
    try {
      final text = source.trim();
      if (!text.startsWith('lira-sync:') || text.length > 2048) {
        throw const FormatException();
      }
      final data = _map(
        jsonDecode(
          utf8.decode(
            base64Url.decode(
              base64Url.normalize(text.substring('lira-sync:'.length)),
            ),
          ),
        ),
      );
      final address = InternetAddress.tryParse(data['a'] as String);
      final port = data['p'];
      final key = base64Url.decode(data['k'] as String);
      final sessionId = data['s'] as String;
      final hostId = data['h'] as String;
      final expires = DateTime.fromMillisecondsSinceEpoch(data['e'] as int);
      if (data['v'] != 1 ||
          address == null ||
          !_allowedAddress(address) ||
          port is! int ||
          port < 1 ||
          port > 65535 ||
          key.length != 32 ||
          !_idPattern.hasMatch(sessionId) ||
          !_idPattern.hasMatch(hostId)) {
        throw const FormatException();
      }
      if (!expires.isAfter(DateTime.now())) throw const _SyncFailure('expired');
      if (expires.isAfter(DateTime.now().add(const Duration(minutes: 6)))) {
        throw const FormatException();
      }
      return _Invitation(address, port, key, sessionId, hostId, expires);
    } on _SyncFailure {
      rethrow;
    } catch (_) {
      throw const _SyncFailure('invalidInvitation');
    }
  }

  Future<void> _listen(_Session session) async {
    final address = bindAddress ?? InternetAddress.anyIPv4;
    if (address != InternetAddress.anyIPv4 && !_allowedAddress(address)) {
      throw const _SyncFailure('noLocalAddress');
    }
    session.client = _DirectHttpOverrides().createHttpClient(null)
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = requestTimeout
      ..idleTimeout = requestTimeout
      ..autoUncompress = false;
    session.directory = await Directory.systemTemp.createTemp('lira-sync-');
    if (!_active(session)) {
      await session.shutdown();
      return;
    }
    session.server = await HttpServer.bind(address, 0, shared: false);
    if (!_active(session)) {
      await session.shutdown();
      return;
    }
    session.server!.autoCompress = false;
    session.server!.listen(
      (request) => unawaited(_handle(session, request)),
      onError: (Object error) => unawaited(_fail(session, error)),
    );
    session.expiry = Timer(session.expires.difference(DateTime.now()), () {
      unawaited(_fail(session, const _SyncFailure('expired')));
    });
  }

  void _check(_Session session) {
    if (!_active(session) || session.stopped) {
      throw const _SyncFailure('cancelled');
    }
    if (!session.approved && !session.expires.isAfter(DateTime.now())) {
      throw const _SyncFailure('expired');
    }
  }

  Future<void> _handle(_Session session, HttpRequest request) async {
    String? requestId;
    String? sender;
    var authenticated = false;
    var responseStarted = false;
    try {
      _check(session);
      if (request.method != 'POST' ||
          request.uri.hasQuery ||
          request.uri.path != request.uri.toString() ||
          !_allowedAddress(request.connectionInfo!.remoteAddress)) {
        throw const _SyncFailure('unauthorized');
      }
      final path = request.uri.path;
      if (path != '/pair' &&
          path != '/exchange' &&
          path != '/done' &&
          path != '/book') {
        throw const _SyncFailure('unauthorized');
      }
      requestId = request.headers.value('x-lira-request');
      sender = request.headers.value('x-lira-peer');
      if (requestId == null ||
          sender == null ||
          !_idPattern.hasMatch(requestId) ||
          !_idPattern.hasMatch(sender) ||
          (session.peerId != null && session.peerId != sender) ||
          (session.peerId == null && (!session.host || path != '/pair'))) {
        throw const _SyncFailure('unauthorized');
      }
      final replayKey = '$sender:$requestId';
      if (session.seen.contains(replayKey) ||
          session.seen.length >= _requestLimit) {
        throw const _SyncFailure('unauthorized');
      }
      final body = await _readBounded(request, _metadataLimit + 28);
      final plaintext = await _open(
        session,
        body,
        _aad(session, path, requestId, sender, session.ownId, response: false),
      );
      final payload = _map(jsonDecode(utf8.decode(plaintext)));
      // Mark only authenticated requests, before any asynchronous dispatch.
      session.seen.add(replayKey);
      authenticated = true;
      _check(session);
      if (path == '/pair') {
        if (!session.host || session.peerId != null) {
          throw const _SyncFailure('unauthorized');
        }
        final port = payload['port'];
        if (port is! int || port < 1 || port > 65535) {
          throw const _SyncFailure('unauthorized');
        }
        session.peerId = sender;
        // Never trust a callback host supplied by the peer.
        session.peer = Uri(
          scheme: 'http',
          host: request.connectionInfo!.remoteAddress.address,
          port: port,
        );
        _peerName = _name(payload['name']);
        session.approval = Completer<bool>();
        _phase = LocalSyncPhase.awaitingApproval;
        _notify();
        final approved = await session.approval!.future;
        _check(session);
        if (!approved) throw const _SyncFailure('rejected');
        session.snapshot = await _store.snapshot();
        _allowSnapshot(session, session.snapshot!);
        session.approved = true;
        session.expiry?.cancel();
        _phase = LocalSyncPhase.syncing;
        _notify();
        responseStarted = true;
        await _respond(session, request, requestId, sender, {
          'name': _name(deviceName),
        });
      } else {
        if (!session.approved || session.peerId != sender) {
          throw const _SyncFailure('unauthorized');
        }
        if (path == '/exchange') {
          if (!session.host || session.exchanged) {
            throw const _SyncFailure('unauthorized');
          }
          session.exchanged = true;
          final remote = SyncSnapshot.fromJson(_map(payload['snapshot']));
          session.mergeResult = await _store.merge(
            remote,
            fetchBook: (hash) => _fetchBook(session, hash),
          );
          _check(session);
          final merged = await _store.snapshot();
          _allowSnapshot(session, merged);
          responseStarted = true;
          await _respond(session, request, requestId, sender, {
            'snapshot': merged.toJson(),
          });
          session.exchangeFinished = true;
        } else if (path == '/done') {
          if (!session.host || !session.exchangeFinished || session.done) {
            throw const _SyncFailure('unauthorized');
          }
          session.done = true;
          responseStarted = true;
          await _respond(session, request, requestId, sender, const {});
          if (!_active(session)) return;
          _result = session.mergeResult;
          _phase = LocalSyncPhase.complete;
          _notify();
          await session.shutdown(graceful: true);
        } else if (path == '/book') {
          final hash = payload['hash'];
          if (hash is! String ||
              !_hashPattern.hasMatch(hash) ||
              !session.allowedBooks.contains(hash)) {
            throw const _SyncFailure('unauthorized');
          }
          final file = await _store.bookFile(hash);
          if (file == null) throw const _SyncFailure('transferFailed');
          responseStarted = true;
          await _sendBook(session, request, requestId, sender, file);
        }
      }
    } catch (error) {
      try {
        if (authenticated &&
            !responseStarted &&
            requestId != null &&
            sender != null &&
            _active(session) &&
            !session.stopped) {
          await _respond(session, request, requestId, sender, {
            'error': error is _SyncFailure ? error.code : 'transferFailed',
          });
        } else {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
        }
      } catch (_) {
        // The peer may already have cancelled its socket.
      }
      // Unauthenticated LAN probes cannot terminate an approved session.
      if (authenticated && error is! _SyncFailure) {
        await _fail(session, error);
      } else if (authenticated &&
          error is _SyncFailure &&
          error.code != 'unauthorized') {
        await _fail(session, error);
      }
    }
  }

  void _allowSnapshot(_Session session, SyncSnapshot snapshot) {
    for (final record in snapshot.records) {
      if (record.kind == 'book' && !record.deleted) {
        session.allowedBooks.add(record.bookHash);
      }
    }
  }

  Future<void> _respond(
    _Session session,
    HttpRequest request,
    String requestId,
    String recipient,
    Map<String, dynamic> value,
  ) async {
    final bytes = utf8.encode(jsonEncode(value));
    if (bytes.length > _metadataLimit)
      throw const _SyncFailure('transferFailed');
    final encrypted = await _seal(
      session,
      bytes,
      _aad(
        session,
        request.uri.path,
        requestId,
        session.ownId,
        recipient,
        response: true,
      ),
    );
    request.response.headers.contentType = ContentType.binary;
    request.response.contentLength = encrypted.length;
    request.response.add(encrypted);
    await request.response.close();
  }

  Future<(HttpClientResponse, String)> _request(
    _Session session,
    String path,
    Map<String, dynamic> data, {
    bool approval = false,
  }) async {
    _check(session);
    final requestId = _randomId();
    final bytes = utf8.encode(jsonEncode(data));
    if (bytes.length > _metadataLimit)
      throw const _SyncFailure('transferFailed');
    final encrypted = await _seal(
      session,
      bytes,
      _aad(
        session,
        path,
        requestId,
        session.ownId,
        session.peerId!,
        response: false,
      ),
    );
    final request = await session.client!
        .postUrl(session.peer!.replace(path: path))
        .timeout(requestTimeout);
    request.followRedirects = false;
    request.headers.contentType = ContentType.binary;
    request.headers.set('x-lira-peer', session.ownId);
    request.headers.set('x-lira-request', requestId);
    request.contentLength = encrypted.length;
    request.add(encrypted);
    final response = await request.close().timeout(
      approval ? session.expires.difference(DateTime.now()) : requestTimeout,
      onTimeout: () {
        request.abort();
        throw const _SyncFailure('connectionFailed');
      },
    );
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().timeout(requestTimeout);
      throw const _SyncFailure('unauthorized');
    }
    return (response, requestId);
  }

  Future<Map<String, dynamic>> _requestJson(
    _Session session,
    String path,
    Map<String, dynamic> data, {
    bool approval = false,
  }) async {
    final (response, requestId) = await _request(
      session,
      path,
      data,
      approval: approval,
    );
    final body = await _readBounded(response, _metadataLimit + 28);
    final decoded = await _open(
      session,
      body,
      _aad(
        session,
        path,
        requestId,
        session.peerId!,
        session.ownId,
        response: true,
      ),
    );
    final value = _map(jsonDecode(utf8.decode(decoded)));
    if (value['error'] is String) throw _SyncFailure(value['error'] as String);
    return value;
  }

  Future<void> _sendBook(
    _Session session,
    HttpRequest request,
    String requestId,
    String recipient,
    File file,
  ) async {
    final length = await file.length();
    if (length > _fileLimit) throw const _SyncFailure('transferFailed');
    request.response.headers.contentType = ContentType.binary;
    final input = await file.open();
    var index = 0;
    var total = 0;
    try {
      while (true) {
        _check(session);
        final bytes = await input.read(_chunkSize);
        if (bytes.isEmpty) break;
        total += bytes.length;
        if (total > _fileLimit || total > length) {
          throw const _SyncFailure('transferFailed');
        }
        final plain = Uint8List(bytes.length + 1)
          ..setRange(1, bytes.length + 1, bytes);
        final encrypted = await _seal(
          session,
          plain,
          _aad(
            session,
            request.uri.path,
            requestId,
            session.ownId,
            recipient,
            response: true,
            frame: index++,
          ),
        );
        request.response.add(_uint32(encrypted.length));
        request.response.add(encrypted);
        await request.response.flush().timeout(requestTimeout);
      }
      if (total != length) throw const _SyncFailure('transferFailed');
      final end = Uint8List(9)..[0] = 1;
      ByteData.sublistView(end).setUint64(1, total);
      final encrypted = await _seal(
        session,
        end,
        _aad(
          session,
          request.uri.path,
          requestId,
          session.ownId,
          recipient,
          response: true,
          frame: index,
        ),
      );
      request.response.add(_uint32(encrypted.length));
      request.response.add(encrypted);
      await request.response.close().timeout(requestTimeout);
    } finally {
      await input.close();
    }
  }

  Future<File> _fetchBook(_Session session, String hash) async {
    if (!_hashPattern.hasMatch(hash))
      throw const _SyncFailure('transferFailed');
    _check(session);
    const path = '/book';
    final (response, requestId) = await _request(session, path, {'hash': hash});
    final reader = _FrameReader(response.timeout(requestTimeout));
    final file = File('${session.directory!.path}/$hash-${_randomId()}');
    RandomAccessFile? output;
    var complete = false;
    var total = 0;
    var index = 0;
    _check(session);
    session.beginTransfer();
    try {
      output = await file.open(mode: FileMode.write);
      while (true) {
        _check(session);
        final lengthBytes = await reader.take(4);
        final length = ByteData.sublistView(lengthBytes).getUint32(0);
        if (length < 29 || length > _chunkSize + 29) {
          throw const _SyncFailure('transferFailed');
        }
        final plain = await _open(
          session,
          await reader.take(length),
          _aad(
            session,
            path,
            requestId,
            session.peerId!,
            session.ownId,
            response: true,
            frame: index++,
          ),
        );
        if (plain.isEmpty) throw const _SyncFailure('transferFailed');
        if (plain[0] == 1) {
          if (plain.length != 9 ||
              ByteData.sublistView(Uint8List.fromList(plain)).getUint64(1) !=
                  total) {
            throw const _SyncFailure('transferFailed');
          }
          await reader.requireEnd();
          complete = true;
          break;
        }
        if (plain[0] != 0 || plain.length < 2) {
          throw const _SyncFailure('transferFailed');
        }
        total += plain.length - 1;
        if (total > _fileLimit) throw const _SyncFailure('transferFailed');
        await output.writeFrom(plain, 1);
      }
      return file;
    } finally {
      await reader.cancel();
      await output?.close();
      if (!complete && await file.exists()) await file.delete();
      session.endTransfer();
    }
  }

  Future<Uint8List> _readBounded(Stream<List<int>> stream, int limit) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(requestTimeout)) {
      if (bytes.length + chunk.length > limit) {
        throw const _SyncFailure('transferFailed');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static List<int> _aad(
    _Session session,
    String path,
    String requestId,
    String sender,
    String recipient, {
    required bool response,
    int? frame,
  }) {
    // Includes direction, identities, endpoint, request and frame ordering.
    return utf8.encode(
      jsonEncode([
        1,
        session.id,
        'POST',
        path,
        requestId,
        sender,
        recipient,
        response ? 'response' : 'request',
        frame,
      ]),
    );
  }

  static Future<Uint8List> _seal(
    _Session session,
    List<int> plain,
    List<int> aad,
  ) async {
    final box = await _cipher.encrypt(
      plain,
      secretKey: session.key,
      nonce: _randomBytes(12),
      aad: aad,
    );
    return Uint8List(
        box.nonce.length + box.cipherText.length + box.mac.bytes.length,
      )
      ..setRange(0, box.nonce.length, box.nonce)
      ..setRange(
        box.nonce.length,
        box.nonce.length + box.cipherText.length,
        box.cipherText,
      )
      ..setRange(
        box.nonce.length + box.cipherText.length,
        box.nonce.length + box.cipherText.length + box.mac.bytes.length,
        box.mac.bytes,
      );
  }

  static Future<List<int>> _open(
    _Session session,
    List<int> bytes,
    List<int> aad,
  ) async {
    if (bytes.length < 28) throw const _SyncFailure('unauthorized');
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    try {
      return await _cipher.decrypt(
        SecretBox(
          Uint8List.sublistView(data, 12, data.length - 16),
          nonce: Uint8List.sublistView(data, 0, 12),
          mac: Mac(Uint8List.sublistView(data, data.length - 16)),
        ),
        secretKey: session.key,
        aad: aad,
      );
    } on SecretBoxAuthenticationError {
      throw const _SyncFailure('unauthorized');
    }
  }

  Future<void> _fail(
    _Session? session,
    Object error, {
    String fallback = 'transferFailed',
  }) async {
    if (_closed || (session != null && !_active(session))) return;
    _error = error is _SyncFailure ? error.code : fallback;
    _phase = LocalSyncPhase.failed;
    _result = null;
    _notify();
    await session?.shutdown();
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>)
      throw const FormatException('Invalid message');
    return value;
  }

  static String _name(Object? value) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > 80 ||
        value.runes.any((rune) => rune < 32 || rune == 127)) {
      throw const FormatException('Invalid device name');
    }
    return value.trim();
  }

  static Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );
  static String _randomId() =>
      base64Url.encode(_randomBytes(16)).replaceAll('=', '');
  static Uint8List _uint32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value);
}

class _Session {
  _Session({
    required this.host,
    required this.id,
    required this.ownId,
    required this.key,
    required this.expires,
  });

  final bool host;
  final String id;
  final String ownId;
  final SecretKey key;
  final DateTime expires;
  String? peerId;
  Uri? peer;
  HttpServer? server;
  HttpClient? client;
  Directory? directory;
  Timer? expiry;
  Completer<bool>? approval;
  SyncSnapshot? snapshot;
  SyncMergeResult? mergeResult;
  final seen = <String>{};
  final allowedBooks = <String>{};
  bool approved = false;
  bool exchanged = false;
  bool exchangeFinished = false;
  bool done = false;
  bool stopped = false;
  int _activeTransfers = 0;
  Completer<void>? _transfersDone;

  void beginTransfer() {
    if (_activeTransfers++ == 0) _transfersDone = Completer<void>();
  }

  void endTransfer() {
    if (--_activeTransfers == 0) _transfersDone!.complete();
  }

  Future<void> shutdown({bool graceful = false}) async {
    stopped = true;
    expiry?.cancel();
    if (approval != null && !approval!.isCompleted) approval!.complete(false);
    client?.close(force: !graceful);
    final listening = server;
    server = null;
    await listening?.close(force: !graceful);
    await _transfersDone?.future;
    final temporary = directory;
    if (temporary != null && await temporary.exists()) {
      try {
        await temporary.delete(recursive: true);
      } on FileSystemException {
        if (await temporary.exists()) rethrow;
      }
    }
  }
}

class _Invitation {
  const _Invitation(
    this.address,
    this.port,
    this.key,
    this.sessionId,
    this.hostId,
    this.expires,
  );
  final InternetAddress address;
  final int port;
  final List<int> key;
  final String sessionId;
  final String hostId;
  final DateTime expires;
}

class _SyncFailure implements Exception {
  const _SyncFailure(this.code);
  final String code;
}

/// Holds at most one socket chunk plus one bounded encrypted frame.
class _FrameReader {
  _FrameReader(Stream<List<int>> stream) : _iterator = StreamIterator(stream);
  final StreamIterator<List<int>> _iterator;
  List<int> _current = const [];
  int _offset = 0;

  Future<Uint8List> take(int count) async {
    final result = Uint8List(count);
    var written = 0;
    while (written < count) {
      if (_offset == _current.length) {
        if (!await _iterator.moveNext())
          throw const _SyncFailure('transferFailed');
        _current = _iterator.current;
        _offset = 0;
        if (_current.isEmpty) continue;
      }
      final size = min(count - written, _current.length - _offset);
      result.setRange(written, written + size, _current, _offset);
      written += size;
      _offset += size;
    }
    return result;
  }

  Future<void> requireEnd() async {
    if (_offset != _current.length) throw const _SyncFailure('transferFailed');
    while (await _iterator.moveNext()) {
      if (_iterator.current.isNotEmpty)
        throw const _SyncFailure('transferFailed');
    }
  }

  Future<void> cancel() => _iterator.cancel();
}

class _DirectHttpOverrides extends HttpOverrides {}
