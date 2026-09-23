import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'errors.dart';

/// Abstraction de la connexion TCP/TLS pour l'API RouterOS.
abstract class ApiTransport {
  Stream<List<int>> get incoming;
  void send(List<int> data);
  Future<void> close();
}

class TcpTransport implements ApiTransport {
  final dynamic _socket;

  TcpTransport._(this._socket);

  static Future<TcpTransport> connect(
    String host,
    int port, {
    bool ssl = false,
    Duration? timeout,
  }) async {
    if (kIsWeb) {
      throw const RouterosException(
        "L'API RouterOS (socket) n'est pas disponible sur le Web. "
        'Activez le transport REST pour ce serveur.',
      );
    }
    try {
      final sock = ssl
          ? await SecureSocket.connect(host, port, timeout: timeout)
          : await Socket.connect(host, port, timeout: timeout);
      return TcpTransport._(sock);
    } on SocketException catch (e) {
      throw RouterosException('Connexion impossible ${host}:$port — ${e.message}');
    }
  }

  @override
  Stream<List<int>> get incoming => _socket as Stream<List<int>>;

  @override
  void send(List<int> data) {
    try {
      (_socket as dynamic).add(data);
    } catch (_) {
      // socket fermée
    }
  }

  @override
  Future<void> close() async {
    try {
      await (_socket as dynamic).close();
    } catch (_) {}
  }
}