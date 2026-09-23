import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'errors.dart';
import '../utils/hex.dart';

/// Client REST MikroTik (RouterOS v7). Login par défi, session via cookie
/// `-routeros`, avec fallback Basic-Auth. Utilisé sur le Web et en secours.
class RestClient {
  final String host;
  final int port;
  final bool useSsl;
  final String username;
  final String password;

  final http.Client _http = http.Client();
  Map<String, String> _cookies = {};
  bool _basicFallback = false;

  RestClient({
    required this.host,
    required this.port,
    this.useSsl = true,
    required this.username,
    required this.password,
  });

  Uri _uri(String restPath, [Map<String, String>? query]) {
    final scheme = useSsl ? 'https' : 'http';
    final segments = <String>[
      'rest',
      ...restPath
          .split('/')
          .where((s) => s.isNotEmpty),
    ];
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      pathSegments: segments,
      queryParameters: query,
    );
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['content-type'] = 'application/json';
    if (_cookies.isNotEmpty) {
      h['cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    if (_basicFallback) {
      h['authorization'] =
          'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    }
    return h;
  }

  Future<void> login() async {
    if (_basicFallback) return;
    try {
      final r1 = await _http.get(_uri('login')).timeout(
            const Duration(seconds: 12),
          );
      if (r1.statusCode >= 400) {
        _basicFallback = true;
        return;
      }
      final body = utf8.decode(r1.bodyBytes);
      final Object? decoded = body.isEmpty ? null : jsonDecode(body);
      final challenge = (decoded is Map) ? decoded['ret'] as String? : null;
      if (challenge == null || challenge.isEmpty) {
        _basicFallback = true;
        return;
      }
      final firstHex = Hex.encode(md5.convert(utf8.encode(password)).bytes);
      final second = md5.convert(utf8.encode(firstHex + challenge));
      final response = '00${Hex.encode(second.bytes)}';

      final r2 = await _http.post(
        _uri('login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'name': username, 'password': response}),
      ).timeout(const Duration(seconds: 12));

      if (r2.statusCode >= 400 && r2.statusCode != 205) {
        _basicFallback = true;
        return;
      }
      final sc = r2.headers['set-cookie'] ?? r2.headers['Set-Cookie'];
      if (sc != null) {
        _cookies = _parseCookies(sc);
      } else {
        // Version sans cookie : chaque requête doit renvoyer le password en Basic.
        _cookies = {};
        _basicFallback = true;
      }
    } catch (_) {
      _basicFallback = true;
    }
  }

  static Map<String, String> _parseCookies(String header) {
    final out = <String, String>{};
    for (final part in header.split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        final k = part.substring(0, eq).trim();
        final v = part.substring(eq + 1).trim();
        if (k == '-routeros') out[k] = v;
      }
    }
    return out;
  }

  /// Envoie une requête REST. `path` sans `/rest/`, ex : `ip/hotspot/user`.
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = _headers();
    http.Response resp;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          resp = await _http.get(uri, headers: headers);
          break;
        case 'POST':
          resp = await _http.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
          break;
        case 'PUT':
          resp = await _http.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
          break;
        case 'PATCH':
          resp = await _http.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
          break;
        default:
          resp = await _http.delete(uri, headers: headers);
      }
    } on Exception catch (e) {
      throw RestException('Requête REST échouée : $e');
    }

    if (resp.statusCode >= 400) {
      var msg = utf8.decode(resp.bodyBytes, allowMalformed: true);
      if (msg.length > 400) msg = msg.substring(0, 400);
      throw RestException('REST ${resp.statusCode} : $msg');
    }
    if (resp.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  Future<void> close() async {
    _http.close();
  }
}