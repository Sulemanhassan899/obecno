import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/more/data/models/employee_profile_model.dart';
import 'package:obecno/features/more/services/profile_cache_service.dart';
import 'package:obecno/features/more/services/profile_service.dart';

class ProfileProvider extends BaseProvider {
  ProfileProvider(
    this._service, {
    ProfileCacheService? cache,
    String? Function()? userIdProvider,
  }) : _cache = cache ?? ProfileCacheService(),
       _userIdProvider = userIdProvider;

  final ProfileService _service;
  final ProfileCacheService _cache;
  final String? Function()? _userIdProvider;

  EmployeeProfileModel? _profile;
  EmployeeProfileModel? get profile => _profile;

  File? _localPhoto;
  File? get localPhotoFile {
    final file = _localPhoto;
    if (file == null) return null;
    return file.existsSync() ? file : null;
  }

  int _photoCacheBuster = 0;
  int get photoCacheBuster => _photoCacheBuster;

  String? get displayPhotoUrl {
    final url = _profile?.photoUrl;
    if (url == null || url.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$_photoCacheBuster';
  }

  String? get _userId => _userIdProvider?.call();

  /// GET /api/employee/profile
  Future<bool> loadProfile() async {
    await _hydrateFromCache();
    final ok = await safeCall<EmployeeProfileModel>(
      operationKey: 'profile_load',
      request: (_) => _service.getProfile(),
      onSuccess: (data) {
        _profile = data;
        unawaited(_persist(data));
      },
    );
    if (!ok && _profile != null) {
      // Keep the cached profile visible; don't treat this as an empty error.
      resetViewState();
      notifyListeners();
      return true;
    }
    return ok;
  }

  /// PUT /api/employee/profile
  Future<bool> updateProfile(Map<String, dynamic> payload) {
    return safeCall<EmployeeProfileModel>(
      operationKey: 'profile_update',
      request: (_) => _service.updateProfile(payload),
      onSuccess: (data) {
        _profile = data;
        unawaited(_persist(data));
      },
    );
  }

  /// constructor instead.
  Future<bool> updatePhoto({
    List<int>? photoBytes,
    String? fileName,
    bool removePhoto = false,
  }) {
    debugPrint(
      '[ProfileProvider] updatePhoto() called -> hitting '
      'POST /api/employee/profile/photo '
      '(fileName: $fileName, bytes: ${photoBytes?.length}, removePhoto: $removePhoto)',
    );

    final userId = _userId;
    if (userId != null && photoBytes != null && photoBytes.isNotEmpty) {
      unawaited(
        _cache.cachePhotoBytes(userId, photoBytes).then((file) {
          _localPhoto = file;
          notifyListeners();
        }),
      );
    }

    return safeCall<EmployeeProfileModel>(
      operationKey: 'profile_photo',
      request: (_) => _service.updatePhoto(
        photoBytes: photoBytes,
        fileName: fileName,
        removePhoto: removePhoto,
      ),
      onSuccess: (data) {
        final current = _profile;
        _profile = current == null
            ? data
            : EmployeeProfileModel(
                id: current.id,
                name: current.name,
                email: current.email,
                phone: current.phone,
                photoUrl: data.photoUrl,
                designation: current.designation,
                employeeCode: current.employeeCode,
                address: current.address,
                countryId: current.countryId,
                cityId: current.cityId,
                departmentId: current.departmentId,
                department: current.department,
                countries: data.countries.isNotEmpty
                    ? data.countries
                    : current.countries,
                cities: data.cities.isNotEmpty ? data.cities : current.cities,
                departments: data.departments.isNotEmpty
                    ? data.departments
                    : current.departments,
                profileFields: current.profileFields,
              );

        _photoCacheBuster++;
        debugPrint(
          '[ProfileProvider] updatePhoto() succeeded -> new photoUrl: '
          '${_profile?.photoUrl} (cacheBuster: $_photoCacheBuster)',
        );
        unawaited(_persist(_profile!));
      },
    );
  }

  Future<void> clearLocal({String? userId}) async {
    final id = userId ?? _userId;
    _profile = null;
    _localPhoto = null;
    _photoCacheBuster = 0;
    resetViewState();
    if (id != null && id.isNotEmpty) {
      await _cache.clearForUser(id);
    }
    notifyListeners();
  }

  Future<void> _hydrateFromCache() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    if (_profile == null) {
      final cached = await _cache.getCachedProfile(userId);
      if (cached != null) _profile = cached;
    }
    _localPhoto = await _cache.photoFile(userId);
    if (_profile != null || _localPhoto != null) notifyListeners();
  }

  Future<void> _persist(EmployeeProfileModel profile) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    await _cache.cacheProfile(userId, profile);
    final photo = await _cache.cachePhotoFromUrl(userId, profile.photoUrl);
    if (photo != null) _localPhoto = photo;
    notifyListeners();
  }
}
