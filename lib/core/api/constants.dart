/// Centralized app-wide constants.
/// Keep environment-specific values (base URL, timeouts) here so they are
/// never hardcoded inside the api client or repositories.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // Environment
  // ---------------------------------------------------------------------
  static const String baseUrl = String.fromEnvironment(
    'OBECNO_BASE_URL',
    defaultValue: 'https://app.obecno.com/',
  );

  // ---------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // ---------------------------------------------------------------------
  // Retry
  // ---------------------------------------------------------------------
  static const int maxRetries = 3;
  static const Duration retryBaseDelay = Duration(milliseconds: 600);

  // ---------------------------------------------------------------------
  // Storage keys
  // ---------------------------------------------------------------------
  static const String cookieDirName = 'obecno_cookies';
  static const String keySessionActive = 'session_active';
  static const String keyUserId = 'session_user_id';
  static const String keyUserRole = 'session_user_role';

  // ---------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------
  static const bool enableApiLogging = bool.fromEnvironment(
    'OBECNO_DEBUG_LOGS',
    defaultValue: true,
  );
}
