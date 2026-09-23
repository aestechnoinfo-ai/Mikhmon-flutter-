import 'package:flutter/foundation.dart';
import '../core/mikrotik/errors.dart';
import '../core/mikrotik/mikrotik_service.dart';
import '../core/storage/app_storage.dart';
import '../models/app_settings.dart';
import '../models/router_server.dart';
import '../services/auth_service.dart';
import '../services/log_service.dart';

enum AppStatus {
  init,
  unauthenticated,
  authenticated,
  connecting,
  connected,
  error,
}

/// État global de l'application (auth, serveurs, connexion courante).
class AppState extends ChangeNotifier {
  final AppStorage storage;
  final AuthService auth;
  final LogService log;

  AppState(this.storage, this.auth, this.log);

  AppStatus status = AppStatus.init;
  RouterServer? currentServer;
  MikrotikService? service;
  String? errorMessage;

  List<RouterServer> get servers => storage.servers;
  AppSettings get settings => storage.settings;

  RouterServer? get defaultServer =>
      storage.serverById(settings.defaultServerId) ??
      (servers.isNotEmpty ? servers.first : null);

  RouterServer? get current => currentServer;

  Future<void> initialize() async {
    await storage.init();
    if (storage.loggedIn) {
      status = AppStatus.authenticated;
      final def = defaultServer;
      if (def != null) {
        await selectServer(def.id, notify: false);
      }
    } else {
      status = AppStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<AuthResult> login(String user, String pass) async {
    final res = await auth.login(user, pass);
    if (res.ok) {
      status = AppStatus.authenticated;
      await log.login('Connexion réussie ($user)');
    } else {
      await log.error('Échec de connexion ($user)');
    }
    notifyListeners();
    return res;
  }

  Future<void> logout() async {
    await auth.logout();
    await disconnect();
    currentServer = null;
    status = AppStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> addServer(RouterServer server) async {
    await storage.upsertServer(server);
    await log.action('Serveur ajouté : ${server.name} (${server.host})',
        serverId: server.id);
    notifyListeners();
  }

  Future<void> updateServer(RouterServer server) async {
    await storage.upsertServer(server);
    await log.action('Serveur modifié : ${server.name}',
        serverId: server.id);
    if (currentServer?.id == server.id) {
      currentServer = server;
      service = null;
    }
    notifyListeners();
  }

  Future<void> deleteServer(String id) async {
    await storage.removeServer(id);
    await log.action('Serveur supprimé ($id)');
    if (currentServer?.id == id) {
      await disconnect();
      currentServer = null;
    }
    notifyListeners();
  }

  Future<void> selectServer(String id, {bool notify = true}) async {
    final server = storage.serverById(id);
    if (server == null) return;
    await disconnect();
    currentServer = server;
    errorMessage = null;
    if (notify) notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> connect() async {
    final server = currentServer;
    if (server == null) {
      status = AppStatus.authenticated;
      errorMessage = 'Aucun serveur sélectionné.';
      notifyListeners();
      return;
    }
    status = AppStatus.connecting;
    errorMessage = null;
    notifyListeners();
    try {
      final svc = MikrotikService(server);
      await svc.connect();
      service = svc;
      status = AppStatus.connected;
      await log.action('Connexion établie vers ${server.name} '
          'via ${svc.connectedLabel}',
          serverId: server.id);
    } on RitikException catch (e) {
      await disconnect();
      status = AppStatus.authenticated;
      errorMessage = e.message;
      await log.error('Connexion échouée ${server.host} : ${e.message}',
          serverId: server.id);
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    final s = service;
    service = null;
    if (s != null) await s.disconnect();
    if (status == AppStatus.connected || status == AppStatus.connecting) {
      status = currentServer != null
          ? AppStatus.authenticated
          : AppStatus.unauthenticated;
    }
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    await storage.saveSettings(newSettings);
    await log.action('Réglages mis à jour');
    notifyListeners();
  }

  /// Enregistre dans la storage le serveur courant après édition (ex: test OK).
  Future<void> persistCurrentServer() async {
    final s = currentServer;
    if (s != null) {
      await storage.upsertServer(s);
      notifyListeners();
    }
  }
}