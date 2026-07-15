

// import 'package:flutter/foundation.dart';
// import 'package:Obecno/features/auth/data/models/auth_user_model.dart';
// import '../services/auth_service.dart';
// import 'package:Obecno/core/services/logger.dart';

// enum AuthFlowStep { email, otp, resetPassword, authenticated }

// /// Where the user should land after authentication, derived purely from
// /// `role` (no separate role-selection screen in the flow anymore).
// enum AuthHomeTarget { employee, manager }

// class AuthProvider extends ChangeNotifier {
//   AuthProvider(this._service);

//   final AuthService _service;

//   bool _isLoading = false;
//   String? _errorMessage;
//   AuthUserModel? _user;

//   bool _isAuthenticated = false;
//   AuthFlowStep _currentStep = AuthFlowStep.email;

//   String? _pendingEmail;

//   /// Role restored from persisted session on app restart (checkSession),
//   /// used only when there's no fresh [_user] from a just-completed login.
//   String? _restoredRole;

//   bool _isForgotPasswordLoading = false;
//   String? _forgotPasswordMessage;

//   bool get isAuthenticated => _isAuthenticated;
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   AuthUserModel? get user => _user;
//   AuthFlowStep get currentStep => _currentStep;
//   String? get pendingEmail => _pendingEmail;

//   bool get isForgotPasswordLoading => _isForgotPasswordLoading;
//   String? get forgotPasswordMessage => _forgotPasswordMessage;

//   /// Single source of truth for role -- prefers the freshly logged-in
//   /// user's role, falls back to the role restored from storage on app
//   /// restart (see [checkSession]).
//   String? get role => _user?.role ?? _restoredRole;

//   /// Role-based navigation target (data.user.role → screen). Any role
//   /// other than "manager" is treated as "employee" -- no fallback to a
//   /// role-selection screen.
//   AuthHomeTarget get homeTarget =>
//       role == 'manager' ? AuthHomeTarget.manager : AuthHomeTarget.employee;

//   Future<bool> checkEmail(String email) async {
//     if (_isLoading) return false;

//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     final response = await _service.checkEmailExists(email);

//     _isLoading = false;

//     if (response.success && response.data == true) {
//       _pendingEmail = email;
//       notifyListeners();
//       return true;
//     }

//     _errorMessage = response.success
//         ? 'No account found with this email.'
//         : (response.message ?? 'Failed to verify email.');
//     notifyListeners();
//     return false;
//   }

//   Future<bool> loginWithPassword(
//     String password, {
//     bool rememberMe = true,
//   }) async {
//     if (_isLoading) return false;

//     final email = _pendingEmail;
//     if (email == null || email.isEmpty) {
//       _errorMessage = 'Please enter your email again.';
//       notifyListeners();
//       return false;
//     }

//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     final response = await _service.login(
//       email: email,
//       password: password,
//       rememberMe: rememberMe,
//     );

//     // ✅ DEBUG LOGGING (LOGIN ONLY)
//     if (kDebugMode) {
//       AppLogger.info('[LOGIN EMAIL] $email');
//       AppLogger.info('[LOGIN PASSWORD] $password');
//       AppLogger.info('[LOGIN RESPONSE] ${response.data}');
//     }

//     _isLoading = false;

//     if (response.success && response.data != null) {
//       _user = response.data;
//       _isAuthenticated = true;
//       _currentStep = AuthFlowStep.authenticated;

//       // Role now lives on `_user.role` (see `role`/`homeTarget` getters
//       // above) -- the actual screen it maps to is decided by whoever
//       // reads `homeTarget`, not here. No role-selection screen involved.
//       if (kDebugMode) {
//         AppLogger.info('[ROLE] $role');
//       }

//       notifyListeners();
//       return true;
//     }

//     _errorMessage = response.message ?? 'Login failed. Please try again.';
//     notifyListeners();
//     return false;
//   }

//   Future<bool> checkSession() async {
//     final isRemembered = await _service.isRememberMe();
//     if (!isRemembered) {
//       await _service.logout();
//     }
//     _isAuthenticated = await _service.isLoggedIn();
//     notifyListeners();
//     return _isAuthenticated;
//   }

//   Future<void> logout() async {
//     await _service.logout();

//     _isAuthenticated = false;
//     _user = null;
//     _restoredRole = null;
//     _pendingEmail = null;
//     _currentStep = AuthFlowStep.email;

