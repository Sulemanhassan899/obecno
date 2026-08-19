import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/features/employee_module/more/data/models/device_model.dart';

/// Local persistence for the linked-devices list, so the Linked Devices
/// screen has something to show when offline or when the API call fails.
///
/// Owns its own storage key (independent of `TokenService`), and is wiped
/// on logout the same way the other feature caches (terms/privacy) are --
/// see `AppBindings.registerLogoutCleanup`.
class DeviceCacheService {
  DeviceCacheService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _devicesKey = 'device_module_cached_devices';

  final FlutterSecureStorage _storage;

  Future<void> cacheDevices(List<DeviceModel> devices) async {
    try {
      // De-duplicate by deviceId before persisting, so a repeated fetch
      // (or a register-then-fetch race) can never write duplicate entries
      // into the cache.
      final seen = <String>{};
      final deduped = <DeviceModel>[];
      for (final device in devices) {
        final key = device.deviceId.isNotEmpty ? device.deviceId : device.id;
        if (key.isEmpty || seen.add(key)) {
          deduped.add(device);
        }
      }

      final payload = jsonEncode(
        deduped
            .map(
              (d) => {
                ...d.toJson(),
                'id': d.id,
                'last_active': d.lastActive?.toIso8601String(),
                'is_current': d.isCurrent,
                'status': d.status,
              },
            )
            .toList(growable: false),
      );
      await _storage.write(key: _devicesKey, value: payload);
    } catch (e, st) {
      // Caching is a convenience, not a correctness requirement -- a
      // failure here must never surface as a device-fetch failure.
      AppLogger.error('DeviceCacheService', 'cacheDevices', e, stackTrace: st);
    }
  }

  Future<List<DeviceModel>> getCachedDevices() async {
    try {
      final raw = await _storage.read(key: _devicesKey);
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DeviceModel.fromJson)
          .toList(growable: false);
    } catch (e, st) {
      AppLogger.error('DeviceCacheService', 'getCachedDevices', e, stackTrace: st);
      return const [];
    }
  }

  Future<void> clearCache() async {
    try {
      await _storage.delete(key: _devicesKey);
    } catch (e, st) {
      AppLogger.error('DeviceCacheService', 'clearCache', e, stackTrace: st);
    }
  }
}
