import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:Obecno/core/services/logger.dart';

/// Immutable snapshot of the current device's identifying info, sent to the
/// backend to register/list this device.
class DeviceInfoSnapshot {
  const DeviceInfoSnapshot({
    required this.deviceId,
    required this.deviceName,
    required this.model,
    required this.manufacturer,
    required this.os,
    required this.osVersion,
    required this.sdkVersion,
    required this.platform,
    required this.appVersion,
    required this.timezone,
    required this.macAddress,
    required this.deviceDetails,
    this.uptimeSeconds,
  });

  final String deviceId;
  final String deviceName;
  final String model;
  final String manufacturer;
  final String os;
  final String osVersion;
  final String sdkVersion;
  final String platform;
  final String appVersion;
  final String timezone;
  final String macAddress;
  final String deviceDetails;
  final int? uptimeSeconds;
}

/// Collects device identity/info used by the Device Linking module.
///
/// Fix (Issue 4): `deviceId` is now a persistent UUID generated once and
/// stored in secure storage -- NOT derived from OS/hardware fields (e.g.
/// Android's `Build.ID` via device_info_plus' `androidInfo.id`, which
/// tracks the OS build and changes across OS updates). That instability
/// caused the same physical device to look "new" after an OS update and
/// register a duplicate device on every login.
class DeviceInfoService {
  DeviceInfoService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _deviceIdKey = 'device_module_persistent_device_id';

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DeviceInfoSnapshot? _cached;

  Future<String> _getOrCreatePersistentDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateUuid();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  String _generateUuid() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Collects (and caches in-memory) the current device's info. Pass
  /// [forceRefresh] to bypass the in-memory cache -- the persistent device
  /// ID itself is never regenerated once created.
  Future<DeviceInfoSnapshot> collect({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;

    final package = await PackageInfo.fromPlatform();
    final deviceId = await _getOrCreatePersistentDeviceId();

    String name = '';
    String model = '';
    String manufacturer = '';
    final String os = Platform.operatingSystem;
    String osVersion = Platform.operatingSystemVersion;
    String sdkVersion = '';
    final String platform = Platform.isAndroid ? 'android' : 'ios';

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      name = android.device;
      model = android.model;
      manufacturer = android.manufacturer;
      sdkVersion = android.version.sdkInt.toString();
      // Prefer the user-facing release (e.g. "13") over the verbose
      // Platform.operatingSystemVersion string.
      if (android.version.release.isNotEmpty) {
        osVersion = android.version.release;
      }
    } else if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      name = ios.name;
      model = ios.model;
      manufacturer = 'Apple';
      if (ios.systemVersion.isNotEmpty) {
        osVersion = ios.systemVersion;
      }
    }

    final osLabel = platform == 'ios' ? 'iOS' : 'Android';
    final displayModel = () {
      final mfg = manufacturer.trim();
      final mdl = model.trim();
      if (mfg.isEmpty) return mdl.isNotEmpty ? mdl : name;
      if (mdl.isEmpty) return mfg;
      if (mdl.toLowerCase().startsWith(mfg.toLowerCase())) return mdl;
      return '$mfg $mdl';
    }();

    final snapshot = DeviceInfoSnapshot(
      deviceId: deviceId,
      deviceName: name,
      model: model,
      manufacturer: manufacturer,
      os: os,
      osVersion: osVersion,
      sdkVersion: sdkVersion,
      platform: platform,
      appVersion: package.version,
      timezone: DateTime.now().timeZoneName,
      // Backend doesn't always echo `device_id` back -- it stores what we
      // send under `mac_address` as the device identifier instead (see
      // DeviceModel.fromJson), so send our stable ID there too.
      macAddress: deviceId,
      // Matches attendance check-in payload format, e.g. "Vivo e23 | Android 13".
      deviceDetails: '$displayModel | $osLabel $osVersion',
    );

    AppLogger.info(
      '[DeviceInfo] deviceId=$deviceId name=$name model=$model '
      'manufacturer=$manufacturer os=$os osVersion=$osVersion '
      'platform=$platform appVersion=${package.version} timezone=${snapshot.timezone}',
    );

    _cached = snapshot;
    return snapshot;
  }
}
