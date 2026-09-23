import 'package:flutter/foundation.dart';

enum LogType { login, action, error, system, info }

extension LogTypeX on LogType {
  String get name => toString().split('.').last;
}

@immutable
class AppLog {
  final String id;
  final LogType type;
  final String message;
  final String? serverId;
  final DateTime createdAt;

  const AppLog({
    required this.id,
    required this.type,
    required this.message,
    this.serverId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'message': message,
        'serverId': serverId,
        'createdAt': createdAt.toIso8601String(),
      };

  static AppLog fromJson(Map<String, dynamic> json) {
    return AppLog(
      id: json['id'] as String? ?? '',
      type: LogType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LogType.info,
      ),
      message: json['message'] as String? ?? '',
      serverId: json['serverId'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}