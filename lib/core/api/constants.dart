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
  /// GET-only network retries (see [RetryPolicy]). Keep low to avoid storms.
  static const int maxRetries = 3;
  static const Duration retryBaseDelay = Duration(milliseconds: 500);

  /// When true, manager leave list/review also tries legacy `/manager/leaves*`
  /// if `team-leaves` returns empty/fails. Prefer leaving this off once the
  /// backend contract is stable.
  static const bool useLegacyLeavePaths = bool.fromEnvironment(
    'OBECNO_LEGACY_LEAVE_PATHS',
    defaultValue: false,
  );

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
  static const String keyPermissionsSetupCompleted =
      'permissions_setup_completed';
  static const String keyOnboardingCompleted = 'onboarding_completed';

  /// Off in release. Enable only with:
  /// `--dart-define=OBECNO_DEBUG_LOGS=true`
  static const bool enableApiLogging = bool.fromEnvironment(
    'OBECNO_DEBUG_LOGS',
    defaultValue: false,
  );
}
