import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Reads only handshake bytes while retaining any bytes coalesced with them.
/// StreamIterator pauses the native subscription between reads, including when
/// handing the original socket to SecureSocket.secure for a native TLS upgrade.
class Socks5SocketReader {
  Socks5SocketReader(Socket socket) : _chunks = StreamIterator(socket);

  final StreamIterator<Uint8List> _chunks;
  Uint8List _chunk = Uint8List(0);
  int _offset = 0;

  Future<List<int>> readExactly(int count) async {
    final bytes = Uint8List(count);
    var copied = 0;
    while (copied < count) {
      if (_offset == _chunk.length) {
        if (!await _chunks.moveNext()) {
          throw const SocketException('Peer closed during SOCKS5 negotiation');
        }
        _chunk = _chunks.current;
        _offset = 0;
      }
      final available = _chunk.length - _offset;
      final remaining = count - copied;
      final take = available < remaining ? available : remaining;
      bytes.setRange(copied, copied + take, _chunk, _offset);
      _offset += take;
      copied += take;
    }
    return bytes;
  }

  Stream<Uint8List> _remaining() async* {
    try {
      if (_offset < _chunk.length) {
        yield Uint8List.sublistView(_chunk, _offset);
      }
      while (await _chunks.moveNext()) {
        yield _chunks.current;
      }
    } finally {
      await _chunks.cancel();
    }
  }

  Socket tunnel(Socket socket) => _TunnelSocket(socket, _remaining());
}

/// Only the input stream changes after SOCKS framing is consumed. All socket
/// and sink operations keep their native semantics; TLS uses the native socket
/// directly rather than attempting to detach this forwarding wrapper.
class _TunnelSocket extends StreamView<Uint8List> implements Socket {
  _TunnelSocket(this._socket, Stream<Uint8List> input) : super(input);

  final Socket _socket;

  @override
  Encoding get encoding => _socket.encoding;
  @override
  set encoding(Encoding value) => _socket.encoding = value;
  @override
  void add(List<int> data) => _socket.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream);
  @override
  InternetAddress get address => _socket.address;
  @override
  Future<void> close() => _socket.close();
  @override
  void destroy() => _socket.destroy();
  @override
  Future<void> get done => _socket.done;
  @override
  Future<void> flush() => _socket.flush();
  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);
  @override
  int get port => _socket.port;
  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;
  @override
  int get remotePort => _socket.remotePort;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);
  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
  @override
  void write(Object? object) => _socket.write(object);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _socket.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => _socket.writeln(object);
}
