class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // Environment
  // ---------------------------------------------------------------------
  static const String baseUrl = String.fromEnvironment(
    'OBECNO_BASE_URL',
    defaultValue: 'https://app.obecno.com/',
  );

static const String apiVersion = String.fromEnvironment(
  'OBECNO_API_VERSION',
  defaultValue: '/api/v1', 
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
  static const int maxRetries = 5;
  static const Duration retryBaseDelay = Duration(milliseconds: 500);

  // ---------------------------------------------------------------------
  // Storage keys
  // ---------------------------------------------------------------------
  static const String keySessionActive = 'session_active';
  static const String keyUserId = 'session_user_id';
  static const String keyUserRole = 'session_user_role';

  static const String keySavedEmail = 'saved_login_email';

  static const String keyCompanyJson = 'session_company_json';
  static const String keyLocationsJson = 'session_locations_json';
  static const String keySelectedLocationId = 'session_selected_location_id';

  static const String keyPermissionLocationJson =
      'session_permission_location_json';

  static const String keyTokenJson = 'session_token_json';
  static const String keyPermissionsJson = 'session_permissions_json';

  /// Off in release. Enable only with:
  /// `--dart-define=OBECNO_DEBUG_LOGS=true`
  static const bool enableApiLogging = bool.fromEnvironment(
    'OBECNO_DEBUG_LOGS',
    defaultValue: false,
  );
}
