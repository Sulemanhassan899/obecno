import 'package:Obecno/api/api_response.dart';
import 'package:Obecno/api/session_cookie_store.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';
import 'package:Obecno/model/auth_user_model.dart';

class AuthService {
  AuthService(
    this._repository,
    this._tokenService, {
    SessionCookieStore? cookieStore,
  }) : _cookieStore = cookieStore ?? SessionCookieStore();

  final AuthRepository _repository;
  final TokenService _tokenService;
  final SessionCookieStore _cookieStore;

  // ================= LOGIN =================
  Future<ApiResponse<AuthUserModel>> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final response = await _repository.login(email: email, password: password);

    if (response.success && response.data != null) {
      final user = response.data!;
      await _tokenService.setRememberMe(rememberMe);
      await _tokenService.markSessionActive(userId: user.id, role: user.role);
    }

    return response;
  }

  Future<bool> isRememberMe() async {
    return await _tokenService.isRememberMe;
  }
  // ✅ NO STRUCTURE CHANGE — ONLY SAFE RETURN HANDLING

  Future<ApiResponse<void>> forgotPassword(String email) async {
    final res = await _repository.forgotPassword(email);
    return res;
  }

  Future<ApiResponse<void>> verifyOtp(String otp) async {
    final res = await _repository.verifyOtp(otp);
    return res;
  }

  Future<ApiResponse<void>> resetPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await _repository.resetPassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    return res;
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _tokenService.clearSession();
    await _cookieStore.clear();
  }

  Future<bool> isLoggedIn() async {
    return await _tokenService.isSessionActive;
  }
}
