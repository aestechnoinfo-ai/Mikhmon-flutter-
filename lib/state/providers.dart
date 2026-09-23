import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/mikrotik/mikrotik_service.dart';
import '../core/storage/app_storage.dart';
import '../models/app_settings.dart';
import '../models/hotspot_profile.dart';
import '../models/remote_entities.dart';
import '../models/router_server.dart';
import '../models/voucher.dart';
import '../services/voucher_generator.dart';
import '../core/utils/uid.dart';

/// Métriques du tableau de bord.
class MetricsProvider extends ChangeNotifier {
  RouterMetrics? metrics;
  Map<String, String>? identity;
  bool loading = false;
  String? error;

  int totalUsers = -1;
  int activeSessions = -1;

  Future<void> refresh(MikrotikService service) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      metrics = await service.fetchMetrics();
      identity = await service.fetchIdentity();
      totalUsers = await service.countHotspotUsers();
      activeSessions = (await service.listActiveSessions()).length;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

enum BillingFilter { all, online, expired, disabled, pool, trial }

extension BillingFilterX on BillingFilter {
  String get label {
    switch (this) {
      case BillingFilter.all:
        return 'Tous';
      case BillingFilter.online:
        return 'En ligne';
      case BillingFilter.expired:
        return 'Expirés';
      case BillingFilter.disabled:
        return 'Désactivés';
      case BillingFilter.pool:
        return 'Pool';
      case BillingFilter.trial:
        return 'Trial / Personal';
    }
  }
}

/// Liste des users hotspot du serveur courant.
class BillingProvider extends ChangeNotifier {
  List<RemoteHotspotUser> users = [];
  List<ActiveSession> sessions = [];
  bool loading = false;
  String? error;

  void _setLoading(bool v) {
    loading = v;
    notifyListeners();
  }

