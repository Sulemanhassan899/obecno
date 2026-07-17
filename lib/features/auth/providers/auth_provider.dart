


// import 'package:flutter/foundation.dart';
// import 'package:Obecno/core/services/logger.dart';
// import 'package:Obecno/features/auth/data/models/auth_user_model.dart';

// import '../services/auth_service.dart';

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

//   // ================= CHANGE PASSWORD =================
//   bool _isChangePasswordLoading = false;
//   String? _changePasswordMessage;
//   bool _changePasswordSuccess = false;

//   /// Guards against overlapping `GET /api/auth/me` calls -- e.g. Splash's
//   /// bootstrap and an app-resume/401-419 revalidation firing back to back.
//   /// (spec: "Prevent duplicate /me calls")
//   bool _meInFlight = false;

//   bool get isAuthenticated => _isAuthenticated;
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   AuthUserModel? get user => _user;
//   AuthFlowStep get currentStep => _currentStep;
//   String? get pendingEmail => _pendingEmail;

//   bool get isForgotPasswordLoading => _isForgotPasswordLoading;
//   String? get forgotPasswordMessage => _forgotPasswordMessage;

//   bool get isChangePasswordLoading => _isChangePasswordLoading;
//   String? get changePasswordMessage => _changePasswordMessage;
//   bool get changePasswordSuccess => _changePasswordSuccess;

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

//   /// FIXED: this used to trust the locally persisted "session active"
//   /// flag on its own, so a cookie that had already expired/been revoked
//   /// server-side still showed the user as logged in until the very next
//   /// API call happened to 401. Per spec a session is only ever valid if
//   /// the local flag says a cookie exists AND the server confirms it via
//   /// `GET /api/auth/me` -- that call now happens as part of validation
//   /// itself (via [refreshCurrentUser]), not just opportunistically after.
//   Future<bool> checkSession() async {
//     final isRemembered = await _service.isRememberMe();
//     if (!isRemembered) {
//       await _service.logout();
//       _isAuthenticated = false;
//       notifyListeners();
//       return false;
//     }

//     final hasLocalSession = await _service.isLoggedIn();
//     if (!hasLocalSession) {
//       _isAuthenticated = false;
//       notifyListeners();
//       return false;
//     }

//     // Cookie appears to exist locally -- confirm with the backend before
//     // trusting it (spec: "Session is valid ONLY IF cookie exists AND
//     // /api/auth/me returns success").
//     final verified = await refreshCurrentUser();
//     if (!verified) {
//       // Edge case: "Expired cookie → logout".
//       await logout();
//       return false;
//     }

//     _isAuthenticated = true;
//     notifyListeners();
//     return true;
//   }

//   /// Pulls the latest user (name/email/role) from `/api/auth/me`. Safe to
//   /// call after [checkSession] returns true, when there's no fresh
//   /// [_user] from a same-session login to fall back on -- populates
//   /// [_restoredRole] so [role]/[homeTarget] work immediately after an app
//   /// restart instead of only after a fresh login.
//   ///
//   /// FIXED: added the [_meInFlight] guard so overlapping callers (Splash's
//   /// bootstrap, an app-resume revalidation, and a 401/419 interceptor hit)
//   /// can't fire duplicate concurrent `/api/auth/me` requests.
//   Future<bool> refreshCurrentUser() async {
//     if (_meInFlight) return _isAuthenticated;
//     _meInFlight = true;

//     try {
//       final response = await _service.getCurrentUser();

//       if (response.success && response.data != null) {
//         _user = response.data;
//         _restoredRole = response.data!.role;
//         notifyListeners();
//         return true;
//       }

//       return false;
//     } finally {
//       _meInFlight = false;
//     }
//   }

