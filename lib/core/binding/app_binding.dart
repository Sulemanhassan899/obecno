import 'dart:async';
import 'dart:ui';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/session_manager.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/auth/providers/permission_provider.dart';
import 'package:obecno/features/auth/repositories/auth_repository.dart';
import 'package:obecno/features/auth/services/auth_service.dart';
import 'package:obecno/features/auth/services/company_policy_service.dart';
import 'package:obecno/features/employee_module/more/repositories/privacy_provider.dart';
import 'package:obecno/features/employee_module/more/repositories/terms_provider.dart';
import 'package:obecno/features/employee_module/more/services/terms_service.dart';
import 'package:obecno/features/launch/book_demo/providers/book_demo_provider.dart';
import 'package:obecno/features/launch/book_demo/repositories/book_demo_repository.dart';
import 'package:obecno/features/launch/book_demo/services/book_demo_service.dart';
import 'package:obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:obecno/features/employee_module/more/repositories/device_repository.dart';
import 'package:obecno/features/employee_module/more/services/device_cache_service.dart';
import 'package:obecno/features/employee_module/more/services/device_info_service.dart';
import 'package:obecno/features/employee_module/more/services/device_service.dart';
import 'package:obecno/features/employee_module/attendance/data/local/attendance_cache_tracker.dart';
import 'package:obecno/features/employee_module/attendance/data/local/attendance_db.dart';
import 'package:obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';

import 'package:obecno/features/clock/repositories/clock_attendance_repository.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';
import 'package:obecno/features/clock/services/sync_service.dart';
import 'package:obecno/features/employee_module/more/providers/profile_provider.dart';
import 'package:obecno/features/employee_module/more/repositories/profile_repository.dart';
import 'package:obecno/features/employee_module/more/services/profile_service.dart';
import 'package:obecno/features/employee_module/more/services/privacy_service.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/repositories/manager_overview_repository.dart';
import 'package:obecno/features/manager_module/Manager_overview/services/manager_overview_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';
import 'package:obecno/features/manager_module/Manager_employees/services/manager_employees_service.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/repositories/manager_locations_repository.dart';
import 'package:obecno/features/manager_module/Manager_locations/services/manager_locations_service.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_status_filters_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_status_filters_repository.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_attendance_repository.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_status_filters_service.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:obecno/shared/location/service/local_queue_service.dart';
import 'package:obecno/shared/location/service/location_provider.dart';

class AppBindings {
  late final NetworkChecker networkChecker;
  late final TokenService token;
  late final ApiClient ApihttpClient;
  late final SessionManager sessionManager;

  ApiClient get apiClient => ApihttpClient;

  String get userEmail => authProvider.user?.email ?? '';

  late final AuthRepository authRepository;
  late final AuthService authService;
  late final AuthProvider authProvider;
  late final CompanyPolicyService companyPolicyService;
  late final PermissionProvider permissionProvider;
  late final BookDemoRepository bookDemoRepository;
  late final BookDemoService bookDemoService;
  late final BookDemoProvider bookDemoProvider;
  late final ProfileRepository profileRepository;
  late final ProfileService profileService;
  late final ProfileProvider profileProvider;

  late final DeviceRepository deviceRepository;
  late final DeviceInfoService deviceInfoService;
  late final DeviceCacheService deviceCacheService;
  late final DeviceService deviceService;
  late final DeviceProvider deviceProvider;

