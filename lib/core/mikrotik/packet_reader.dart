import 'dart:async';
import 'dart:typed_data';
import 'errors.dart';

/// Lecteur de trames découpé en morceaux depuis le flux de la socket.
class ApiPacketReader {
  final Stream<List<int>> _stream;
  final List<Uint8List> _chunks = [];
  final List<Completer<void>> _waiters = [];
  StreamSubscription<List<int>>? _sub;
  bool _done = false;

  ApiPacketReader(this._stream);

  Future<void> start() async {
    _sub = _stream.listen(
      (c) {
        if (c is! Uint8List) {
          _chunks.add(Uint8List.fromList(c));
        } else {
          _chunks.add(c);
        }
        _wakeAll();
      },
      onError: (Object e) {
        _done = true;
        _wakeAll();
      },
      onDone: () {
        _done = true;
        _wakeAll();
      },
    );
  }

  void _wakeAll() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  int _buffered() {
    var t = 0;
    for (final c in _chunks) {
      t += c.length;
    }
    return t;
  }

  Future<Uint8List> readExactly(int n) async {
    while (_buffered() < n) {
      if (_done) {
        throw const RouterosException('Connexion fermée par le routeur.');
      }
      final c = Completer<void>();
      _waiters.add(c);
      await c.future.timeout(
        const Duration(seconds: 40),
        onTimeout: () =>
            throw const RouterosException('Délai dépassé en lecture du routeur.'),
      );
    }
    final out = BytesBuilder();
    var need = n;
    while (need > 0) {
      final first = _chunks.first;
      if (first.length <= need) {
        out.add(first);
        need -= first.length;
        _chunks.removeAt(0);
      } else {
        out.add(first.sublist(0, need));
        _chunks[0] = first.sublist(need);
        need = 0;
      }
    }
    return out.takeBytes();
  }

  Future<int> readByte() async {
    final b = await readExactly(1);
    return b[0];
  }

  /// Lit une trame complète (en-tête de longueur compris).
  Future<Uint8List> readFrame() async {
    final len = await _readLength();
    if (len <= 0) return Uint8List(0);
    return readExactly(len);
  }

  Future<int> _readLength() async {
    final b0 = await readByte();
    if (b0 < 0x80) return b0;
    if (b0 == 0xf0) {
      final d = await readExactly(4);
      return (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3];
    }
    if ((b0 & 0xc0) == 0x80) {
      final b1 = await readByte();
      return ((b0 & 0x3f) << 8) | b1;
    }
    if ((b0 & 0xe0) == 0xc0) {
      final b1 = await readByte();
      final b2 = await readByte();
      return ((b0 & 0x1f) << 16) | (b1 << 8) | b2;
    }
    final b1 = await readByte();
    final b2 = await readByte();
    final b3 = await readByte();
    return ((b0 & 0x0f) << 24) | (b1 << 16) | (b2 << 8) | b3;
  }

  Future<void> dispose() async {
    _done = true;
    _wakeAll();
    await _sub?.cancel();
  }
}