//   /// FIXED (missing logic): `ApiClient` already exposed an `onUnauthorized`
//   /// hook fired on 401/419 responses, but nothing was ever wired to it, so
//   /// an expired/invalidated session never got reflected back into this
//   /// provider until the app was manually restarted. This is now passed in
//   /// `binding/app_binding.dart` as:
//   ///   `ApiClient(... onUnauthorized: () => authProvider.validateSessionOnUnauthorized())`
//   ///
//   /// Per spec this method only revalidates/clears local session state --
//   /// it never navigates. `monitors/app_guard.dart` listens for
//   /// [isAuthenticated] flipping to `false` and is what actually sends the
//   /// user back to Splash/Login.
//   Future<void> validateSessionOnUnauthorized() async {
//     final stillValid = await refreshCurrentUser();
//     if (!stillValid) {
//       await logout();
//     }
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
//         ? (response.message ??
//               'Please check your email for further instructions.')
//         : (response.message ?? 'Failed to send reset instructions.');

//     notifyListeners();
//     return response.success;
//   }

//   void clearForgotPasswordMessage() {
//     if (_forgotPasswordMessage == null) return;
//     _forgotPasswordMessage = null;
//     notifyListeners();
//   }

//   // ================= CHANGE PASSWORD =================
//   /// Submits a change-password request. [changePasswordMessage] always
//   /// carries the message to show; [changePasswordSuccess] tells the
//   /// screen whether to pop / show a success state or keep the form open
//   /// with the error visible.
//   Future<bool> changePassword({
//     required String currentPassword,
//     required String newPassword,
//     required String newPasswordConfirmation,
//   }) async {
//     if (_isChangePasswordLoading) return false;

//     if (newPassword != newPasswordConfirmation) {
//       _changePasswordSuccess = false;
//       _changePasswordMessage = 'Passwords do not match.';
//       notifyListeners();
//       return false;
//     }

//     _isChangePasswordLoading = true;
//     _changePasswordMessage = null;
//     notifyListeners();

//     final response = await _service.changePassword(
//       currentPassword: currentPassword,
//       newPassword: newPassword,
//       newPasswordConfirmation: newPasswordConfirmation,
//     );

//     _isChangePasswordLoading = false;
//     _changePasswordSuccess = response.success;
//     _changePasswordMessage = response.success
//         ? (response.message ?? 'Password changed successfully.')
//         : (response.message ?? 'Failed to change password.');

//     notifyListeners();
//     return response.success;
//   }