//     notifyListeners();
//   }

//   // ================= FORGOT PASSWORD =================
//   static final RegExp _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

//   /// Validates then submits the forgot-password request. Returns true
//   /// only on a confirmed-success API response; [forgotPasswordMessage]
//   /// always carries the message to show (success text on true, the
//   /// field-level/general error on false).
//   Future<bool> forgotPassword(String email) async {
//     if (_isForgotPasswordLoading) return false;

//     final trimmedEmail = email.trim();

//     if (trimmedEmail.isEmpty) {
//       _forgotPasswordMessage = 'Email is required.';
//       notifyListeners();
//       return false;
//     }

//     if (!_emailRegex.hasMatch(trimmedEmail)) {
//       _forgotPasswordMessage = 'Enter a valid email.';
//       notifyListeners();
//       return false;
//     }

//     _isForgotPasswordLoading = true;
//     _forgotPasswordMessage = null;
//     notifyListeners();

//     final response = await _service.forgotPassword(trimmedEmail);

//     _isForgotPasswordLoading = false;
//     _forgotPasswordMessage = response.success
//         ? (response.message ?? 'Please check your email for further instructions.')
//         : (response.message ?? 'Failed to send reset instructions.');

//     notifyListeners();
//     return response.success;
//   }

//   void clearForgotPasswordMessage() {
//     if (_forgotPasswordMessage == null) return;
//     _forgotPasswordMessage = null;
//     notifyListeners();
//   }

//   void resetToEmailStep() {
//     _currentStep = AuthFlowStep.email;
//     _pendingEmail = null;
//     _errorMessage = null;
//     notifyListeners();
//   }

//   void clearError() {
//     if (_errorMessage == null) return;
//     _errorMessage = null;
//     notifyListeners();
//   }
// }
import 'package:flutter/foundation.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/features/auth/data/models/auth_user_model.dart';

import '../services/auth_service.dart';

enum AuthFlowStep { email, otp, resetPassword, authenticated }

