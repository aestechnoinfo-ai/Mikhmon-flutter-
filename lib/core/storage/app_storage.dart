import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_log.dart';
import '../../models/app_settings.dart';
import '../../models/hotspot_profile.dart';
import '../../models/router_server.dart';
import '../../models/voucher.dart';
import '../constants/app_constants.dart';

/// Persistance locale multi-plateforme (mobile, desktop, web).
class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  static const _kAdminUser = 'admin_user';
  static const _kAdminHash = 'admin_hash';
  static const _kLoggedIn = 'logged_in';
  static const _kServers = 'servers';
  static const _kProfiles = 'profiles';
  static const _kVouchers = 'vouchers';
  static const _kLogs = 'logs';
  static const _kSettings = 'settings';

  SharedPreferences? _prefs;
  bool _ready = false;

  List<RouterServer> _servers = [];
  List<HotspotProfile> _profiles = [];
  List<Voucher> _vouchers = [];
  List<AppLog> _logs = [];
  AppSettings _settings = const AppSettings();

  bool get ready => _ready;

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _loadAll();
    _ready = true;
  }

  void _loadAll() {
    final p = _prefs;
    if (p == null) return;

    final serverJson = p.getString(_kServers);
    if (serverJson != null) {
      _servers = (jsonDecode(serverJson) as List)
          .map((e) => RouterServer.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final profileJson = p.getString(_kProfiles);
    if (profileJson != null) {
      _profiles = (jsonDecode(profileJson) as List)
          .map((e) => HotspotProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final voucherJson = p.getString(_kVouchers);
    if (voucherJson != null) {
      _vouchers = (jsonDecode(voucherJson) as List)
          .map((e) => Voucher.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final logJson = p.getString(_kLogs);
    if (logJson != null) {
      _logs = (jsonDecode(logJson) as List)
          .map((e) => AppLog.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final settingsJson = p.getString(_kSettings);
    if (settingsJson != null) {
      _settings = AppSettings.fromJson(
        jsonDecode(settingsJson) as Map<String, dynamic>,
      );
    }
  }

  Future<void> _saveString(String key, Object value) async {
    await _prefs?.setString(key, jsonEncode(value));
  }

  // ---------- Admin / session ----------

  String get adminUser => _prefs?.getString(_kAdminUser) ?? AppConstants.defaultAdminUser;
  String get adminHash =>
      _prefs?.getString(_kAdminHash) ?? '';
  bool get loggedIn => _prefs?.getBool(_kLoggedIn) ?? false;

  Future<void> setAdminCredentials(String user, String hash) async {
    await _prefs?.setString(_kAdminUser, user);
    await _prefs?.setString(_kAdminHash, hash);
  }

  Future<void> setLoggedIn(bool value) async {
    await _prefs?.setBool(_kLoggedIn, value);
  }

  // ---------- Serveurs ----------

  List<RouterServer> get servers => List.unmodifiable(_servers);

  RouterServer? serverById(String? id) {
    if (id == null) return null;
    for (final s in _servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> upsertServer(RouterServer server) async {
    final idx = _servers.indexWhere((s) => s.id == server.id);
    if (idx >= 0) {
      _servers[idx] = server;
    } else {
      _servers.add(server);
    }
    await _saveString(_kServers, _servers.map((s) => s.toJson()).toList());
  }

  Future<void> removeServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    _profiles.removeWhere((p) => p.serverId == id);
    await _saveString(_kServers, _servers.map((s) => s.toJson()).toList());
    await _saveString(_kProfiles, _profiles.map((p) => p.toJson()).toList());
  }

  // ---------- Profils ----------

  List<HotspotProfile> profilesForServer(String? serverId) {
    if (serverId == null) return const [];
    return _profiles.where((p) => p.serverId == serverId).toList();
  }

  List<HotspotProfile> get allProfiles => List.unmodifiable(_profiles);

  Future<void> upsertProfile(HotspotProfile profile) async {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _profiles[idx] = profile;
    } else {
      _profiles.add(profile);
    }
    await _saveString(_kProfiles, _profiles.map((p) => p.toJson()).toList());
  }

  Future<void> removeProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    await _saveString(_kProfiles, _profiles.map((p) => p.toJson()).toList());
  }

  // ---------- Vouchers ----------

  List<Voucher> get vouchers => List.unmodifiable(_vouchers);

  List<Voucher> vouchersForBatch(String batchId) =>
      _vouchers.where((v) => v.batchId == batchId).toList();

  Future<void> addVouchers(List<Voucher> vouchers) async {
    final all = [..._vouchers, ...vouchers];
    _vouchers = all.length > AppConstants.maxStoredVouchers
        ? all.sublist(all.length - AppConstants.maxStoredVouchers)
        : all;
    await _saveString(_kVouchers, _vouchers.map((v) => v.toJson()).toList());
  }

  Future<void> clearVouchers() async {
    _vouchers = [];
    await _prefs?.remove(_kVouchers);
  }

  // ---------- Logs ----------

  List<AppLog> get logs =>
      List.unmodifiable(_logs.reversed); // plus récents en premier

  Future<void> addLog(AppLog log) async {
    _logs.add(log);
    if (_logs.length > AppConstants.maxLocalLogs) {
      _logs = _logs.sublist(_logs.length - AppConstants.maxLocalLogs);
    }
    await _saveString(_kLogs, _logs.map((l) => l.toJson()).toList());
  }

  Future<void> clearLogs() async {
    _logs = [];
    await _prefs?.remove(_kLogs);
  }

  // ---------- Réglages ----------

  AppSettings get settings => _settings;

  Future<void> saveSettings(AppSettings s) async {
    _settings = s;
    await _saveString(_kSettings, s.toJson());
  }
}