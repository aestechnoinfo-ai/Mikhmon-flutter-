import 'package:flutter/foundation.dart';
import '../core/utils/formatters.dart';

/// Utilisateur hotspot lu depuis le routeur.
@immutable
class RemoteHotspotUser {
  final String id; // .id
  final String name;
  final String password;
  final String profile;
  final String comment;
  final String server;
  final String limitUptime;
  final int limitBytesTotal;
  final int limitBytesIn;
  final int limitBytesOut;
  final bool disabled;
  final bool isValid;
  final String? expiration;
  final String? createdAt;

  const RemoteHotspotUser({
    required this.id,
    required this.name,
    this.password = '',
    this.profile = '',
    this.comment = '',
    this.server = '',
    this.limitUptime = '',
    this.limitBytesTotal = 0,
    this.limitBytesIn = 0,
    this.limitBytesOut = 0,
    this.disabled = false,
    this.isValid = true,
    this.expiration,
    this.createdAt,
  });

  Duration get limitDuration => Formatters.parseRouterosUptime(limitUptime);

  String get limitUptimeLabel =>
      Formatters.humanDuration(limitDuration);

  String get bytesLabel => Formatters.bytesReadable(limitBytesTotal);

  bool get canExpireLater => !isValid && !disabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'password': password,
        'profile': profile,
        'comment': comment,
        'server': server,
        'limitUptime': limitUptime,
        'limitBytesTotal': limitBytesTotal,
        'disabled': disabled,
        'isValid': isValid,
      };

  static RemoteHotspotUser fromRouteros(Map<String, String> m) {
    return RemoteHotspotUser(
      id: m['.id'] ?? '',
      name: m['name'] ?? '',
      password: m['password'] ?? '',
      profile: m['profile'] ?? '',
      comment: m['comment'] ?? '',
      server: m['server'] ?? '',
      limitUptime: m['limit-uptime'] ?? '',
      limitBytesTotal: int.tryParse(m['limit-bytes-total'] ?? '') ?? 0,
      limitBytesIn: int.tryParse(m['limit-bytes-in'] ?? '') ?? 0,
      limitBytesOut: int.tryParse(m['limit-bytes-out'] ?? '') ?? 0,
      disabled: m['disabled'] == 'true',
      isValid: m['valid'] == 'true',
      expiration: m['expires-after'],
      createdAt: m['creation-time'],
    );
  }
}

/// Session hotspot active.
@immutable
class ActiveSession {
  final String id; // .id
  final String user;
  final String address;
  final String macAddress;
  final String uptime;
  final String idleTime;
  final String comment;
  final String keepaliveTimeout;
  final String bytesIn;
  final String bytesOut;
  final String server;

  const ActiveSession({
    required this.id,
    required this.user,
    this.address = '',
    this.macAddress = '',
    this.uptime = '',
    this.idleTime = '',
    this.comment = '',
    this.keepaliveTimeout = '',
    this.bytesIn = '0',
    this.bytesOut = '0',
    this.server = '',
  });

  Duration get sessionUptime => Formatters.parseRouterosUptime(uptime);

  String get sessionUptimeLabel => Formatters.humanDuration(sessionUptime);

  static ActiveSession fromRouteros(Map<String, String> m) {
    return ActiveSession(
      id: m['.id'] ?? '',
      user: m['user'] ?? '',
      address: m['address'] ?? '',
      macAddress: m['mac-address'] ?? '',
      uptime: m['uptime'] ?? '',
      idleTime: m['idle-time'] ?? '',
      comment: m['comment'] ?? m['host'] ?? '',
      keepaliveTimeout: m['keepalive-timeout'] ?? '',
      bytesIn: m['bytes-in'] ?? '0',
      bytesOut: m['bytes-out'] ?? '0',
      server: m['server'] ?? '',
    );
  }
}

/// Profil hotspot lu depuis le routeur.
@immutable
class RemoteHotspotProfile {
  final String id; // .id
  final String name;
  final String rateLimit;
  final String validity;
  final String sharedUsers;
  final String macCookie;

  const RemoteHotspotProfile({
    required this.id,
    required this.name,
    this.rateLimit = '',
    this.validity = '',
    this.sharedUsers = '',
    this.macCookie = '',
  });

  static RemoteHotspotProfile fromRouteros(Map<String, String> m) {
    return RemoteHotspotProfile(
      id: m['.id'] ?? '',
      name: m['name'] ?? '',
      rateLimit: m['rate-limit'] ?? '',
      validity: m['validity'] ?? '',
      sharedUsers: m['shared-users'] ?? '',
      macCookie: m['mac-cookie'] ?? '',
    );
  }
}

/// Statistiques système du routeur.
@immutable
class RouterMetrics {
  final String identity;
  final String version;
  final String boardName;
  final int uptimeSeconds;
  final double cpuLoad;
  final int freeMemory;
  final int totalMemory;
  final int freeHdd;
  final int totalHdd;
  final String architecture;
  final String buildTime;

  const RouterMetrics({
    this.identity = '',
    this.version = '',
    this.boardName = '',
    this.uptimeSeconds = 0,
    this.cpuLoad = 0,
    this.freeMemory = 0,
    this.totalMemory = 0,
    this.freeHdd = 0,
    this.totalHdd = 0,
    this.architecture = '',
    this.buildTime = '',
  });

  Duration get uptime => Duration(seconds: uptimeSeconds);

  String get cpuLabel => '${cpuLoad.toStringAsFixed(1)} %';
  String get memLabel => '${_mb(freeMemory)} / ${_mb(totalMemory)} Mo';
  double get memoryUsage =>
      totalMemory <= 0 ? 0 : ((totalMemory - freeMemory) / totalMemory) * 100;
  double get hddUsage => totalHdd <= 0 ? 0 : ((totalHdd - freeHdd) / totalHdd) * 100;
  String get hddLabel => '${_mb(freeHdd)} / ${_mb(totalHdd)} Mo';

  static String _mb(int b) => (b / 1048576).toStringAsFixed(0);

  static RouterMetrics fromRouteros(List<Map<String, String>> rows) {
    if (rows.isEmpty) return const RouterMetrics();
    final m = rows.first;
    final mem = int.tryParse(m['free-memory'] ?? '') ?? 0;
    final tot = int.tryParse(m['total-memory'] ?? '') ?? 0;
    return RouterMetrics(
      identity: m['identity'] ?? '',
      version: m['version'] ?? '',
      boardName: m['board-name'] ?? '',
      uptimeSeconds: Formatters.parseRouterosUptime(m['uptime']).inSeconds,
      cpuLoad: double.tryParse(m['cpu-load'] ?? '') ?? 0,
      freeMemory: mem,
      totalMemory: tot,
      freeHdd: int.tryParse(m['free-hdd-space'] ?? '') ?? 0,
      totalHdd: int.tryParse(m['total-hdd-space'] ?? '') ?? 0,
      architecture: m['architecture-name'] ?? '',
      buildTime: m['build-time'] ?? '',
    );
  }
}

/// Entrée de log système du routeur.
@immutable
class SystemLogEntry {
  final String time;
  final String topics;
  final String message;
  final String? id;

  const SystemLogEntry({
    required this.time,
    this.topics = '',
    this.message = '',
    this.id,
  });

  static SystemLogEntry fromRouteros(Map<String, String> m) {
    return SystemLogEntry(
      id: m['.id'],
      time: m['time'] ?? '',
      topics: m['topics'] ?? '',
      message: m['message'] ?? '',
    );
  }
}