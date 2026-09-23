import 'package:flutter/foundation.dart';

/// Réglages globaux de l'application (persistés).
@immutable
class AppSettings {
  final String currencySymbol;
  final String defaultServerId;
  final bool keepSessionOpen;
  final TransportChoiceX defaultTransport;
  final String voucherPrefix;
  final bool voucherUppercase;
  final bool voucherDigits;
  final int voucherLength;
  final int voucherPasswordLength;
  final bool voucherPasswordGenerated;
  final String voucherFixedPassword;
  final int voucherPerSheet;

  const AppSettings({
    this.currencySymbol = '€',
    this.defaultServerId = '',
    this.keepSessionOpen = true,
    this.defaultTransport = TransportChoiceX.auto,
    this.voucherPrefix = '',
    this.voucherUppercase = false,
    this.voucherDigits = true,
    this.voucherLength = 5,
    this.voucherPasswordLength = 5,
    this.voucherPasswordGenerated = true,
    this.voucherFixedPassword = '',
    this.voucherPerSheet = 6,
  });

  AppSettings copyWith({
    String? currencySymbol,
    String? defaultServerId,
    bool? keepSessionOpen,
    TransportChoiceX? defaultTransport,
    String? voucherPrefix,
    bool? voucherUppercase,
    bool? voucherDigits,
    int? voucherLength,
    int? voucherPasswordLength,
    bool? voucherPasswordGenerated,
    String? voucherFixedPassword,
    int? voucherPerSheet,
  }) {
    return AppSettings(
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultServerId: defaultServerId ?? this.defaultServerId,
      keepSessionOpen: keepSessionOpen ?? this.keepSessionOpen,
      defaultTransport: defaultTransport ?? this.defaultTransport,
      voucherPrefix: voucherPrefix ?? this.voucherPrefix,
      voucherUppercase: voucherUppercase ?? this.voucherUppercase,
      voucherDigits: voucherDigits ?? this.voucherDigits,
      voucherLength: voucherLength ?? this.voucherLength,
      voucherPasswordLength: voucherPasswordLength ?? this.voucherPasswordLength,
      voucherPasswordGenerated:
          voucherPasswordGenerated ?? this.voucherPasswordGenerated,
      voucherFixedPassword: voucherFixedPassword ?? this.voucherFixedPassword,
      voucherPerSheet: voucherPerSheet ?? this.voucherPerSheet,
    );
  }

  Map<String, dynamic> toJson() => {
        'currencySymbol': currencySymbol,
        'defaultServerId': defaultServerId,
        'keepSessionOpen': keepSessionOpen,
        'defaultTransport': defaultTransport.name,
        'voucherPrefix': voucherPrefix,
        'voucherUppercase': voucherUppercase,
        'voucherDigits': voucherDigits,
        'voucherLength': voucherLength,
        'voucherPasswordLength': voucherPasswordLength,
        'voucherPasswordGenerated': voucherPasswordGenerated,
        'voucherFixedPassword': voucherFixedPassword,
        'voucherPerSheet': voucherPerSheet,
      };

  static AppSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    TransportChoiceX transport = TransportChoiceX.auto;
    switch (json['defaultTransport']) {
      case 'api':
        transport = TransportChoiceX.api;
        break;
      case 'rest':
        transport = TransportChoiceX.rest;
        break;
    }
    return AppSettings(
      currencySymbol: json['currencySymbol'] as String? ?? '€',
      defaultServerId: json['defaultServerId'] as String? ?? '',
      keepSessionOpen: json['keepSessionOpen'] as bool? ?? true,
      defaultTransport: transport,
      voucherPrefix: json['voucherPrefix'] as String? ?? '',
      voucherUppercase: json['voucherUppercase'] as bool? ?? false,
      voucherDigits: json['voucherDigits'] as bool? ?? true,
      voucherLength: json['voucherLength'] as int? ?? 5,
      voucherPasswordLength: json['voucherPasswordLength'] as int? ?? 5,
      voucherPasswordGenerated:
          json['voucherPasswordGenerated'] as bool? ?? true,
      voucherFixedPassword: json['voucherFixedPassword'] as String? ?? '',
      voucherPerSheet: json['voucherPerSheet'] as int? ?? 6,
    );
  }
}

enum TransportChoiceX { api, rest, auto }