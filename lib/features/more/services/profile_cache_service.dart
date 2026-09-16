import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/more/data/models/employee_profile_model.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the signed-in user's profile JSON and photo so More still
/// shows name / avatar when the device is offline.
class ProfileCacheService {
  ProfileCacheService({FlutterSecureStorage? storage, http.Client? httpClient})
    : _storage = storage ?? const FlutterSecureStorage(),
      _http = httpClient ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _http;

  static String _profileKey(String userId) =>
      'profile_module_cached_profile_$userId';

  Future<void> cacheProfile(String userId, EmployeeProfileModel profile) async {
    if (userId.isEmpty) return;
    try {
      await _storage.write(
        key: _profileKey(userId),
        value: jsonEncode(profile.toCacheJson()),
      );
    } catch (e, st) {
      AppLogger.error('ProfileCacheService', 'cacheProfile', e, stackTrace: st);
    }
  }

  Future<EmployeeProfileModel?> getCachedProfile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final raw = await _storage.read(key: _profileKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return EmployeeProfileModel.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      AppLogger.error(
        'ProfileCacheService',
        'getCachedProfile',
        e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<File?> photoFile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final file = await _photoPath(userId);
      if (await file.exists()) return file;
    } catch (e, st) {
      AppLogger.error('ProfileCacheService', 'photoFile', e, stackTrace: st);
    }
    return null;
  }

  Future<File?> cachePhotoBytes(String userId, List<int> bytes) async {
    if (userId.isEmpty || bytes.isEmpty) return null;
    try {
      final file = await _photoPath(userId);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e, st) {
      AppLogger.error(
        'ProfileCacheService',
        'cachePhotoBytes',
        e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<File?> cachePhotoFromUrl(String userId, String? url) async {
    if (userId.isEmpty || url == null || url.trim().isEmpty) {
      return photoFile(userId);
    }
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return photoFile(userId);
      }
      final response = await _http
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return photoFile(userId);
      }
      if (response.bodyBytes.isEmpty) return photoFile(userId);
      return cachePhotoBytes(userId, response.bodyBytes);
    } catch (e, st) {
      AppLogger.error(
        'ProfileCacheService',
        'cachePhotoFromUrl',
        e,
        stackTrace: st,
      );
      return photoFile(userId);
    }
  }

  Future<void> clearForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _storage.delete(key: _profileKey(userId));
    } catch (e, st) {
      AppLogger.error('ProfileCacheService', 'clearForUser', e, stackTrace: st);
    }
    try {
      final file = await _photoPath(userId);
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      AppLogger.error(
        'ProfileCacheService',
        'clearForUser.photo',
        e,
        stackTrace: st,
      );
    }
  }

  Future<File> _photoPath(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profile_photos/$userId.jpg');
  }
}