//   void clearChangePasswordMessage() {
//     if (_changePasswordMessage == null) return;
//     _changePasswordMessage = null;
//     _changePasswordSuccess = false;
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

  /// Guards against overlapping `GET /api/auth/me` calls -- e.g. Splash's
  /// bootstrap and an app-resume/401-419 revalidation firing back to back.
  /// (spec: "Prevent duplicate /me calls")
  bool _meInFlight = false;

  /// OFFLINE-FIX: set by [refreshCurrentUser] whenever it fails, so
  /// [checkSession]/[validateSessionOnUnauthorized] can tell a *confirmed*
  /// auth rejection (server responded 401/403/419 -- the cookie really is
  /// dead) apart from a failure that never got a real answer from the
  /// server at all (no internet, DNS/timeout, dropped connection, 5xx).
  /// Only the former is allowed to log the user out -- losing internet
  /// must never end an existing session.
  bool _lastMeFailureConfirmedUnauthorized = false;

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
  AuthHomeTarget get homeTarget =>
      role == 'manager' ? AuthHomeTarget.manager : AuthHomeTarget.employee;

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

    _errorMessage = response.success
        ? 'No account found with this email.'
        : (response.message ?? 'Failed to verify email.');
    notifyListeners();
    return false;
  }

  Future<bool> loginWithPassword(
    String password, {
    bool rememberMe = true,
  }) async {
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

    final response = await _service.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );

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

  /// FIXED (offline-first): this used to trust the locally persisted
  /// "session active" flag on its own, so a cookie that had already
  /// expired/been revoked server-side still showed the user as logged in
  /// until the very next API call happened to 401. A `GET /api/auth/me`
  /// confirmation call was added for that -- but naively treated ANY
  /// failure from that call (including "no internet") as an invalid
  /// session, which is the bug this fixes: losing connectivity is not
  /// the same thing as an expired cookie, and must never log the user
  /// out or send them back to the login screen.
  ///
  /// Session is now considered valid the moment the local flag says a
  /// cookie exists (offline-first: the person stays logged in and can
  /// keep using the app, e.g. the Clock module, straight from local/
  /// cached state). The `/api/auth/me` call still runs to *confirm* that
  /// with the server when possible, but only a definite rejection
  /// (401/403/419 -- see [_lastMeFailureConfirmedUnauthorized]) is
  /// allowed to end the session. A network failure just leaves the
  /// existing local session in place; it'll be re-confirmed on the next
  /// app resume/API call once connectivity returns.
  Future<bool> checkSession() async {
    final isRemembered = await _service.isRememberMe();
    if (!isRemembered) {
      await _service.logout();
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }

    final hasLocalSession = await _service.isLoggedIn();
    if (!hasLocalSession) {
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }

    // Trust the local session immediately -- offline-first. The user is
    // considered logged in from here regardless of whether the /me
    // confirmation below can even reach the server.
    _isAuthenticated = true;
    notifyListeners();

    final verified = await refreshCurrentUser();
    if (!verified && _lastMeFailureConfirmedUnauthorized) {
      // Edge case: "Expired cookie → logout" -- the server explicitly
      // rejected the session (not just unreachable).
      await logout();
      return false;
    }

    // Either verified==true, or the confirmation call simply couldn't
    // reach the server (offline/timeout/5xx) -- keep the existing local
    // session either way.
    return true;
  }

  /// Pulls the latest user (name/email/role) from `/api/auth/me`. Safe to
  /// call after [checkSession] returns true, when there's no fresh
  /// [_user] from a same-session login to fall back on -- populates
  /// [_restoredRole] so [role]/[homeTarget] work immediately after an app
  /// restart instead of only after a fresh login.
  ///
  /// FIXED: added the [_meInFlight] guard so overlapping callers (Splash's
  /// bootstrap, an app-resume revalidation, and a 401/419 interceptor hit)
  /// can't fire duplicate concurrent `/api/auth/me` requests.
  Future<bool> refreshCurrentUser() async {
    if (_meInFlight) return _isAuthenticated;
    _meInFlight = true;

    try {
      final response = await _service.getCurrentUser();

      if (response.success && response.data != null) {
        _user = response.data;
        _restoredRole = response.data!.role;
        _lastMeFailureConfirmedUnauthorized = false;
        notifyListeners();
        return true;
      }

      // OFFLINE-FIX: only a real 401/403/419 from the server means the
      // session is actually dead. `statusCode` is null for anything that
      // never got a response at all (no internet, timeout, dropped
      // connection -- see ApiError.fromException/AuthRepository, which
      // never attach a statusCode for those cases), so those fail-open
      // here instead of being treated as a logout signal.
      _lastMeFailureConfirmedUnauthorized =
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 419;

      return false;
    } finally {
      _meInFlight = false;
    }
  }

  /// FIXED (missing logic): `ApiClient` already exposed an `onUnauthorized`
  /// hook fired on 401/419 responses, but nothing was ever wired to it, so
  /// an expired/invalidated session never got reflected back into this
  /// provider until the app was manually restarted. This is now passed in
  /// `binding/app_binding.dart` as:
  ///   `ApiClient(... onUnauthorized: () => authProvider.validateSessionOnUnauthorized())`
  ///
  /// Per spec this method only revalidates/clears local session state --
  /// it never navigates. `monitors/app_guard.dart` listens for
  /// [isAuthenticated] flipping to `false` and is what actually sends the
  /// user back to Splash/Login.
  ///
  /// OFFLINE-FIX: this only clears the session on a confirmed 401/403/419
  /// from the server. If the app resumes (or a request fails) while
  /// there's simply no internet, this is a no-op -- the existing session
  /// stays intact instead of bouncing the user back to Login.
  Future<void> validateSessionOnUnauthorized() async {
    final stillValid = await refreshCurrentUser();
    if (!stillValid && _lastMeFailureConfirmedUnauthorized) {
      await logout();
    }
    // OFFLINE-FIX: if it merely couldn't be confirmed (no internet, the
    // interceptor's own 401 turning out to be a network blip, etc.), the
    // existing session is left untouched -- no logout, no redirect.
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
        ? (response.message ??
              'Please check your email for further instructions.')
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