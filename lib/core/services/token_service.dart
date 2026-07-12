import 'package:Obecno/api/constants.dart';
import 'package:Obecno/api/cookie_service.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


/// The API is cookie-authenticated, so there is no bearer token to carry
/// around — but the app still needs a fast, synchronous-feeling way to
/// know "is someone logged in" (for splash/router redirects) and to store
/// a couple of session-scoped values (user id, role).
///
/// Kept separate from [CookieService] so that if the backend later adds
/// a bearer/refresh-token flow, that logic slots in here without touching
/// the cookie jar or the api client's interceptors.
class TokenService {
  TokenService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> markSessionActive({required String userId, String? role}) async {
    await _storage.write(key: AppConstants.keySessionActive, value: 'true');
    await _storage.write(key: AppConstants.keyUserId, value: userId);
    if (role != null) {
      await _storage.write(key: AppConstants.keyUserRole, value: role);
    }
  }

  Future<bool> get isSessionActive async {
    final flag = await _storage.read(key: AppConstants.keySessionActive);
    return flag == 'true';
  }

  Future<String?> get userId => _storage.read(key: AppConstants.keyUserId);

  Future<String?> get userRole => _storage.read(key: AppConstants.keyUserRole);

  Future<void> markOnboardingCompleted() async {
    await _storage.write(key: 'onboarding_completed', value: 'true');
  }

  Future<bool> get isOnboardingCompleted async {
    final flag = await _storage.read(key: 'onboarding_completed');
    return flag == 'true';
  }

  Future<void> setRememberMe(bool value) async {
    await _storage.write(key: 'remember_me', value: value ? 'true' : 'false');
  }

  Future<bool> get isRememberMe async {
    final flag = await _storage.read(key: 'remember_me');
    return flag != 'false'; // Defaults to true if not set
  }

  /// Called by the auth interceptor on a 401, and by the explicit
  /// logout flow. Clears both the secure-storage flags and the cookie jar
  /// so no stale session data lingers on the device.
  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.keySessionActive);
    await _storage.delete(key: AppConstants.keyUserId);
    await _storage.delete(key: AppConstants.keyUserRole);
    await CookieService.instance.clear();
    AppLogger.info('TokenService: session cleared.');
  }

  // -----------------------------------------------------------------
  // Future-ready hook: if the backend adds refresh tokens later, wire
  // the refresh call here and have AuthInterceptor call it on 401
  // before falling back to clearSession().
  // -----------------------------------------------------------------
  Future<bool> tryRefreshSession() async {
    // Not supported by the current cookie-session backend.
    // Placeholder kept so AuthInterceptor's call site doesn't change
    // when refresh support is added.
    return false;
  }
}