/// Where the user should land after authentication, derived purely from
/// `role` (no separate role-selection screen in the flow anymore).
enum AuthHomeTarget { employee, manager }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

  bool _isLoading = false;
  String? _errorMessage;
  AuthUserModel? _user;

  bool _isAuthenticated = false;
  AuthFlowStep _currentStep = AuthFlowStep.email;

  String? _pendingEmail;

  /// Role restored from persisted session on app restart (checkSession),
  /// used only when there's no fresh [_user] from a just-completed login.
  String? _restoredRole;

  bool _isForgotPasswordLoading = false;
  String? _forgotPasswordMessage;

  // ================= CHANGE PASSWORD =================
  bool _isChangePasswordLoading = false;
  String? _changePasswordMessage;
  bool _changePasswordSuccess = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthUserModel? get user => _user;
  AuthFlowStep get currentStep => _currentStep;
  String? get pendingEmail => _pendingEmail;

  bool get isForgotPasswordLoading => _isForgotPasswordLoading;
  String? get forgotPasswordMessage => _forgotPasswordMessage;

  bool get isChangePasswordLoading => _isChangePasswordLoading;
  String? get changePasswordMessage => _changePasswordMessage;
  bool get changePasswordSuccess => _changePasswordSuccess;

  /// Single source of truth for role -- prefers the freshly logged-in
  /// user's role, falls back to the role restored from storage on app
  /// restart (see [checkSession]).
  String? get role => _user?.role ?? _restoredRole;

  /// Role-based navigation target (data.user.role → screen). Any role
  /// other than "manager" is treated as "employee" -- no fallback to a
  /// role-selection screen.
  AuthHomeTarget get homeTarget => role == 'manager' ? AuthHomeTarget.manager : AuthHomeTarget.employee;

  Future<bool> checkEmail(String email) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.checkEmailExists(email);

    _isLoading = false;

    if (response.success && response.data == true) {
      _pendingEmail = email;
      notifyListeners();
      return true;
    }

    _errorMessage = response.success ? 'No account found with this email.' : (response.message ?? 'Failed to verify email.');
    notifyListeners();
    return false;
  }

  Future<bool> loginWithPassword(String password, {bool rememberMe = true}) async {
    if (_isLoading) return false;

    final email = _pendingEmail;
    if (email == null || email.isEmpty) {
      _errorMessage = 'Please enter your email again.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.login(email: email, password: password, rememberMe: rememberMe);

    // ✅ DEBUG LOGGING (LOGIN ONLY)
    if (kDebugMode) {
      AppLogger.info('[LOGIN EMAIL] $email');
      AppLogger.info('[LOGIN RESPONSE] ${response.data}');
    }

    _isLoading = false;

    if (response.success && response.data != null) {
      _user = response.data;
      _isAuthenticated = true;
      _currentStep = AuthFlowStep.authenticated;

      // Role now lives on `_user.role` (see `role`/`homeTarget` getters
      // above) -- the actual screen it maps to is decided by whoever
      // reads `homeTarget`, not here. No role-selection screen involved.
      if (kDebugMode) {
        AppLogger.info('[ROLE] $role');
      }

      notifyListeners();
      return true;
    }

    _errorMessage = response.message ?? 'Login failed. Please try again.';
    notifyListeners();
    return false;
  }

  Future<bool> checkSession() async {
    final isRemembered = await _service.isRememberMe();
    if (!isRemembered) {
      await _service.logout();
    }
    _isAuthenticated = await _service.isLoggedIn();
    notifyListeners();
    return _isAuthenticated;
  }

  /// Pulls the latest user (name/email/role) from `/api/auth/me`. Safe to
  /// call after [checkSession] returns true, when there's no fresh
  /// [_user] from a same-session login to fall back on -- populates
  /// [_restoredRole] so [role]/[homeTarget] work immediately after an app
  /// restart instead of only after a fresh login.
  Future<bool> refreshCurrentUser() async {
    final response = await _service.getCurrentUser();

    if (response.success && response.data != null) {
      _user = response.data;
      _restoredRole = response.data!.role;
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> logout() async {
    await _service.logout();

    _isAuthenticated = false;
    _user = null;
    _restoredRole = null;
    _pendingEmail = null;
    _currentStep = AuthFlowStep.email;

    notifyListeners();
  }

  // ================= FORGOT PASSWORD =================
  static final RegExp _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

  /// Validates then submits the forgot-password request. Returns true
  /// only on a confirmed-success API response; [forgotPasswordMessage]
  /// always carries the message to show (success text on true, the
  /// field-level/general error on false).
  Future<bool> forgotPassword(String email) async {
    if (_isForgotPasswordLoading) return false;

    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      _forgotPasswordMessage = 'Email is required.';
      notifyListeners();
      return false;
    }

    if (!_emailRegex.hasMatch(trimmedEmail)) {
      _forgotPasswordMessage = 'Enter a valid email.';
      notifyListeners();
      return false;
    }

    _isForgotPasswordLoading = true;
    _forgotPasswordMessage = null;
    notifyListeners();

    final response = await _service.forgotPassword(trimmedEmail);

    _isForgotPasswordLoading = false;
    _forgotPasswordMessage = response.success
        ? (response.message ?? 'Please check your email for further instructions.')
        : (response.message ?? 'Failed to send reset instructions.');

    notifyListeners();
    return response.success;
  }

  void clearForgotPasswordMessage() {
    if (_forgotPasswordMessage == null) return;
    _forgotPasswordMessage = null;
    notifyListeners();
  }

  // ================= CHANGE PASSWORD =================
  /// Submits a change-password request. [changePasswordMessage] always
  /// carries the message to show; [changePasswordSuccess] tells the
  /// screen whether to pop / show a success state or keep the form open
  /// with the error visible.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    if (_isChangePasswordLoading) return false;

    if (newPassword != newPasswordConfirmation) {
      _changePasswordSuccess = false;
      _changePasswordMessage = 'Passwords do not match.';
      notifyListeners();
      return false;
    }

    _isChangePasswordLoading = true;
    _changePasswordMessage = null;
    notifyListeners();

    final response = await _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );

    _isChangePasswordLoading = false;
    _changePasswordSuccess = response.success;
    _changePasswordMessage = response.success
        ? (response.message ?? 'Password changed successfully.')
        : (response.message ?? 'Failed to change password.');

    notifyListeners();
    return response.success;
  }

  void clearChangePasswordMessage() {
    if (_changePasswordMessage == null) return;
    _changePasswordMessage = null;
    _changePasswordSuccess = false;
    notifyListeners();
  }

  void resetToEmailStep() {
    _currentStep = AuthFlowStep.email;
    _pendingEmail = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}