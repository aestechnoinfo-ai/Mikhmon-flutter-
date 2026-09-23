import 'package:flutter/foundation.dart';

/// Transport choisi pour joindre un routeur.
enum TransportChoice { api, rest, auto }

/// Méthode de login API RouterOS.
enum ApiLoginMethod { auto, v6, v7 }

/// Représente un routeur MikroTik configuré (serveur hotspot).
@immutable
class RouterServer {
  final String id;
  final String name;
  final String host;
  final int apiPort;
  final int apiSslPort;
  final int restPort;
  final int restSslPort;
  final bool useApiSsl;
  final bool useRestSsl;
  final String username;
  final String password;
  final TransportChoice transport;
  final ApiLoginMethod loginMethod;
  final String hotspotName;
  final DateTime createdAt;
  final bool enabled;

  const RouterServer({
    required this.id,
    required this.name,
    required this.host,
    this.apiPort = 8728,
    this.apiSslPort = 8729,
    this.restPort = 80,
    this.restSslPort = 443,
    this.useApiSsl = false,
    this.useRestSsl = true,
    required this.username,
    required this.password,
    this.transport = TransportChoice.auto,
    this.loginMethod = ApiLoginMethod.auto,
    this.hotspotName = 'hotspot1',
    required this.createdAt,
    this.enabled = true,
  });

  String get idLabel => id;

  RouterServer copyWith({
    String? name,
    String? host,
    int? apiPort,
    int? apiSslPort,
    int? restPort,
    int? restSslPort,
    bool? useApiSsl,
    bool? useRestSsl,
    String? username,
    String? password,
    TransportChoice? transport,
    ApiLoginMethod? loginMethod,
    String? hotspotName,
    bool? enabled,
  }) {
    return RouterServer(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      apiPort: apiPort ?? this.apiPort,
      apiSslPort: apiSslPort ?? this.apiSslPort,
      restPort: restPort ?? this.restPort,
      restSslPort: restSslPort ?? this.restSslPort,
      useApiSsl: useApiSsl ?? this.useApiSsl,
      useRestSsl: useRestSsl ?? this.useRestSsl,
      username: username ?? this.username,
      password: password ?? this.password,
      transport: transport ?? this.transport,
      loginMethod: loginMethod ?? this.loginMethod,
      hotspotName: hotspotName ?? this.hotspotName,
      createdAt: createdAt,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'apiPort': apiPort,
        'apiSslPort': apiSslPort,
        'restPort': restPort,
        'restSslPort': restSslPort,
        'useApiSsl': useApiSsl,
        'useRestSsl': useRestSsl,
        'username': username,
        'password': password,
        'transport': transport.name,
        'loginMethod': loginMethod.name,
        'hotspotName': hotspotName,
        'createdAt': createdAt.toIso8601String(),
        'enabled': enabled,
      };

  static RouterServer fromJson(Map<String, dynamic> json) {
    return RouterServer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      apiPort: json['apiPort'] as int? ?? 8728,
      apiSslPort: json['apiSslPort'] as int? ?? 8729,
      restPort: json['restPort'] as int? ?? 80,
      restSslPort: json['restSslPort'] as int? ?? 443,
      useApiSsl: json['useApiSsl'] as bool? ?? false,
      useRestSsl: json['useRestSsl'] as bool? ?? true,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      transport: TransportChoice.values.asNameMap()[json['transport']] ??
          TransportChoice.auto,
      loginMethod: ApiLoginMethod.values.asNameMap()[json['loginMethod']] ??
          ApiLoginMethod.auto,
      hotspotName: json['hotspotName'] as String? ?? 'hotspot1',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RouterServer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}