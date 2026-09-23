import 'dart:math';

/// Génère un identifiant local unique et compact.
String generateUid() {
  final now = DateTime.now();
  final rnd = Random.secure();
  final r = rnd.nextInt(0x7fffffff).toRadixString(36);
  final t = now.microsecondsSinceEpoch.toRadixString(36);
  return '$t-$r';
}

/// Génère une chaîne aléatoire à partir d'un jeu de caractères.
String randomString({required int length, required String charset}) {
  if (length <= 0 || charset.isEmpty) return '';
  final rnd = Random.secure();
  final sb = StringBuffer();
  for (var i = 0; i < length; i++) {
    sb.write(charset[rnd.nextInt(charset.length)]);
  }
  return sb.toString();
}