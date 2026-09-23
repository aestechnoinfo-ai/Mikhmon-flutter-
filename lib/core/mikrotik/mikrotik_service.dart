import 'package:flutter/foundation.dart'
    show kIsWeb;
import '../constants/app_constants.dart';
import '../../models/remote_entities.dart';
import '../../models/router_server.dart';
import '../utils/formatters.dart';
import 'errors.dart';
import 'rest_client.dart';
import 'routeros_client.dart';

/// Service unifié vers un routeur MikroTik.
///
/// Choisit automatiquement **API RouterOS** (socket, Desktop/Mobile) ou
/// **API REST** (Web ou secours), selon `RouterServer.transport`.
class MikrotikService {
  final RouterServer server;

  RouterosClient? _api;
  RestClient? _rest;
  TransportChoice? _usedTransport;
  String? _connectedAs;

  MikrotikService(this.server);

  bool get isConnected => _usedTransport != null;

  TransportChoice? get usedTransport => _usedTransport;

  String get connectedLabel {
    switch (_usedTransport) {
      case TransportChoice.api:
        return 'RouterOS API';
      case TransportChoice.rest:
        return 'REST API';
      default:
        return '—';
    }
  }

  Future<void> connect() async {
    final t = server.transport;

    // Mode auto : API sur plateformes natives, REST sur le Web.
    if (t == TransportChoice.auto && kIsWeb) {
      await _connectRest();
      return;
    }
    if (t == TransportChoice.rest) {
      await _connectRest();
      return;
    }
    if (t == TransportChoice.api) {
      await _connectApi();
      return;
    }
    // auto non-web : API puisse le login échouer → REST en secours.
    try {
      await _connectApi();
    } on RitikException {
      if (kIsWeb) rethrow;
      await _connectRest();
    }
  }

  Future<void> _connectApi() async {
    await disconnect();
    final api = RouterosClient();
    await api.connect(
      server.host,
      server.useApiSsl ? server.apiSslPort : server.apiPort,
      ssl: server.useApiSsl,
    );
    await api.login(
      server.username,
      server.password,
      method: server.loginMethod.name,
    );
    _api = api;
    _rest?.close();
    _rest = null;
    _usedTransport = TransportChoice.api;
    _connectedAs = server.username;
  }

  Future<void> _connectRest() async {
    await disconnect();
    final rest = RestClient(
      host: server.host,
      port: server.useRestSsl ? server.restSslPort : server.restPort,
      useSsl: server.useRestSsl,
      username: server.username,
      password: server.password,
    );
    await rest.login();
    _rest = rest;
    _api?.disconnect();
    _api = null;
    _usedTransport = TransportChoice.rest;
    _connectedAs = server.username;
  }

  Future<void> disconnect() async {
    final a = _api;
    final r = _rest;
    _api = null;
    _rest = null;
    _usedTransport = null;
    if (a != null) await a.disconnect();
    if (r != null) await r.close();
  }

  bool get _isApi => _usedTransport == TransportChoice.api;

  RouterosClient get _apiClient {
    final c = _api;
    if (c == null) throw const NotConnectedException();
    return c;
  }

  RestClient get _restClient {
    final c = _rest;
    if (c == null) throw const NotConnectedException();
    return c;
  }

  // ------------------------------------------------------------------
  //  Primitives de transport
  // ------------------------------------------------------------------

  List<Map<String, String>> _normalizeRows(dynamic data) {
    if (data is! List) return const [];
    final out = <Map<String, String>>[];
    for (final item in data) {
      if (item is Map) {
        out.add(item.map((k, v) => MapEntry(
              k.toString(),
              v == null ? '' : v.toString(),
            )));
      }
    }
    return out;
  }

  /// `cmd` : `ip/hotspot/user` (sans slash de départ).
  Future<List<Map<String, String>>> printRows(
    String cmd, {
    List<Map<String, String>> queries = const [],
  }) async {
    if (_isApi) {
      final rows = await _apiClient.execute(
        ['/${cmd}/print'],
        queries: queries,
      );
      return rows;
    }
    final query = <String, String>{};
    for (final q in queries) {
      query.addAll(q);
    }
    return _normalizeRows(
      await _restClient.request('GET', '$cmd/print', query: query),
    );
  }

