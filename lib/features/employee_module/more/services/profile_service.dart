import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:obecno/features/employee_module/more/repositories/profile_repository.dart';

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
