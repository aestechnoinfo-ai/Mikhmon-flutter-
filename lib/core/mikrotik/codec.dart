import 'dart:convert';
import 'dart:typed_data';

/// Encodage/décodage des trames du protocole API RouterOS v1.
///
/// Chaque trame = une longueur compacte (1 à 5 octets) suivie d'octets,
/// contenant des mots séparés par un octet nul.
class ApiFrameCodec {
  ApiFrameCodec._();

  static Uint8List encodeLength(int len) {
    if (len < 0x80) {
      return Uint8List.fromList([len]);
    }
    if (len < 0x4000) {
      return Uint8List.fromList([0x80 | (len >> 8), len & 0xff]);
    }
    if (len < 0x200000) {
      return Uint8List.fromList([
        0x80 | (len >> 16),
        0x80 | ((len >> 8) & 0xff),
        len & 0xff,
      ]);
    }
    if (len < 0x10000000) {
      return Uint8List.fromList([
        0x80 | (len >> 24),
        0x80 | ((len >> 16) & 0xff),
        0x80 | ((len >> 8) & 0xff),
        len & 0xff,
      ]);
    }
    return Uint8List.fromList([
      0xf0,
      (len >> 24) & 0xff,
      (len >> 16) & 0xff,
      (len >> 8) & 0xff,
      len & 0xff,
    ]);
  }

  /// Assimile une liste de mots en une trame.
  static List<int> pack(List<String> words) {
    final builder = BytesBuilder();
    for (final w in words) {
      builder.add(utf8.encode(w));
      builder.addByte(0);
    }
    final body = builder.takeBytes();
    final head = encodeLength(body.length);
    return [...head, ...body];
  }

  /// Désassemble une trame en liste de mots.
  static List<String> decodeWords(Uint8List data) {
    if (data.isEmpty) return const [];
    final text = utf8.decode(data, allowMalformed: true);
    return text
        .split('\x00')
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
  }
}