  Future<void> refresh(MikrotikService service) async {
    _setLoading(true);
    error = null;
    try {
      final results = await Future.wait([
        service.listHotspotUsers(),
        service.listActiveSessions(),
      ]);
      users = results[0] as List<RemoteHotspotUser>;
      sessions = results[1] as List<ActiveSession>;
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Set<String> get onlineUserNames => sessions.map((s) => s.user).toSet();

  List<RemoteHotspotUser> filter(BillingFilter f) {
    final online = onlineUserNames;
    final list = switch (f) {
      BillingFilter.all => users,
      BillingFilter.online =>
        users.where((u) => online.contains(u.name)).toList(),
      BillingFilter.expired => users
          .where((u) =>
              u.limitDuration.inSeconds > 0 &&
              _isExpired(u, online))
          .toList(),
      BillingFilter.disabled => users.where((u) => u.disabled).toList(),
      BillingFilter.pool => users
          .where((u) =>
              u.profile.toLowerCase().contains('pool') ||
              u.comment.toLowerCase().contains('pool'))
          .toList(),
      BillingFilter.trial => users
          .where((u) =>
              u.profile.toLowerCase().contains('trial') ||
              u.comment.toLowerCase().contains('trial') ||
              u.profile.toLowerCase().contains('personal'))
          .toList(),
    };
    return list;
  }

  static bool _isExpired(RemoteHotspotUser u, Set<String> online) {
    // Expiré = durée de session atteinte sans être connecté, ou user inactif.
    if (u.disabled) return false;
    if (online.contains(u.name)) return false;
    // On considère expirés les users dont la durée est épuisée selon le
    // compteur "expires-after" renseigné par le routeur.
    final exp = u.expiration;
    if (exp != null && exp.isNotEmpty) {
      final parts = exp.split(' ');
      if (parts.length > 1) {
        final suffix = parts[1];
        if (suffix.startsWith('0') && parts[0].toLowerCase() != 'never') {
          return true;
        }
      }
    }
    return false;
  }
}

/// Suivi des sessions actives avec rafraîchissement périodique.
class MonitorProvider extends ChangeNotifier {
  List<ActiveSession> sessions = [];
  bool running = false;
  bool loading = false;
  String? error;
  Duration period = const Duration(seconds: 5);
  Timer? _timer;
  int _tick = 0;
  int get tick => _tick;

  int get onlineCount => sessions.length;

  Future<void> refresh(MikrotikService service) async {
    loading = true;
    try {
      sessions = await service.listActiveSessions();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      _tick++;
      loading = false;
      notifyListeners();
    }
  }

  void start(MikrotikService service, {Duration? period}) {
    stop();
    this.period = period ?? this.period;
    running = true;
    notifyListeners();
    _runOnce(service);
    _timer = Timer.periodic(this.period, (_) => _runOnce(service));
  }

  Future<void> _runOnce(MikrotikService s) async {
    await refresh(s);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Profils hotspot : miroir local + présence côté routeur.
class ProfilesProvider extends ChangeNotifier {
  List<RemoteHotspotProfile> remoteProfiles = [];
  bool loadingRemote = false;
  String? error;

  List<HotspotProfile> localFor(String? serverId) => serverId == null
      ? const []
      : _local.where((p) => p.serverId == serverId).toList();

  List<HotspotProfile> _local = [];

  void cacheLocal(List<HotspotProfile> profiles) {
    _local = profiles;
    notifyListeners();
  }

  Future<void> loadRemote(MikrotikService service) async {
    loadingRemote = true;
    error = null;
    notifyListeners();
    try {
      remoteProfiles = await service.listHotspotProfiles();
    } catch (e) {
      error = e.toString();
    } finally {
      loadingRemote = false;
      notifyListeners();
    }
  }
}

/// Résultat de génération de vouchers.
class GenerateResult {
  final bool ok;
  final String message;
  final List<Voucher> vouchers;
  final String batchId;
  final int created;

  const GenerateResult({
    this.ok = true,
    this.message = '',
    this.vouchers = const [],
    this.batchId = '',
    this.created = 0,
  });

  static GenerateResult fail(String msg) => GenerateResult(
        ok: false,
        message: msg,
      );
}

/// Génération de vouchers, avec progression.
class VouchersProvider extends ChangeNotifier {
  final AppStorage storage;
  VouchersProvider(this.storage);

  bool generating = false;
  double progress = 0;
  int done = 0;
  int total = 0;
  String? error;

  final List<Voucher> _lastVouchers = [];
  List<Voucher> get lastVouchers => List.unmodifiable(_lastVouchers);

  Future<void> generate({
    required RouterServer server,
    required HotspotProfile profile,
    required int count,
    required AppSettings settings,
    required MikrotikService service,
  }) async {
    if (generating) return;
    generating = true;
    _lastVouchers.clear();
    progress = 0;
    done = 0;
    total = count;
    error = null;
    notifyListeners();

    final batchId = generateUid();
    bool failed = false;
    int created = 0;

    try {
      // Évite les collisions avec les users existants sur le routeur.
      final existing = await service.listHotspotUsers();
      final used = existing.map((u) => u.name).toSet();

      final generator = VoucherGenerator(
        settings: settings,
        existingUsernames: used,
      );
      final pairs = generator.generateBatch(count);
      used.addAll(pairs.map((p) => p.username));

      final validity = profile.validityLabel;
      final duration = Duration(seconds: profile.uptimeSeconds);
      // Quota volumétrique éventuel : débit (kbps) × durée.
      final rateBps = profile.downloadKbps * 1024 ~/ 8;
      final quotaBytes =
          profile.downloadKbps > 0 ? rateBps * duration.inSeconds : 0;

      for (var i = 0; i < pairs.length; i++) {
        final pair = pairs[i];
        final code = pair.username;
        try {
          await service.createHotspotUser(
            username: pair.username,
            password: pair.password,
            profile: profile.name,
            limitUptime: duration,
            limitBytesTotal: quotaBytes > 0 ? quotaBytes : 0,
            comment: code,
          );
          created++;
        } on Exception catch (e) {
          error = 'User "${pair.username}" : $e';
          failed = true;
          break;
        }
        _lastVouchers.add(
          Voucher(
            id: generateUid(),
            serverId: server.id,
            profileName: profile.name,
            username: pair.username,
            password: pair.password,
            code: code,
            price: profile.price,
            currencySymbol: settings.currencySymbol,
            validityLabel: validity,
            batchId: batchId,
            createdAt: DateTime.now(),
          ),
        );
        done = i + 1;
        progress = count == 0 ? 1 : done / count;
        notifyListeners();
      }

      if (!failed) {
        await storage.addVouchers(_lastVouchers);
      }
    } catch (e) {
      error = e.toString();
      failed = true;
    } finally {
      generating = false;
      notifyListeners();
      final result = GenerateResult(
        ok: !failed && created > 0,
        message: !failed
            ? '$created voucher(s) créé(s) sur le hotspot.'
            : (error ?? 'Génération interrompue.'),
        vouchers: _lastVouchers,
        batchId: batchId,
        created: created,
      );
      _lastResult = result;
    }
  }

  GenerateResult? _lastResult;
  GenerateResult? get lastResult => _lastResult;

  void acknowledgeResult() {
    _lastResult = null;
    notifyListeners();
  }
}

/// Historique des vouchers persistés (rafraîchi depuis le stockage).
class VoucherHistory extends ChangeNotifier {
  final List<Voucher> items;
  VoucherHistory(this.items);

  void reload(List<Voucher> all) {
    items
      ..clear()
      ..addAll(all);
    notifyListeners();
  }
}