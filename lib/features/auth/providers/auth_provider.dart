import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/data/models/auth_company_model.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/data/models/auth_user_model.dart';

import '../services/auth_service.dart';

enum AuthFlowStep { email, otp, resetPassword, authenticated }

enum AuthHomeTarget { employee, manager }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

  /// Optional callback triggered after successful login or session restore
  /// to refresh latest policy/permissions from network.
  Future<void> Function()? _onPolicyRefresh;

  bool _isLoading = false;
  String? _errorMessage;
  AuthUserModel? _user;

  bool _isAuthenticated = false;
  AuthFlowStep _currentStep = AuthFlowStep.email;

  String? _pendingEmail;

  String? _restoredRole;

  // Fix (Issue 6): lightweight guard for the pre-login flow (checkEmail ->
  // loginWithPassword). Bumped whenever the flow is reset (e.g. the user
  // backs out to the email step while a request is in flight) so a
  // response for an abandoned attempt can't populate state for whatever
  // the user has moved on to. This mirrors _sessionEpoch's pattern but is
  // deliberately kept separate and pre-auth-only: there is no signed-in
  // session to protect yet, only this flow's own in-flight requests.
  int _authFlowToken = 0;

  bool _isForgotPasswordLoading = false;
  String? _forgotPasswordMessage;

  // ================= CHANGE PASSWORD =================
  bool _isChangePasswordLoading = false;
  String? _changePasswordMessage;
  bool _changePasswordSuccess = false;
  Completer<bool>? _meInFlightCompleter;

  // TTL cache for /auth/me: skip network if last successful refresh was recent.
  DateTime? _lastMeRefreshedAt;
  static const Duration _meCacheTtl = Duration(minutes: 5);

  bool get _isMeCacheValid {
    final last = _lastMeRefreshedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _meCacheTtl;
  }

  bool _lastMeFailureConfirmedUnauthorized = false;

  Future<void> Function()? _onLogoutCleanup;

  void registerLogoutCleanup(Future<void> Function() cleanup) {
    _onLogoutCleanup = cleanup;
  }

  // Bumped on every successful login and on every logout. Singletons that
  // outlive a single login/logout cycle (SyncService, queue/cache
  // repositories) capture this value when an async op starts and compare it
  // before applying any effect, so work started under a previous session can
  // never touch state or UI for the session that replaced it.
  int _sessionEpoch = 0;
  int get sessionEpoch => _sessionEpoch;

  // Cancels any in-flight request started under the session that's ending,
  // so it stops consuming network/backend resources instead of merely
  // having its (still-completing) result ignored by the epoch check above.
  // Purely an efficiency layer -- correctness still comes from sessionEpoch.
  ApiCancelToken _sessionCancelToken = ApiCancelToken();
  ApiCancelToken get sessionCancelToken => _sessionCancelToken;

  /// Register a callback to be called on login and session restore
  /// to refresh the latest permissions/policy from network.
  void registerPolicyRefresh(Future<void> Function() callback) {
    _onPolicyRefresh = callback;
  }

  AuthCompanyModel? _company;
  List<AuthLocationModel> _locations = const [];
  AuthLocationModel? _selectedLocation;

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

  AuthCompanyModel? get company => _company;
  String get companyName => _company?.name ?? '';
  List<AuthLocationModel> get locations => _locations;
  AuthLocationModel? get selectedLocation => _selectedLocation;
  String get selectedLocationName => _selectedLocation?.name ?? '';

  String? get role => _user?.role ?? _restoredRole;

  AuthHomeTarget get homeTarget {
    final candidates = <String>{
      if (role != null) role!,
      ...?_user?.roleIds,
      if (_user?.activeRoleView != null) _user!.activeRoleView!,
    };

    for (final raw in candidates) {
      final r = raw.trim().toLowerCase();
      if (r == '6' || r == 'manager' || r == 'owner' || r == 'admin') {
        return AuthHomeTarget.manager;
      }
    }

    // API can mark management users with is_employee: false.
    if (_user?.isEmployee == false) {
      return AuthHomeTarget.manager;
    }

    return AuthHomeTarget.employee;
  }

  bool _applyCompanyAndLocations(
    AuthUserModel user, {
    String? preferredLocationId,
  }) {
    bool hasChanged = false;

    if (user.company != null && user.company != _company) {
      _company = user.company;
      hasChanged = true;
    }

    if (user.locations.isNotEmpty) {
      if (!AuthLocationModel.isSameLocationList(_locations, user.locations)) {
        _locations = user.locations;
        hasChanged = true;
      }
    }

    AuthLocationModel? preferred;
    if (preferredLocationId != null) {
      for (final loc in _locations) {
        if (loc.id == preferredLocationId) {
          preferred = loc;
          break;
        }
      }
    }

    AuthLocationModel? defaultLocation;
    for (final loc in _locations) {
      if (loc.isDefault) {
        defaultLocation = loc;
        break;
      }
    }

    final newSelected =
        preferred ??
        defaultLocation ??
        (_locations.isNotEmpty ? _locations.first : null);
    if (newSelected != _selectedLocation) {
      _selectedLocation = newSelected;
      hasChanged = true;
    }

    return hasChanged;
  }

  Future<void> restoreCompanyAndLocationsFromCache() async {
    if (_company != null && _locations.isNotEmpty) return;

    final cachedCompany = await _service.getCachedCompany();
    final cachedLocations = await _service.getCachedLocations();
    final cachedSelectedId = await _service.getCachedSelectedLocationId();

    bool updated = false;

    if (_company == null && cachedCompany != null) {
      _company = cachedCompany;
      updated = true;
    }

    if (_locations.isEmpty && cachedLocations.isNotEmpty) {
      _locations = cachedLocations;
      updated = true;
    }

    if (_locations.isNotEmpty) {
      AuthLocationModel? match;
      if (cachedSelectedId != null) {
        for (final loc in _locations) {
          if (loc.id == cachedSelectedId) {
            match = loc;
            break;
          }
        }
      }
      final target = match ?? _locations.first;
      if (_selectedLocation != target) {
        _selectedLocation = target;
        updated = true;
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  /// Builds a minimal in-memory user from the locally persisted session so
  /// Clock / Attendance can mount while `/auth/me` is unreachable.
  Future<void> _hydrateUserFromCacheIfNeeded() async {
    if (_user != null && _user!.id.isNotEmpty) return;

    final userId = await _service.getCachedUserId();
    if (userId == null || userId.isEmpty) return;

    final email = await _service.getSavedEmail() ?? '';
    _user = AuthUserModel(
      id: userId,
      name: '',
      email: email,
      role: _restoredRole,
      company: _company,
      locations: _locations,
    );
  }

  Future<void> selectLocation(AuthLocationModel location) async {
    if (_selectedLocation?.id == location.id) return;
    _selectedLocation = location;
    notifyListeners();
    await _service.setSelectedLocationId(location.id);

    // Bypass TTL: the user explicitly switched locations so we need fresh data.
    _lastMeRefreshedAt = null;
    unawaited(refreshCurrentUser());
  }

  Future<bool> checkEmail(String email) async {
    if (_isLoading) return false;

    final flowToken = ++_authFlowToken; // Fix (Issue 6)
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _service.checkEmailExists(email);

    _isLoading = false;

    if (flowToken != _authFlowToken) {
      // Fix (Issue 6): the flow was reset while this request was in
      // flight -- don't apply a result for an attempt the user already
      // abandoned. Still notify so `_isLoading` reaching false is
      // reflected in the UI.
      notifyListeners();
      return false;
    }

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

    final flowToken = ++_authFlowToken; // Fix (Issue 6)
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

    if (flowToken != _authFlowToken) {
      // Fix (Issue 6): flow was reset (e.g. user backed out to the email
      // step) while this login request was in flight -- drop the result
      // rather than authenticating into a flow the user has abandoned.
      notifyListeners();
      return false;
    }

    if (response.success && response.data != null) {
      _user = response.data;
      _isAuthenticated = true;
      _currentStep = AuthFlowStep.authenticated;
      _sessionEpoch++;
      _sessionCancelToken = ApiCancelToken();

      _applyCompanyAndLocations(_user!);

      // Refresh latest permissions/policy from network after login
      if (_onPolicyRefresh != null) unawaited(_onPolicyRefresh!());

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

  /// Fast, local-only check (no network call): true if a remembered,
  /// locally-persisted session exists. Lets callers (AuthWrapper) decide to
  /// go straight to the authenticated UI while [checkSession]'s full
  /// network verification (`/auth/me`) continues in the background,
  /// instead of blocking first paint on that network round-trip.
  Future<bool> hasLocalSession() async {
    final isRemembered = await _service.isRememberMe();
    if (!isRemembered) return false;
    return _service.isLoggedIn();
  }

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
    _restoredRole ??= await _service.getCachedRole();

    await restoreCompanyAndLocationsFromCache();
    // Offline restore: /auth/me may fail with "No internet" while a local
    // session still exists. Clock/Attendance need a user id before they
    // mount, so hydrate from the cached session id first.
    await _hydrateUserFromCacheIfNeeded();

    _isAuthenticated = true;
    notifyListeners();

    final verified = await refreshCurrentUser();
    if (!verified && _lastMeFailureConfirmedUnauthorized) {
      await logout();
      return false;
    }

    // Refresh latest permissions/policy from network after session restore
    if (_onPolicyRefresh != null) unawaited(_onPolicyRefresh!());

    return true;
  }

  Future<bool> refreshCurrentUser() {
    // TTL guard — return immediately if the cache is still fresh.
    if (_isMeCacheValid) {
      AppLogger.info(
        'AuthProvider: /api/auth/me TTL cache hit, skipping network.',
      );
      return Future.value(true);
    }

    // Deduplication — join any in-flight request rather than spawning a new one.
    final inFlight = _meInFlightCompleter;
    if (inFlight != null) {
      AppLogger.info('AuthProvider: awaiting in-flight /api/auth/me call.');
      return inFlight.future;
    }

    final completer = Completer<bool>();
    _meInFlightCompleter = completer;

    _runRefreshCurrentUser()
        .then(completer.complete, onError: completer.completeError)
        .whenComplete(() {
          _meInFlightCompleter = null;
        });

    return completer.future;
  }

  Future<bool> _runRefreshCurrentUser() async {
    final response = await _service.getCurrentUser();

    if (response.success && response.data != null) {
      _user = response.data;
      _restoredRole = response.data!.role;
      final changed = _applyCompanyAndLocations(
        _user!,
        preferredLocationId: _selectedLocation?.id,
      );
      _lastMeFailureConfirmedUnauthorized = false;
      // Mark cache timestamp on success.
      _lastMeRefreshedAt = DateTime.now();
      if (changed) {
        notifyListeners();
      }
      return true;
    }

    _lastMeFailureConfirmedUnauthorized =
        response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 419;

    return false;
  }

  Future<void> validateSessionOnUnauthorized() async {
    final stillValid = await refreshCurrentUser();
    if (!stillValid && _lastMeFailureConfirmedUnauthorized) {
      await logout();
    }
  }

  Future<void> logout() async {
    // Invalidate first: any async op already in flight (sync pass, network
    // fetch, etc.) reads this before touching UI/state and must see a
    // changed epoch even while cleanup below is still running.
    _sessionEpoch++;
    // Actually abandon in-flight requests too (efficiency, not correctness --
    // the epoch check already guarantees no stale result can apply).
    _sessionCancelToken.cancel('logout');
    _sessionCancelToken = ApiCancelToken();
    try {
      await _onLogoutCleanup?.call();
    } catch (e, st) {
      AppLogger.error('AuthProvider', 'logout cleanup', e, stackTrace: st);
    }

    await _service.logout();
    final keptEmail = await _service.getSavedEmail();

    _isAuthenticated = false;
    _user = null;
    _restoredRole = null;
    _pendingEmail = keptEmail;
    _currentStep = AuthFlowStep.email;
    _company = null;
    _locations = const [];
    _selectedLocation = null;
    // Clear TTL cache so the next login always fetches fresh data.
    _lastMeRefreshedAt = null;

    notifyListeners();
  }

  Future<String?> getSavedEmail() => _service.getSavedEmail();

  // ================= FORGOT PASSWORD =================
  static final RegExp _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

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
    _authFlowToken++; // Fix (Issue 6): invalidate any in-flight checkEmail/login response
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