  Future<void> add(String cmd, Map<String, dynamic> params) async {
    if (_isApi) {
      await _apiClient.execute(
        ['/${cmd}/add'],
        params: params.entries.map((e) => '=${e.key}=${e.value}').toList(),
      );
      return;
    }
    await _restClient.request('POST', cmd, body: params);
  }

  Future<void> set(String cmd, Map<String, dynamic> params, {String? id}) async {
    if (_isApi) {
      final words = <String>['/${cmd}/set'];
      if (id != null) words.add('=numbers=$id');
      words.addAll(params.entries.map((e) => '=${e.key}=${e.value}'));
      await _apiClient.execute(words);
      return;
    }
    await _restClient.request(
      'POST',
      '$cmd/set',
      body: {
        if (id != null) 'numbers': [id],
        ...params,
      },
    );
  }

  Future<void> remove(String cmd, String id) async {
    if (_isApi) {
      await _apiClient.execute(['/${cmd}/remove', '=numbers=$id']);
      return;
    }
    try {
      await _restClient.request('DELETE', '$cmd/$id');
    } on RitikException {
      await _restClient.request(
        'POST',
        '$cmd/remove',
        body: {'numbers': [id]},
      );
    }
  }

  // ------------------------------------------------------------------
  //  Métriques & identité
  // ------------------------------------------------------------------

  Future<RouterMetrics> fetchMetrics() async {
    final rows = await printRows('system/resource');
    return RouterMetrics.fromRouteros(rows);
  }

  Future<Map<String, String>> fetchIdentity() async {
    final rows = await printRows('system/identity');
    return rows.isEmpty ? const {} : rows.first;
  }

  Future<RouterMetrics> ping() async {
    final m = await fetchMetrics();
    if (m.identity.isEmpty) {
      final identity = await fetchIdentity();
      return RouterMetrics(
        identity: identity['name'] ?? '',
        version: m.version,
        boardName: m.boardName,
        uptimeSeconds: m.uptimeSeconds,
        cpuLoad: m.cpuLoad,
        freeMemory: m.freeMemory,
        totalMemory: m.totalMemory,
        freeHdd: m.freeHdd,
        totalHdd: m.totalHdd,
      );
    }
    return m;
  }

  // ------------------------------------------------------------------
  //  Hotspot
  // ------------------------------------------------------------------

  Future<RemoteHotspotProfile?> findHotspotProfileByName(String name) async {
    final rows = await printRows('ip/hotspot/profile');
    for (final r in rows) {
      if (r['name'] == name) return RemoteHotspotProfile.fromRouteros(r);
    }
    return null;
  }

  Future<List<RemoteHotspotProfile>> listHotspotProfiles() async {
    final rows = await printRows('ip/hotspot/profile');
    return rows.map(RemoteHotspotProfile.fromRouteros).toList();
  }

  /// Crée le profil sur le routeur (limite montante/descendante, partage).
  Future<void> createHotspotProfile({
    required String name,
    String? rateLimit,
    int sharedUsers = 0,
  }) async {
    final params = <String, dynamic>{
      'name': name,
      if (rateLimit != null && rateLimit.isNotEmpty) 'rate-limit': rateLimit,
      if (sharedUsers > 0) 'shared-users': sharedUsers.toString(),
    };
    await add('ip/hotspot/profile', params);
  }

  Future<void> deleteHotspotProfile(String name) async {
    final rows = await printRows('ip/hotspot/profile');
    for (final r in rows) {
      if (r['name'] == name) {
        await remove('ip/hotspot/profile', r['.id'] ?? name);
        return;
      }
    }
    throw RitikException('Profil hotspots "$name" introuvable sur le routeur.');
  }

  Future<List<RemoteHotspotUser>> listHotspotUsers({
    String? profile,
    String? nameEquals,
  }) async {
    final queries = <Map<String, String>>[];
    if (profile != null && profile.isNotEmpty) queries.add({'profile': profile});
    if (nameEquals != null && nameEquals.isNotEmpty) {
      queries.add({'name': nameEquals});
    }
    final rows = queries.isEmpty
        ? await printRows('ip/hotspot/user')
        : await printRows('ip/hotspot/user', queries: queries);
    return rows.map(RemoteHotspotUser.fromRouteros).toList();
  }

  Future<int> countHotspotUsers({String? profile}) async {
    final users = await listHotspotUsers(profile: profile);
    return users.length;
  }

