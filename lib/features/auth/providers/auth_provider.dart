import 'package:flutter/foundation.dart';
import 'package:Obecno/model/auth_user_model.dart';
import '../services/auth_service.dart';

enum AuthFlowStep { email, otp, resetPassword, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

  bool _isLoading = false;
  String? _errorMessage;
  AuthUserModel? _user;

  bool _isAuthenticated = false;
  AuthFlowStep _currentStep = AuthFlowStep.email;

  // GETTERS
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthUserModel? get user => _user;
  AuthFlowStep get currentStep => _currentStep;

  // ================= LOGIN =================
  Future<bool> login({required String email, required String password, bool rememberMe = true}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.login(email: email, password: password, rememberMe: rememberMe);

    _isLoading = false;

    if (response.success && response.data != null) {
      _user = response.data;
      _isAuthenticated = true;
      _currentStep = AuthFlowStep.authenticated;
      notifyListeners();
      return true;
    }

    _errorMessage = response.message ?? 'Login failed. Please try again.';
    notifyListeners();
    return false;
  }

  // ================= FORGOT PASSWORD =================
  Future<bool> forgotPassword(String email) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.forgotPassword(email);

    _isLoading = false;

    if (response.success) {
      _currentStep = AuthFlowStep.otp;
      notifyListeners();
      return true;
    }

    _errorMessage = response.message ?? 'Failed to send OTP.';
    notifyListeners();
    return false;
  }

  // ================= VERIFY OTP =================
  Future<bool> verifyOtp(String otp) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.verifyOtp(otp);

    _isLoading = false;

    if (response.success) {
      _currentStep = AuthFlowStep.resetPassword;
      notifyListeners();
      return true;
    }

    _errorMessage = response.message ?? 'Invalid OTP.';
    notifyListeners();
    return false;
  }

  // ================= RESET PASSWORD =================
  Future<bool> resetPassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_isLoading) return false;

    if (newPassword != confirmPassword) {
      _errorMessage = 'Passwords do not match';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.resetPassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    _isLoading = false;

    if (response.success) {
      _currentStep = AuthFlowStep.email;
      notifyListeners();
      return true;
    }

    _errorMessage = response.message ?? 'Reset failed.';
    notifyListeners();
    return false;
  }

  // ================= SESSION =================
  Future<bool> checkSession() async {
    final isRemembered = await _service.isRememberMe();
    if (!isRemembered) {
      await _service.logout();
    }
    _isAuthenticated = await _service.isLoggedIn();
    notifyListeners();
    return _isAuthenticated;
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _service.logout();

    _isAuthenticated = false;
    _user = null;
    _currentStep = AuthFlowStep.email;

    notifyListeners();
  }

  // ================= HELPERS =================
  void resetToEmailStep() {
    _currentStep = AuthFlowStep.email;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
