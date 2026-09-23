import 'dart:math';
import '../core/utils/uid.dart';
import '../models/app_settings.dart';

/// Paramètres de génération de nom d'utilisateur.
class UsernameFormat {
  final String prefix;
  final bool uppercase;
  final bool digits;
  final int length; // longueur de la partie aléatoire (hors préfixe)

  const UsernameFormat({
    this.prefix = '',
    this.uppercase = false,
    this.digits = true,
    this.length = 5,
  });

  String buildCharset() {
    final chars = StringBuffer();
    if (uppercase) {
      chars.write('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    } else {
      chars.write('abcdefghijklmnopqrstuvwxyz');
    }
    if (digits) {
      chars.write('0123456789');
    }
    if (chars.isEmpty) chars.write('abcdefghijklmnopqrstuvwxyz');
    return chars.toString();
  }

  String generate([Random? rng]) {
    final r = rng ?? Random.secure();
    final body = randomString(length: length, charset: buildCharset());
    return '$prefix$body';
  }
}

/// Générateur de vouchers avec gestion de collision face aux users existants.
class VoucherGenerator {
  final AppSettings settings;
  final Set<String> existingUsernames;
  final Random _rng;

  VoucherGenerator({
    required this.settings,
    this.existingUsernames = const {},
    Random? rng,
  }) : _rng = rng ?? Random.secure();

  UsernameFormat get _format => UsernameFormat(
        prefix: settings.voucherPrefix,
        uppercase: settings.voucherUppercase,
        digits: settings.voucherDigits,
        length: settings.voucherLength,
      );

  String _makePassword() {
    if (!settings.voucherPasswordGenerated) {
      return settings.voucherFixedPassword;
    }
    return randomString(
      length: settings.voucherPasswordLength,
      charset: 'abcdefghijklmnopqrstuvwxyz123456789'.replaceAll('l', ''),
    );
  }

  /// Génère un couple unique (username, password).
  Record generatePair() {
    final fmt = _format;
    var attempts = 0;
    while (attempts < 8) {
      final u = fmt.generate(_rng);
      attempts++;
      if (existingUsernames.contains(u)) continue;
      return (username: u, password: _makePassword());
    }
    throw StateError(
        'Impossible de générer un nom utilisateur unique (collisions trop nombreuses).');
  }

  /// Génère un lot de couples.
  List<Record> generateBatch(int count) {
    return List.generate(count, (_) => generatePair());
  }
}