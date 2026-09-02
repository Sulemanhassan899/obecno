import 'dart:convert';

import 'package:obecno/core/api/constants.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/data/models/token_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  TokenService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
          );

  final FlutterSecureStorage _storage;

  /// Corrupted Android Keystore / Auto Backup leftovers throw
  /// [PlatformException] (`BAD_DECRYPT`). Treat that as empty storage so a
  /// first install is not sent to login with a stack trace on screen.
  Future<String?> _read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == 'Data has been reset') return null;
      return value;
    } catch (e) {
      AppLogger.error('TokenService: read failed ($key): $e', e.toString(), StackTrace.current.toString());
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      AppLogger.error('TokenService: write failed ($key): $e', e.toString(), StackTrace.current.toString());
      try {
        await _storage.deleteAll();
        await _storage.write(key: key, value: value);
      } catch (e2) {
        AppLogger.error('TokenService: write retry failed ($key): $e2', e2.toString(), StackTrace.current.toString());
      }
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.error('TokenService: delete failed ($key): $e', e.toString(), StackTrace.current.toString());
    }
  }

  Future<void> markSessionActive({required String userId, String? role}) async {
    await _write(AppConstants.keySessionActive, 'true');
    await _write(AppConstants.keyUserId, userId);
    if (role != null) {
      await _write(AppConstants.keyUserRole, role);
    }
  }

  Future<bool> get isSessionActive async {
    final flag = await _read(AppConstants.keySessionActive);
    return flag == 'true';
  }

  Future<String?> get userId => _read(AppConstants.keyUserId);

  Future<String?> get userRole => _read(AppConstants.keyUserRole);

  Future<void> markOnboardingCompleted() async {
    await _write('onboarding_completed', 'true');
  }

  Future<bool> get isOnboardingCompleted async {
    final flag = await _read('onboarding_completed');
    return flag == 'true';
  }

  Future<void> setRememberMe(bool value) async {
    await _write('remember_me', value ? 'true' : 'false');
  }

  /// Defaults to **false** when the key is missing (user must opt in).
  Future<bool> get isRememberMe async {
    final flag = await _read('remember_me');
    return flag == 'true';
  }

  Future<void> saveLastEmail(String email) async {
    await _write(AppConstants.keySavedEmail, email);
  }

  Future<String?> get lastEmail => _read(AppConstants.keySavedEmail);

  Future<void> clearSavedEmail() async {
    await _delete(AppConstants.keySavedEmail);
  }

  Future<void> cacheCompany(Map<String, dynamic>? company) async {
    if (company == null) return;
    await _write(AppConstants.keyCompanyJson, jsonEncode(company));
  }

  Future<Map<String, dynamic>?> get cachedCompany async {
    final raw = await _read(AppConstants.keyCompanyJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheLocations(List<Map<String, dynamic>> locations) async {
    await _write(AppConstants.keyLocationsJson, jsonEncode(locations));
  }

  Future<List<Map<String, dynamic>>> get cachedLocations async {
    final raw = await _read(AppConstants.keyLocationsJson);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSelectedLocationId(String id) async {
    await _write(AppConstants.keySelectedLocationId, id);
  }

  Future<String?> get selectedLocationId =>
      _read(AppConstants.keySelectedLocationId);

  Future<void> cachePermissionLocation(Map<String, dynamic>? location) async {
    if (location == null) return;
    await _write(
      AppConstants.keyPermissionLocationJson,
      jsonEncode(location),
    );
  }

  Future<Map<String, dynamic>?> get cachedPermissionLocation async {
    final raw = await _read(AppConstants.keyPermissionLocationJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(TokenModel token) async {
    await _write(AppConstants.keyTokenJson, jsonEncode(token.toStorageJson()));
  }

  Future<TokenModel?> get accessToken async {
    final raw = await _read(AppConstants.keyTokenJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? TokenModel.fromStorageJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> get authorizationHeader async =>
      (await accessToken)?.authorizationHeader;

  Future<void> cachePermissions(List<Map<String, dynamic>> permissions) async {
    await _write(AppConstants.keyPermissionsJson, jsonEncode(permissions));
  }

  Future<List<Map<String, dynamic>>> get cachedPermissions async {
    final raw = await _read(AppConstants.keyPermissionsJson);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearSession() async {
    await _delete(AppConstants.keySessionActive);
    await _delete(AppConstants.keyUserId);
    await _delete(AppConstants.keyUserRole);
    await _delete(AppConstants.keyCompanyJson);
    await _delete(AppConstants.keyLocationsJson);
    await _delete(AppConstants.keySelectedLocationId);
    await _delete(AppConstants.keyPermissionLocationJson);
    await _delete(AppConstants.keyTokenJson);
    await _delete(AppConstants.keyPermissionsJson);
    AppLogger.info('TokenService: session cleared.');
  }

  /// Checks whether the stored access token is still usable.
  ///
  /// Full refresh-token rotation requires a backend `/auth/refresh` endpoint.
  /// Until that exists: expired tokens clear the session and return false so
  /// callers log the user out instead of sending dead credentials.
  Future<bool> tryRefreshSession() async {
    final token = await accessToken;
    if (token == null) return false;
    if (!token.isExpired) return true;
    await clearSession();
    AppLogger.info('TokenService: access token expired; session cleared.');
    return false;
  }
}
