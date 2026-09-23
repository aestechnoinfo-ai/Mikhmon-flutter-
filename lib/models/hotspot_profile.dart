import 'package:flutter/foundation.dart';

/// Type de validité d'un profil.
enum ValidityType { uptime, expires }

/// Action appliquée à l'échéance du ticket (modes Mikhmon v3 / RouterOS).
enum ExpireMode {
  remove,          /// Supprime l'utilisateur du hotspot.
  notice,          /// Désactive + prévient (notice), sans purge immédiate.
  recordRemove,    /// Consigne l'événement puis supprime.
  recordNotice,    /// Consigne l'événement + prévient.
}

/// Profil hotspot local (miroir d'un profil hotspot RouterOS + tarif).
@immutable
class HotspotProfile {
  final String id;
  final String? serverId;
  final String name;
  final double price;
  final int uptimeSeconds;
  final int expiresDays;
  final ValidityType validityType;
  final ExpireMode expireMode;
  final int uploadKbps;
  final int downloadKbps;
  final int sharedUsers;
  final String comment;
  final bool synced;
  final DateTime createdAt;

  const HotspotProfile({
    required this.id,
    this.serverId,
    required this.name,
    this.price = 0,
    this.uptimeSeconds = 3600,
    this.expiresDays = 0,
    this.validityType = ValidityType.uptime,
    this.expireMode = ExpireMode.remove,
    this.uploadKbps = 0,
    this.downloadKbps = 0,
    this.sharedUsers = 0,
    this.comment = '',
    this.synced = false,
    required this.createdAt,
  });

  Duration get uptime => Duration(seconds: uptimeSeconds);

  String get validityLabel {
    if (validityType == ValidityType.expires) {
      return 'Expire après ${expiresDays} j';
    }
    final d = uptime;
    final h = d.inHours;
    if (h >= 24) {
      final days = h ~/ 24;
      final rem = h % 24;
      return days == 1 ? '1 j ${rem}h' : '$days j ${rem}h';
    }
    if (h > 0) return '$h h';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  String get rateLimitLabel {
    if (uploadKbps <= 0 && downloadKbps <= 0) return 'Illimité';
    return '↕ ${_kbps(downloadKbps)} ↑ ${_kbps(uploadKbps)}';
  }

  String get sharedLabel =>
      sharedUsers <= 0 ? 'Partage illimité' : '$sharedUsers utilisateur(s)';

  static String _kbps(int kbps) {
    if (kbps >= 1000) return '${(kbps / 1000).toStringAsFixed(1)}M';
    return '${kbps}K';
  }

  HotspotProfile copyWith({
    String? serverId,
    String? name,
    double? price,
    int? uptimeSeconds,
    int? expiresDays,
    ValidityType? validityType,
    ExpireMode? expireMode,
    int? uploadKbps,
    int? downloadKbps,
    int? sharedUsers,
    String? comment,
    bool? synced,
  }) {
    return HotspotProfile(
      id: id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      price: price ?? this.price,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      expiresDays: expiresDays ?? this.expiresDays,
      validityType: validityType ?? this.validityType,
      expireMode: expireMode ?? this.expireMode,
      uploadKbps: uploadKbps ?? this.uploadKbps,
      downloadKbps: downloadKbps ?? this.downloadKbps,
      sharedUsers: sharedUsers ?? this.sharedUsers,
      comment: comment ?? this.comment,
      synced: synced ?? this.synced,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'name': name,
        'price': price,
        'uptimeSeconds': uptimeSeconds,
        'expiresDays': expiresDays,
        'validityType': validityType.name,
        'expireMode': expireMode.name,
        'uploadKbps': uploadKbps,
        'downloadKbps': downloadKbps,
        'sharedUsers': sharedUsers,
        'comment': comment,
        'synced': synced,
        'createdAt': createdAt.toIso8601String(),
      };

  static HotspotProfile fromJson(Map<String, dynamic> json) {
    return HotspotProfile(
      id: json['id'] as String? ?? '',
      serverId: json['serverId'] as String?,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      uptimeSeconds: json['uptimeSeconds'] as int? ?? 3600,
      expiresDays: json['expiresDays'] as int? ?? 0,
      validityType: ValidityType.values.asNameMap()[json['validityType']] ??
          ValidityType.uptime,
      uploadKbps: json['uploadKbps'] as int? ?? 0,
      downloadKbps: json['downloadKbps'] as int? ?? 0,
      sharedUsers: json['sharedUsers'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      synced: json['synced'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}