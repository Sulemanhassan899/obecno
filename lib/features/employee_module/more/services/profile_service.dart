import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:Obecno/features/employee_module/more/repositories/profile_repository.dart';

/// Thin orchestration layer between [ProfileProvider] and
/// [ProfileRepository] -- kept as its own class (matching the
/// repository/service/provider split used by [AuthService] and every
/// other feature) rather than having the provider call the repository
/// directly, so any future local caching of the profile can be added here
/// without touching the UI layer.
class ProfileService {
  ProfileService(this._repository);

  final ProfileRepository _repository;

  Future<ApiResponse<EmployeeProfileModel>> getProfile() {
    return _repository.getProfile();
  }

  Future<ApiResponse<EmployeeProfileModel>> updateProfile(
    Map<String, dynamic> payload,
  ) {
    return _repository.updateProfile(payload);
  }

  Future<ApiResponse<EmployeeProfileModel>> updatePhoto({
    List<int>? photoBytes,
    String? fileName,
    bool removePhoto = false,
  }) {
    return _repository.updatePhoto(
      photoBytes: photoBytes,
      fileName: fileName,
      removePhoto: removePhoto,
    );
  }
}
