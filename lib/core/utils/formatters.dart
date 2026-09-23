/// Formats d'affichage et conversions de durées (compatibles RouterOS).
class Formatters {
  Formatters._();

  static String two(int v) => v.toString().padLeft(2, '0');

  /// Convertit une durée en valeur RouterOS `limit-uptime` : `D/HH:MM:SS`.
  static String toRouterosUptime(Duration d) {
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '$days/${two(h)}:${two(m)}:${two(s)}';
  }

  /// Lit une durée au format RouterOS (ex: `0/01:00:00`, `1d/02:00:00`,
  /// `02:00:00`). Tolère le suffixe `d` de RouterOS v7 et le format court.
  static Duration parseRouterosUptime(String? value) {
    if (value == null || value.isEmpty) return Duration.zero;
    final parts = value.split('/');
    var days = 0;
    if (parts.isNotEmpty) {
      final raw = parts[0].replaceAll('d', '').trim();
      days = int.tryParse(raw) ?? 0;
    }
    final hmss = parts.length > 1
        ? parts[1].split(':')
        : parts[0].split(':');
    // Format court `HH:MM:SS` sans jours : tout est dans parts[0].
    if (parts.length == 1 && hmss.length <= 3) {
      days = 0;
    }
    final h = hmss.length > 0 ? int.tryParse(hmss[0]) ?? 0 : 0;
    final m = hmss.length > 1 ? int.tryParse(hmss[1]) ?? 0 : 0;
    final s = hmss.length > 2 ? int.tryParse(hmss[2]) ?? 0 : 0;
    return Duration(days: days, hours: h, minutes: m, seconds: s);
  }

  /// Affiche une durée de façon lisible : `2 j 4 h`, `30 min`, `1 jour`.
  static String humanDuration(Duration d) {
    if (d.inSeconds == 0) return '-';
    if (d.inDays > 0) {
      if (d.inDays == 1) {
        return '${d.inDays} j ${d.inHours} h';
      }
      return '${d.inDays} j ${d.inHours % 24} h';
    }
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  /// Formatte des octets : B / KB / MB / GB.
  static String bytesReadable(num bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  /// Formatte un débit en kbps.
  static String kbpsReadable(num kbps) {
    if (kbps <= 0) return 'Illimité';
    if (kbps < 1000) return '${kbps.toStringAsFixed(0)} kbps';
    return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
  }

  /// Formatte un prix selon le symbole configuré.
  static String price(num value, [String symbol = '€']) {
    final txt = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$txt $symbol';
  }
}