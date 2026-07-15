import 'package:Obecno/core/api/base_provider.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:Obecno/features/employee_module/more/services/profile_service.dart';

/// Backs [ProfileSettingsScreen] / [AccountSetting]. Extends [BaseProvider]
/// like every other feature provider in the app, so loading/error state
/// and duplicate-call guarding come for free via `safeCall`.
class ProfileProvider extends BaseProvider {
  ProfileProvider(this._service);

  final ProfileService _service;

  EmployeeProfileModel? _profile;
  EmployeeProfileModel? get profile => _profile;

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

  /// POST /api/employee/profile/photo. If the response omits the lookup
  /// lists (countries/cities/departments), [EmployeeProfileModel.copyWith]
  /// keeps the ones already loaded instead of blanking the dropdowns.
  Future<bool> updatePhoto({
    List<int>? photoBytes,
    String? fileName,
    bool removePhoto = false,
  }) {
    return safeCall<EmployeeProfileModel>(
      operationKey: 'profile_photo',
      request: (_) => _service.updatePhoto(
        photoBytes: photoBytes,
        fileName: fileName,
        removePhoto: removePhoto,
      ),
      onSuccess: (data) => _profile = _profile == null
          ? data
          : _profile!.copyWith(
              photoUrl: data.photoUrl,
              countries: data.countries,
              cities: data.cities,
              departments: data.departments,
            ),
    );
  }
}
