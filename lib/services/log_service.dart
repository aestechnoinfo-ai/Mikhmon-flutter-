import '../core/storage/app_storage.dart';
import '../models/app_log.dart';
import '../core/utils/uid.dart';

/// Journal d'activité local.
class LogService {
  final AppStorage storage;

  LogService(this.storage);

  Future<void> info(String message, {String? serverId}) =>
      _add(LogType.info, message, serverId);

  Future<void> action(String message, {String? serverId}) =>
      _add(LogType.action, message, serverId);

  Future<void> error(String message, {String? serverId}) =>
      _add(LogType.error, message, serverId);

  Future<void> login(String message, {String? serverId}) =>
      _add(LogType.login, message, serverId);

  Future<void> _add(LogType type, String message, String? serverId) {
    return storage.addLog(
      AppLog(
        id: generateUid(),
        type: type,
        message: message,
        serverId: serverId,
        createdAt: DateTime.now(),
      ),
    );
  }
}