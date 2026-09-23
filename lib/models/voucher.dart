import 'package:flutter/foundation.dart';

/// Un voucher généré (code hotspot).
@immutable
class Voucher {
  final String id;
  final String? serverId;
  final String profileName;
  final String username;
  final String password;
  final String code;
  final double price;
  final String currencySymbol;
  final String validityLabel;
  final String batchId;
  final DateTime createdAt;

  const Voucher({
    required this.id,
    this.serverId,
    required this.profileName,
    required this.username,
    required this.password,
    required this.code,
    required this.price,
    this.currencySymbol = '€',
    required this.validityLabel,
    required this.batchId,
    required this.createdAt,
  });

  Voucher copyWith({String? username, String? password, String? code}) {
    return Voucher(
      id: id,
      serverId: serverId,
      profileName: profileName,
      username: username ?? this.username,
      password: password ?? this.password,
      code: code ?? this.code,
      price: price,
      currencySymbol: currencySymbol,
      validityLabel: validityLabel,
      batchId: batchId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'profileName': profileName,
        'username': username,
        'password': password,
        'code': code,
        'price': price,
        'currencySymbol': currencySymbol,
        'validityLabel': validityLabel,
        'batchId': batchId,
        'createdAt': createdAt.toIso8601String(),
      };

  static Voucher fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id'] as String? ?? '',
      serverId: json['serverId'] as String?,
      profileName: json['profileName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      code: json['code'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currencySymbol: json['currencySymbol'] as String? ?? '€',
      validityLabel: json['validityLabel'] as String? ?? '',
      batchId: json['batchId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}