  Future<RemoteHotspotUser?> findUserByName(String username) async {
    final users = await listHotspotUsers();
    for (final u in users) {
      if (u.name == username) return u;
    }
    return null;
  }

  /// Ajoute un user hotspot. `limitUptime` au format RouterOS `D/HH:MM:SS`.
  Future<void> createHotspotUser({
    required String username,
    required String password,
    required String profile,
    Duration? limitUptime,
    int? limitBytesTotal,
    String comment = '',
  }) async {
    final params = <String, dynamic>{
      'server': server.hotspotName,
      'name': username,
      'password': password,
      'profile': profile,
      if (limitUptime != null && limitUptime.inSeconds > 0)
        'limit-uptime': Formatters.toRouterosUptime(limitUptime),
      if (limitBytesTotal != null && limitBytesTotal > 0)
        'limit-bytes-total': '$limitBytesTotal',
      if (comment.isNotEmpty) 'comment': comment,
    };
    try {
      await add('ip/hotspot/user', params);
    } on RitikException {
      // Astuce : certains routeurs (mélanges v6) refusent `server` explicite
      // quand un seul serveur hotspot existe → retente sans le champ.
      params.remove('server');
      await add('ip/hotspot/user', params);
    }
  }

  /// Ajoute un lot de users hotspot (génération de tickets).
  Future<void> createHotspotUsers(List<Map<String, dynamic>> specs) async {
    for (final spec in specs) {
      await createHotspotUser(
        username: spec['username'] as String,
        password: spec['password'] as String,
        profile: spec['profile'] as String,
        limitUptime: spec['limitUptime'] as Duration?,
        limitBytesTotal: spec['limitBytesTotal'] as int?,
        comment: spec['comment'] as String? ?? '',
      );
    }
  }

  Future<void> deleteHotspotUser(String id) async {
    await remove('ip/hotspot/user', id);
  }

  Future<void> deleteHotspotUsersByComment(String comment) async {
    final users = await listHotspotUsers();
    for (final u in users) {
      if (u.comment == comment) {
        try {
          await remove('ip/hotspot/user', u.id);
        } on RitikException {
          // continue
        }
      }
    }
  }

  Future<void> setHotspotUserDisabled(String id, bool disabled) async {
    await set('ip/hotspot/user', {'disabled': '$disabled'}, id: id);
  }

  // ------------------------------------------------------------------
  //  Sessions actives & hosts
  // ------------------------------------------------------------------

  Future<List<ActiveSession>> listActiveSessions() async {
    final rows = await printRows('ip/hotspot/active');
    return rows.map(ActiveSession.fromRouteros).toList();
  }

  Future<List<Map<String, String>>> listHotspotHosts() async {
    return printRows('ip/hotspot/host');
  }

  // ------------------------------------------------------------------
  //  Logs système
  // ------------------------------------------------------------------

  Future<List<SystemLogEntry>> systemLogs({String? topics}) async {
    final queries = topics == null ? const <Map<String, String>>[] : [
      {'topics': topics}
    ];
    final rows =
        await printRows('log', queries: queries);
    return rows.map(SystemLogEntry.fromRouteros).toList();
  }

  // ------------------------------------------------------------------
  //  Helpers
  // ------------------------------------------------------------------

  static String formatRateLimit(int downloadKbps, int uploadKbps) {
    return '${_rate(downloadKbps)}/${_rate(uploadKbps)}';
  }

  static String _rate(int kbps) {
    if (kbps <= 0) return '0';
    if (kbps >= 1000 && kbps % 1000 == 0) {
      return '${kbps ~/ 1000}M';
    }
    return '${kbps}k';
  }

  // ------------------------------------------------------------------
  //  Test de connexion (indépendant de l'instance)
  // ------------------------------------------------------------------

  static Future<Map<String, String>> testConnection(RouterServer server) async {
    final svc = MikrotikService(server);
    try {
      await svc.connect();
      final metrics = await svc.ping();
      return {
        'ok': 'true',
        'identity': metrics.identity,
        'version': metrics.version,
        'board': metrics.boardName,
        'uptime': Formatters.humanDuration(metrics.uptime),
        'cpu': metrics.cpuLabel,
        'transport': svc.connectedLabel,
      };
    } on RitikException catch (e) {
      return {
        'ok': 'false',
        'error': e.message,
      };
    } finally {
      await svc.disconnect();
    }
  }
}