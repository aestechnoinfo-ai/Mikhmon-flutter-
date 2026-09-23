import 'dart:math';

/// Conversions hexadécimales utilitaires.
class Hex {
  Hex._();

  static String encode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> decode(String hex) {
    final clean = hex.replaceAll(RegExp(r'[\s:]'), '');
    if (clean.length.isOdd) {
      throw ArgumentError('Longueur hexadécimale impaire : $hex');
    }
    final out = List<int>.filled(clean.length ~/ 2, 0);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String randomHex(int length) {
    final rnd = Random.secure();
    final buf = List<int>.generate(length, (_) => rnd.nextInt(256));
    return encode(buf);
  }
}