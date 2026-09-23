/// Constantes globales de l'application.
class AppConstants {
  AppConstants._();

  static const String appName = 'Mikhmon Flutter';
  static const String appVersion = '1.0.0';

  static const int defaultApiPort = 8728;
  static const int defaultApiSslPort = 8729;
  static const int defaultRestPort = 80;
  static const int defaultRestSslPort = 443;

  static const int connectTimeoutSeconds = 8;
  static const int commandTimeoutSeconds = 20;

  static const String defaultAdminUser = 'admin';
  static const String defaultAdminPass = 'mikhmon';

  static const int maxLocalLogs = 500;
  static const int maxStoredVouchers = 5000;
}