  late final TermsService termsService;
  late final TermsProvider termsProvider;
  late final PrivacyService privacyService;
  late final PrivacyProvider privacyProvider;
  late final AttendanceService attendanceService;
  late final AttendanceRepository clockAttendanceRepository;
  late final HistoryAttendanceRepository attendanceRepository;
  late final SyncService clockSyncService;
  late final EmployeeTrustedTime employeeTrustedTime;
  late final LocationProvider locationProvider;
  late final ManagerOverviewRepository managerOverviewRepository;
  late final ManagerOverviewService managerOverviewService;
  late final ManagerOverviewProvider managerOverviewProvider;
  late final ManagerLocationsRepository managerLocationsRepository;
  late final ManagerLocationsService managerLocationsService;
  late final ManagerLocationsProvider managerLocationsProvider;
  late final ManagerEmployeesRepository managerEmployeesRepository;
  late final ManagerEmployeesService managerEmployeesService;
  late final ManagerEmployeesProvider managerEmployeesProvider;
  late final ManagerStatusFiltersRepository managerStatusFiltersRepository;
  late final ManagerStatusFiltersService managerStatusFiltersService;
  late final ManagerStatusFiltersProvider managerStatusFiltersProvider;
  late final ManagerAttendanceRepository managerAttendanceRepository;
  late final ManagerAttendanceService managerAttendanceService;
  late final ManagerAttendanceProvider managerAttendanceProvider;

  VoidCallback? _authListener;
  VoidCallback? _locationSyncListener;
  String? _syncedLocationId;
  bool _wasAuthenticated = false;

