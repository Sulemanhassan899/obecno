import 'package:flutter/foundation.dart';
import 'package:Obecno/core/api/base_provider.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:Obecno/features/employee_module/more/services/profile_service.dart';

class ProfileProvider extends BaseProvider {
  ProfileProvider(this._service);

  final ProfileService _service;

  EmployeeProfileModel? _profile;
  EmployeeProfileModel? get profile => _profile;

  int _photoCacheBuster = 0;
  int get photoCacheBuster => _photoCacheBuster;

  String? get displayPhotoUrl {
    final url = _profile?.photoUrl;
    if (url == null || url.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$_photoCacheBuster';
  }

  /// GET /api/employee/profile
  Future<bool> loadProfile() {
    return safeCall<EmployeeProfileModel>(
      operationKey: 'profile_load',
      request: (_) => _service.getProfile(),
      onSuccess: (data) => _profile = data,
    );
  }

  /// PUT /api/employee/profile
  Future<bool> updateProfile(Map<String, dynamic> payload) {
    return safeCall<EmployeeProfileModel>(
      operationKey: 'profile_update',
      request: (_) => _service.updateProfile(payload),
      onSuccess: (data) => _profile = data,
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
      },
    );
  }
}
