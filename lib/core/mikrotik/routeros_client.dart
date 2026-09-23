import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'codec.dart';
import 'errors.dart';
import 'packet_reader.dart';
import 'transport.dart';
import '../constants/app_constants.dart';
import '../utils/hex.dart';

/// Méthodes de login API RouterOS.
class LoginMethod {
  LoginMethod._();

  static const String auto = 'auto';
  static const String v6 = 'v6';
  static const String v7 = 'v7';
}

/// Client bas-niveau de l'API RouterOS (protocole binhex, port 8728/8729).
///
/// Compatible RouterOS **v6** (défi MD5 binaire) et **v7** (double MD5 hex).
class RouterosClient {
  TcpTransport? _t;
  ApiPacketReader? _reader;
  String? _user;
  bool _loggedIn = false;

  bool get isConnected => _t != null;

  Future<void> connect(
    String host,
    int port, {
    bool ssl = false,
  }) async {
    await disconnect();
    _t = await TcpTransport.connect(
      host,
      port,
      ssl: ssl,
      timeout: const Duration(seconds: AppConstants.connectTimeoutSeconds),
    );
    _reader = ApiPacketReader(_t!.incoming);
    await _reader!.start();
  }

  Future<void> disconnect() async {
    _loggedIn = false;
    final r = _reader;
    final t = _t;
    _reader = null;
    _t = null;
    await r?.dispose();
    if (t != null) {
      try {
        await t.send(const []); // no-op
      } catch (_) {}
    }
    if (t != null) await t.close();
  }

  /// Authentification. `method` : `auto`, `v6` ou `v7`.
  Future<void> login(
    String user,
    String password, {
    String method = LoginMethod.auto,
  }) async {
    _requireTransport();
    final done = await _raw(['/login']);
    var challenge = _attrOf(done, 'ret');
    if (challenge.isEmpty) {
      // Pas de défi → session acceptée directement.
      _loggedIn = true;
      _user = user;
      return;
    }

    if (method == LoginMethod.auto) {
      try {
        final resp = _v7Response(user, password, challenge);
        await _sendLogin(user, resp);
      } catch (e) {
        try {
          final resp = _v6Response(user, password, challenge);
          await _sendLogin(user, resp);
        } catch (e2) {
          throw RouterosException('Login refusé (v6/v7). ${_msg(e2)}');
        }
      }
    } else if (method == LoginMethod.v7) {
      final resp = _v7Response(user, password, challenge);
      await _sendLogin(user, resp);
    } else {
      final resp = _v6Response(user, password, challenge);
      await _sendLogin(user, resp);
    }
    _loggedIn = true;
    _user = user;
  }

  Future<void> _sendLogin(String user, String responseHex) async {
    await _raw(['/login', '=name=$user', '=response=$responseHex']);
  }

  /// RouterOS v6 : MD5(0x00 + password + challenge binaire) → `00<hex>`.
  String _v6Response(String user, String password, String challengeHex) {
    final chBytes = Hex.decode(challengeHex);
    final input = <int>[0, ...utf8.encode(password), ...chBytes];
    final digest = md5.convert(input);
    return '00${Hex.encode(digest.bytes)}';
  }

  /// RouterOS v7 : MD5( hex(MD5(password)) + challengeHex ) → `00<hex>`.
  String _v7Response(String user, String password, String challengeHex) {
    final firstHex = Hex.encode(md5.convert(utf8.encode(password)).bytes);
    final second = md5.convert(utf8.encode(firstHex + challengeHex));
    return '00${Hex.encode(second.bytes)}';
  }

  /// Exécute une commande et renvoie la liste des lignes `!re` (et attributs `!done`).
  ///
  /// `[path]` ex : `['/ip/hotspot/user/add']`, params : `['=name=x', '=password=y']`.
  Future<List<Map<String, String>>> execute(
    List<String> path, {
    List<String> params = const [],
    List<Map<String, String>> queries = const [],
    Map<String, String>? tag,
  }) async {
    _requireConnected();
    final words = <String>[...path];
    for (final p in params) {
      words.add(p.startsWith('=') ? p : '=$p');
    }
    for (final q in queries) {
      for (final e in q.entries) {
        words.add('?${e.key}=${e.value}');
      }
    }
    return _raw(words);
  }

  Future<List<Map<String, String>>> _raw(List<String> words) async {
    _requireTransport();
    _t!.send(ApiFrameCodec.pack(words));
    final rows = <Map<String, String>>[];
    Map<String, String>? current;

    while (true) {
      final frame = await _reader!.readFrame();
      final sents = ApiFrameCodec.decodeWords(frame);
      if (sents.isEmpty) continue;

      final type = sents.firstWhere(
        (w) => w.startsWith('!'),
        orElse: () => '',
      );

      if (type.startsWith('!trap') || type.startsWith('!fatal')) {
        throw RouterosException(_extractMessage(sents));
      }

      if (type.startsWith('!re')) {
        current = _attrsOf(sents);
        continue;
      }

      if (type.startsWith('!final')) {
        if (current != null) {
          rows.add(current);
          current = null;
        }
        continue;
      }

      if (type.startsWith('!done')) {
        if (current != null) {
          rows.add(current);
          current = null;
        }
        final doneAttrs = _attrsOf(sents);
        if (doneAttrs.isNotEmpty) {
          // Ex : `/login` → `=ret=...` ; `/…/print` → attr `.ret` court-circuites.
          if (rows.isEmpty) {
            rows.add(doneAttrs);
          } else {
            rows.last.addAll(doneAttrs);
          }
        }
        return rows;
      }
    }
  }

  static String _extractMessage(List<String> sents) {
    for (final w in sents) {
      if (w.startsWith('=message=')) return w.substring(9);
    }
    return sents.join(' ');
  }

  static Map<String, String> _attrsOf(List<String> sents) {
    final map = <String, String>{};
    for (final w in sents) {
      if (w.startsWith('=')) {
        final eq = w.indexOf('=', 1);
        final key = eq < 0 ? w.substring(1) : w.substring(1, eq);
        final value = eq < 0 ? '' : w.substring(eq + 1);
        map[key] = value;
      }
    }
    return map;
  }

  static String _attrOf(List<Map<String, String>> rows, String key) {
    for (final r in rows) {
      if (r.containsKey(key)) return r[key] ?? '';
    }
    return '';
  }

  void _requireTransport() {
    if (_t == null) {
      throw const NotConnectedException();
    }
  }

  void _requireConnected() {
    if (_t == null || _reader == null) {
      throw const NotConnectedException();
    }
  }

  static String _msg(Object e) => e.toString().replaceAll('Exception: ', '');
}