import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/app_storage.dart';

/// Authentification de l'administrateur local.
class AuthService {
  final AppStorage storage;

  AuthService(this.storage);

  static String hashPassword(String password) =>
      md5.convert(utf8.encode(password)).toString();

  bool isDefaultSetup() =>
      storage.adminHash.isEmpty || storage.adminHash == hashPassword(AppConstants.defaultAdminPass);

  Future<void> resetToDefault() async {
    await storage.setAdminCredentials(
      AppConstants.defaultAdminUser,
      hashPassword(AppConstants.defaultAdminPass),
    );
  }

  Future<AuthResult> login(String username, String password) async {
    final expectedUser = storage.adminUser;
    if (storage.adminHash.isEmpty) {
      await storage.setAdminCredentials(
        AppConstants.defaultAdminUser,
        hashPassword(AppConstants.defaultAdminPass),
      );
    }
    final ok = username == expectedUser &&
        hashPassword(password) == storage.adminHash;
    if (ok) {
      await storage.setLoggedIn(true);
      return const AuthResult.success();
    }
    return const AuthResult.failure("Nom d'utilisateur ou mot de passe incorrect.");
  }

  Future<void> changePassword({required String current, required String newPass}) async {
    if (hashPassword(current) != storage.adminHash) {
      throw const AuthException(
          'Le mot de passe actuel est incorrect. Impossible de continuer.');
    }
    await storage.setAdminCredentials(storage.adminUser, hashPassword(newPass));
  }

  Future<void> logout() async {
    await storage.setLoggedIn(false);
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.success()
      : ok = true,
        error = null;
  const AuthResult.failure(this.error) : ok = false;

  bool get isOk => ok;
}