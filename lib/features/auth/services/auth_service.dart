import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/features/auth/data/models/auth_company_model.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/data/models/auth_user_model.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/auth/repositories/auth_repository.dart';

class AuthService {
  AuthService(this._repository, this._tokenService);

  final AuthRepository _repository;
  final TokenService _tokenService;

  // ================= CHECK EMAIL (STEP 1) =================
  Future<ApiResponse<bool>> checkEmailExists(String email) {
    return _repository.checkEmail(email);
  }

  // ================= SIGN IN (STEP 2) =================
  Future<ApiResponse<AuthUserModel>> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final response = await _repository.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );

    if (response.success && response.data != null) {
      final user = response.data!;
      await _tokenService.setRememberMe(rememberMe);
      await _tokenService.markSessionActive(userId: user.id, role: user.role);

      if (rememberMe) {
        await _tokenService.saveLastEmail(email);
      } else {
        await _tokenService.clearSavedEmail();
      }

      await _cacheEverythingFromEnvelope(user, resetSelection: true);
    }

    return response;
  }

  Future<String?> getSavedEmail() => _tokenService.lastEmail;

  Future<void> _cacheEverythingFromEnvelope(
    AuthUserModel user, {
    bool resetSelection = false,
  }) async {
    if (user.token != null) {
      await _tokenService.saveToken(user.token!);
    }

    if (user.permissions.isNotEmpty) {
      await _tokenService.cachePermissions(
        user.permissions.map((p) => p.toJson()).toList(),
      );
    }

    if (user.company != null) {
      await _tokenService.cacheCompany(user.company!.toJson());
    }

    if (user.permissionLocation != null) {
      await _tokenService.cachePermissionLocation(
        user.permissionLocation!.toJson(),
      );
    }

    if (user.locations.isEmpty) return;
    await _tokenService.cacheLocations(
      user.locations.map((l) => l.toJson()).toList(),
    );

    final existingId = await _tokenService.selectedLocationId;
    final stillValid =
        existingId != null && user.locations.any((l) => l.id == existingId);

    if (resetSelection || !stillValid) {
      await _tokenService.setSelectedLocationId(user.locations.first.id);
    }
  }

  Future<AuthCompanyModel?> getCachedCompany() async {
    final raw = await _tokenService.cachedCompany;
    return raw == null ? null : AuthCompanyModel.fromJsonOrNull(raw);
  }

  Future<AuthLocationModel?> getCachedPermissionLocation() async {
    final raw = await _tokenService.cachedPermissionLocation;
    return raw == null ? null : AuthLocationModel.fromJsonOrNull(raw);
  }

  Future<List<AuthLocationModel>> getCachedLocations() async {
    final raw = await _tokenService.cachedLocations;
    return raw.map(AuthLocationModel.fromJson).toList(growable: false);
  }

  Future<String?> getCachedSelectedLocationId() =>
      _tokenService.selectedLocationId;

  Future<void> setSelectedLocationId(String locationId) =>
      _tokenService.setSelectedLocationId(locationId);

  Future<bool> isRememberMe() => _tokenService.isRememberMe;

  Future<String?> getCachedRole() => _tokenService.userRole;

  Future<String?> getCachedUserId() => _tokenService.userId;

  Future<ApiResponse<void>> forgotPassword(String email) {
    return _repository.forgotPassword(email);
  }

  Future<ApiResponse<AuthUserModel>> getCurrentUser() async {
    final response = await _repository.getCurrentUser();

    if (response.success && response.data != null) {
      final user = response.data!;
      await _tokenService.markSessionActive(userId: user.id, role: user.role);

      await _cacheEverythingFromEnvelope(user, resetSelection: false);
    }

    return response;
  }

  Future<List<PermissionItemModel>> getCachedPermissions() async {
    final raw = await _tokenService.cachedPermissions;
    return raw.map(PermissionItemModel.fromJson).toList(growable: false);
  }

  // ================= CHANGE PASSWORD =================
  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) {
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    final remembered = await _tokenService.isRememberMe;

    await _tokenService.clearSession();

    if (!remembered) {
      await _tokenService.clearSavedEmail();
    }
  }

  Future<bool> isLoggedIn() {
    return _tokenService.isSessionActive;
  }
}
