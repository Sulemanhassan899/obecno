
import 'package:Obecno/core/api/constants.dart';
import 'package:Obecno/core/api/cookie_service.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  TokenService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _cookieKey = 'session_cookie';

  Future<void> saveCookie(String rawCookie) async {
    if (rawCookie.isEmpty) return;
    await _storage.write(key: _cookieKey, value: rawCookie);
  }

  Future<String?> getCookie() async {
    return await _storage.read(key: _cookieKey);
  }

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

  Future<String?> get userRole =>
      _storage.read(key: AppConstants.keyUserRole);

  Future<void> markOnboardingCompleted() async {
    await _storage.write(key: 'onboarding_completed', value: 'true');
  }

  Future<bool> get isOnboardingCompleted async {
    final flag = await _storage.read(key: 'onboarding_completed');
    return flag == 'true';
  }

  Future<void> setRememberMe(bool value) async {
    await _storage.write(
        key: 'remember_me', value: value ? 'true' : 'false');
  }

  Future<bool> get isRememberMe async {
    final flag = await _storage.read(key: 'remember_me');
    return flag != 'false';
  }

  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.keySessionActive);
    await _storage.delete(key: AppConstants.keyUserId);
    await _storage.delete(key: AppConstants.keyUserRole);
    await _storage.delete(key: _cookieKey);
    await CookieService.instance.clear();
    AppLogger.info('TokenService: session cleared.');
  }

  Future<bool> tryRefreshSession() async {
    return false;
  }
}