

import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/data/models/auth_user_model.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';

/// Thin orchestration layer between [AuthProvider] (UI state) and
/// [AuthRepository] (network I/O). Owns session bookkeeping via
/// [TokenService] -- [AuthRepository] never touches local storage itself.
///
/// FIXED: previously took an optional `SessionCookieStore` and cleared it
/// on [logout], a leftover from the old `HttpApiClient` flow
/// (`core/api/session_cookie_store.dart`). That store isn't what
/// [ApiClient] actually reads cookies from -- `TokenService.clearSession()`
/// already wipes the real cookie jar via `CookieService.instance.clear()`
/// -- so keeping it here was dead code that also referenced a client this
/// class no longer depends on. Removed.
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
    final response = await _repository.login(email: email, password: password, rememberMe: rememberMe);

    if (response.success && response.data != null) {
      final user = response.data!;
      await _tokenService.setRememberMe(rememberMe);
      await _tokenService.markSessionActive(userId: user.id, role: user.role);
    }

    return response;
  }

  Future<bool> isRememberMe() => _tokenService.isRememberMe;

  Future<ApiResponse<void>> forgotPassword(String email) {
    return _repository.forgotPassword(email);
  }

  // ================= CURRENT USER =================
  /// Refreshes the session user from `/api/auth/me` and re-persists the
  /// (possibly changed) role. Callers get the same [AuthUserModel] shape
  /// as [login] so it can be dropped straight into [AuthProvider]'s
  /// `_user` field.
  Future<ApiResponse<AuthUserModel>> getCurrentUser() async {
    final response = await _repository.getCurrentUser();

    if (response.success && response.data != null) {
      final user = response.data!;
      await _tokenService.markSessionActive(userId: user.id, role: user.role);
    }

    return response;
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
    await _tokenService.clearSession();
  }

  Future<bool> isLoggedIn() {
    return _tokenService.isSessionActive;
  }
}