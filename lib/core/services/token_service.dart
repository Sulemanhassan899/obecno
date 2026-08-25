import 'dart:convert';

import 'package:obecno/core/api/constants.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/data/models/token_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  TokenService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

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

  /// Defaults to **false** when the key is missing (user must opt in).
  Future<bool> get isRememberMe async {
    final flag = await _storage.read(key: 'remember_me');
    return flag == 'true';
  }

  Future<void> saveLastEmail(String email) async {
    await _storage.write(key: AppConstants.keySavedEmail, value: email);
  }

  Future<String?> get lastEmail =>
      _storage.read(key: AppConstants.keySavedEmail);

  Future<void> clearSavedEmail() async {
    await _storage.delete(key: AppConstants.keySavedEmail);
  }

  Future<void> cacheCompany(Map<String, dynamic>? company) async {
    if (company == null) return;
    await _storage.write(
      key: AppConstants.keyCompanyJson,
      value: jsonEncode(company),
    );
  }

  Future<Map<String, dynamic>?> get cachedCompany async {
    final raw = await _storage.read(key: AppConstants.keyCompanyJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheLocations(List<Map<String, dynamic>> locations) async {
    await _storage.write(
      key: AppConstants.keyLocationsJson,
      value: jsonEncode(locations),
    );
  }

  Future<List<Map<String, dynamic>>> get cachedLocations async {
    final raw = await _storage.read(key: AppConstants.keyLocationsJson);
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
    await _storage.write(key: AppConstants.keySelectedLocationId, value: id);
  }

  Future<String?> get selectedLocationId =>
      _storage.read(key: AppConstants.keySelectedLocationId);

  Future<void> cachePermissionLocation(Map<String, dynamic>? location) async {
    if (location == null) return;
    await _storage.write(
      key: AppConstants.keyPermissionLocationJson,
      value: jsonEncode(location),
    );
  }

  Future<Map<String, dynamic>?> get cachedPermissionLocation async {
    final raw = await _storage.read(
      key: AppConstants.keyPermissionLocationJson,
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(TokenModel token) async {
    await _storage.write(
      key: AppConstants.keyTokenJson,
      value: jsonEncode(token.toStorageJson()),
    );
  }

  Future<TokenModel?> get accessToken async {
    final raw = await _storage.read(key: AppConstants.keyTokenJson);
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
    await _storage.write(
      key: AppConstants.keyPermissionsJson,
      value: jsonEncode(permissions),
    );
  }

  Future<List<Map<String, dynamic>>> get cachedPermissions async {
    final raw = await _storage.read(key: AppConstants.keyPermissionsJson);
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
    await _storage.delete(key: AppConstants.keySessionActive);
    await _storage.delete(key: AppConstants.keyUserId);
    await _storage.delete(key: AppConstants.keyUserRole);
    await _storage.delete(key: AppConstants.keyCompanyJson);
    await _storage.delete(key: AppConstants.keyLocationsJson);
    await _storage.delete(key: AppConstants.keySelectedLocationId);
    await _storage.delete(key: AppConstants.keyPermissionLocationJson);
    await _storage.delete(key: AppConstants.keyTokenJson);
    await _storage.delete(key: AppConstants.keyPermissionsJson);
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