  Future<void> init() async {
    networkChecker = NetworkCheckerImpl();
    token = TokenService();

    sessionManager = SessionManager(
      tokenService: token,
      validateWithBackend: () async {
        await authProvider.validateSessionOnUnauthorized();
        return authProvider.isAuthenticated;
      },
    );

    ApihttpClient = ApiClient(
      networkChecker: networkChecker,
      tokenService: token,
      onUnauthorized: () => authProvider.validateSessionOnUnauthorized(),
      sessionManager: sessionManager,
    );

    authRepository = AuthRepository(ApihttpClient);
    authService = AuthService(authRepository, token);
    authProvider = AuthProvider(authService);
    companyPolicyService = CompanyPolicyService(token, authRepository);
    permissionProvider = PermissionProvider(companyPolicyService, authService);

    // Register callback so AuthProvider refreshes latest permissions/policy
    // from the network on every login and session restore.
    authProvider.registerPolicyRefresh(() async {
      await companyPolicyService.refreshFromNetwork();
      await permissionProvider.refresh();
    });

    employeeTrustedTime = EmployeeTrustedTime();
    await employeeTrustedTime.init();

    locationProvider = LocationProvider();
    _syncLocationProviderFromAuth();
    _locationSyncListener = () {
      final selectedId = authProvider.selectedLocation?.id;
      if (selectedId != _syncedLocationId) {
        _syncLocationProviderFromAuth();
      }
    };
    authProvider.addListener(_locationSyncListener!);

    bookDemoRepository = BookDemoRepository(ApihttpClient);
    bookDemoService = BookDemoService(bookDemoRepository);
    bookDemoProvider = BookDemoProvider(bookDemoService);

    profileRepository = ProfileRepository(ApihttpClient);
    profileService = ProfileService(profileRepository);
    profileProvider = ProfileProvider(profileService);

    deviceRepository = DeviceRepository(ApihttpClient);
    deviceInfoService = DeviceInfoService();
    deviceCacheService = DeviceCacheService();
    deviceService = DeviceService(deviceRepository, deviceInfoService);
    deviceProvider = DeviceProvider(deviceService, deviceCacheService);

    termsService = TermsService(ApihttpClient);
    termsProvider = TermsProvider(termsService);
    privacyService = PrivacyService(ApihttpClient);
    privacyProvider = PrivacyProvider(privacyService);

    managerEmployeesRepository = ManagerEmployeesRepository(ApihttpClient);
    managerEmployeesService = ManagerEmployeesService(
      managerEmployeesRepository,
      currentUserIdProvider: () => authProvider.user?.id,
    );
    managerEmployeesProvider = ManagerEmployeesProvider(
      managerEmployeesService,
    );

    managerAttendanceRepository = ManagerAttendanceRepository(ApihttpClient);
    managerAttendanceService = ManagerAttendanceService(
      managerAttendanceRepository,
      employeesRepository: managerEmployeesRepository,
      currentUserIdProvider: () => authProvider.user?.id,
    );
    managerAttendanceProvider = ManagerAttendanceProvider(
      managerAttendanceService,
    );

    managerOverviewRepository = ManagerOverviewRepository(ApihttpClient);
    managerOverviewService = ManagerOverviewService(
      managerOverviewRepository,
      employeesRepository: managerEmployeesRepository,
      attendanceService: managerAttendanceService,
    );
    managerOverviewProvider = ManagerOverviewProvider(managerOverviewService);

    managerLocationsRepository = ManagerLocationsRepository(ApihttpClient);
    managerLocationsService = ManagerLocationsService(
      managerLocationsRepository,
      authLocationsProvider: () => authProvider.locations,
      companyProvider: () => authProvider.company,
      attendanceService: managerAttendanceService,
      companyScheduleProvider: () async {
        final items = await companyPolicyService.all();
        if (items.isEmpty) return null;
        return LocationSchedule.fromPermissionItems(items);
      },
    );
    managerLocationsProvider = ManagerLocationsProvider(
      managerLocationsService,
    );

    managerStatusFiltersRepository = ManagerStatusFiltersRepository(
      ApihttpClient,
    );
    managerStatusFiltersService = ManagerStatusFiltersService(
      managerStatusFiltersRepository,
    );
    managerStatusFiltersProvider = ManagerStatusFiltersProvider(
      managerStatusFiltersService,
    );

    _wasAuthenticated = authProvider.isAuthenticated;
    if (_wasAuthenticated) {
      unawaited(termsProvider.preloadOnLogin());
      unawaited(privacyProvider.preloadOnLogin());
      final userId = authProvider.user?.id;
      if (userId != null && userId.isNotEmpty) {
        unawaited(employeeTrustedTime.ensureLogin(userId: userId));
      }

      // Device registration/status is checked in the background by
      // AuthWrapper (session-restore path) and LoginPasswordScreen (fresh
      // login path), where a BuildContext is available for the
      // toast/dialog. Only silently (re-)register here so a returning
      // user's device is registered even before either widget runs.
      unawaited(deviceProvider.registerOnLogin());
    }
    _authListener = () {
      final isAuthenticatedNow = authProvider.isAuthenticated;
      if (isAuthenticatedNow && !_wasAuthenticated) {
        unawaited(termsProvider.preloadOnLogin());
        unawaited(privacyProvider.preloadOnLogin());
        final userId = authProvider.user?.id;
        if (userId != null && userId.isNotEmpty) {
          unawaited(employeeTrustedTime.ensureLogin(userId: userId));
        }
      } else if (!isAuthenticatedNow && _wasAuthenticated) {
        // Logged out: drop cached device state so a different user logging
        // in on this device doesn't inherit stale approval/blocked flags.
        unawaited(deviceProvider.clearLocalState());
        managerOverviewProvider.reset();
        managerLocationsProvider.reset();
        managerEmployeesProvider.reset();
        managerStatusFiltersProvider.reset();
        managerAttendanceProvider.reset();
      }
      _wasAuthenticated = isAuthenticatedNow;
    };
    authProvider.addListener(_authListener!);

    final connectivityService = AttendanceConnectivityServiceImpl();
    // Phase 5: the queue must always know *who* queued an action, so it can
    // never sync User A's offline action under User B's session. This
    // provider is re-read on every insert/getPending call rather than
    // captured once, since this service is a singleton that outlives any
    // single login/logout cycle.
    final queueService = LocalQueueServiceImpl(
      userIdProvider: () => authProvider.user?.id,
    );

    attendanceService = AttendanceService(ApihttpClient);

    clockAttendanceRepository = AttendanceRepository(
      ApihttpClient,
      connectivityService,
      queueService,
    );

    // Phase 4: same reasoning -- this repository is a singleton spanning
    // login/logout cycles, so its offline cache must always be scoped to
    // whoever is currently signed in, resolved live rather than fixed at
    // construction time.
    attendanceRepository = HistoryAttendanceRepository(
      attendanceService,
      userIdProvider: () => authProvider.user?.id,
      joiningDateProvider: () => authProvider.user?.joiningDate,
    );

    clockSyncService = SyncService(
      clockAttendanceRepository,
      connectivityService,
      queueService,
      sessionEpochProvider: () => authProvider.sessionEpoch,
      cancelTokenProvider: () => authProvider.sessionCancelToken,
      // Structured sync logs (SYNC_START/SYNC_ITEM/SYNC_SUCCESS/
      // SYNC_FAILURE) must be user-scoped -- read live rather than
      // captured once since this service outlives any single login.
      userIdProvider: () => authProvider.user?.id,
    );

    clockAttendanceRepository.attachSyncTrigger(
      clockSyncService.syncPendingData,
    );

    clockSyncService.startListening();
    unawaited(clockSyncService.syncPendingData());

    authProvider.registerLogoutCleanup(() async {
      // Captured before any cleanup step runs -- registerLogoutCleanup's
      // callback fires *before* AuthProvider clears `_user`, so this is
      // still the outgoing user's id here.
      final loggedOutUserId = authProvider.user?.id;

      // Phase 7: previously this was a single chained `await` sequence --
      // if any one step threw, every step after it silently never ran
      // (e.g. a failed network sync would leave the local queue, the
      // offline DB, and the cache tracker all uncleared). Each step now
      // runs independently: a failure in one is logged and does not
      // prevent the rest from executing.
      await _guardedCleanupStep(
        'invalidatePolicyCache',
        () async => companyPolicyService.invalidate(),
      );

      await _guardedCleanupStep(
        'syncPendingData',
        clockSyncService.syncPendingData,
      );

      await _guardedCleanupStep('detachSyncCallbacks', () async {
        // clockSyncService is a singleton spanning every login; its callback
        // fields are wired by whichever SyncedClockScreenController is
        // currently on screen. Null them out here so no reference to the
        // just-disposed controller can be invoked, on top of the epoch
        // guard inside SyncService itself.
        clockSyncService.onQueuedItemSynced = null;
        clockSyncService.onSyncCompleted = null;
        clockSyncService.onStateChanged = null;
      });

      await _guardedCleanupStep('clearQueue', queueService.clearAll);

      await _guardedCleanupStep(
        'clearAttendanceDb',
        AttendanceDb.instance.clearAll,
      );

      await _guardedCleanupStep('resetAttendanceCache', () async {
        if (loggedOutUserId != null && loggedOutUserId.isNotEmpty) {
          AttendanceCacheTracker.instance.resetForUser(loggedOutUserId);
        } else {
          AttendanceCacheTracker.instance.reset();
        }
      });

      await _guardedCleanupStep(
        'expireTrustedTime',
        employeeTrustedTime.ensureLoggedOut,
      );

      await _guardedCleanupStep('clearTermsCache', termsService.clearCache);

      await _guardedCleanupStep('clearPrivacyCache', privacyService.clearCache);
    });
  }

  /// Runs [step] in isolation: a thrown exception is logged and swallowed
  /// so that a single failing cleanup step (e.g. a network call during
  /// logout) never prevents the remaining logout cleanup steps from
  /// running.
  Future<void> _guardedCleanupStep(
    String label,
    Future<void> Function() step,
  ) async {
    try {
      await step();
    } catch (e, st) {
      AppLogger.error('AppBindings', 'logoutCleanup:$label', e, stackTrace: st);
    }
  }

  void dispose() {
    if (_authListener != null) {
      authProvider.removeListener(_authListener!);
      _authListener = null;
    }
    if (_locationSyncListener != null) {
      authProvider.removeListener(_locationSyncListener!);
      _locationSyncListener = null;
    }
    clockSyncService.stopListening();
    employeeTrustedTime.dispose();
  }

  void _syncLocationProviderFromAuth() {
    final selected = authProvider.selectedLocation;
    _syncedLocationId = selected?.id;
    if (selected == null) return;
    unawaited(
      locationProvider.bindCompanyLocation(
        name: selected.name,
        latLon: selected.latLon,
      ),
    );
    locationProvider.configureRadius(selected.radiusMeters);
  }
}
