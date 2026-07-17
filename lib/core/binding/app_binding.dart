
// import 'dart:async';

// import 'package:Obecno/core/api/api.dart';
// import 'package:Obecno/core/api/api_client.dart';
// import 'package:Obecno/core/api/cookie_service.dart';
// import 'package:Obecno/core/services/network_checker.dart';
// import 'package:Obecno/core/services/token_service.dart';
// import 'package:Obecno/features/auth/providers/auth_provider.dart';
// import 'package:Obecno/features/auth/repositories/auth_repository.dart';
// import 'package:Obecno/features/auth/services/auth_service.dart';
// import 'package:Obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
// import 'package:Obecno/features/employee_module/attendance/services/attendance_service.dart';

// import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
// import 'package:Obecno/features/employee_module/clock/services/sync_service.dart';
// import 'package:Obecno/features/employee_module/more/providers/profile_provider.dart';
// import 'package:Obecno/features/employee_module/more/repositories/profile_repository.dart';
// import 'package:Obecno/features/employee_module/more/services/profile_service.dart';
// import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
// import 'package:Obecno/shared/location/service/local_queue_service.dart';

// class AppBindings {
//   late final CookieService cookieService;
//   late final NetworkChecker networkChecker;
//   late final HttpApiClient httpClient;
//   late final TokenService token;
//   late final ApiClient ApihttpClient;
//   late final AuthService authService;
//   late final AuthProvider authProvider;
//   late final ProfileRepository profileRepository;
//   late final ProfileService profileService;
//   late final ProfileProvider profileProvider;
//   late final AttendanceService attendanceService;
//   late final AttendanceRepository clockAttendanceRepository;
//   late final HistoryAttendanceRepository attendanceRepository;

//   late final SyncService clockSyncService;

//   Future<void> init() async {
//     cookieService = await CookieService.init();
//     networkChecker = NetworkCheckerImpl();
//     token = TokenService();

//     httpClient = HttpApiClient(
//       cookieService: cookieService,
//       networkChecker: networkChecker,
//     );

//     ApihttpClient = ApiClient(
//       cookieService: cookieService,
//       networkChecker: networkChecker,
//       tokenService: token,
//       // FIXED (missing wiring): `ApiClient` already supported an
//       // `onUnauthorized` hook fired on 401/419 responses (see
//       // `core/api/api_client.dart`'s `_guard`), but nothing ever passed one
//       // in -- so an expired/invalidated session was never reflected back
//       // into `AuthProvider` until the app was manually restarted.
//       //
//       // `authProvider` below is a `late final` field assigned a few lines
//       // down in this same method. Referencing it here is safe: this
//       // closure only reads `authProvider` the first time a 401/419 is
//       // actually hit at runtime, which is always well after `init()` (and
//       // therefore the assignment below) has completed.
//       onUnauthorized: () => authProvider.validateSessionOnUnauthorized(),
//     );

//     final tokenService = TokenService();
//     // FIXED: AuthRepository now depends on ApiClient (`ApihttpClient`), the
//     // real, fully-featured GET/PUT/POST/multipart client every other
//     // module uses -- not `httpClient` (`HttpApiClient`), the bare-bones
//     // POST-only client `AuthRepository` was mistakenly wired to before.
//     // The comment above already documented this fix, but the constructor
//     // call itself was never updated -- `AuthRepository` calls `.get(...)`
//     // and `.put(...)` on its client (see auth_repository.dart), neither of
//     // which `HttpApiClient` implements, so this was a straight compile
//     // error / wrong-type wiring. Corrected to `ApihttpClient`.
//     authService = AuthService(AuthRepository(ApihttpClient), tokenService);
//     authProvider = AuthProvider(authService);

//     profileRepository = ProfileRepository(ApihttpClient);
//     profileService = ProfileService(profileRepository);
//     profileProvider = ProfileProvider(profileService);

//     final connectivityService = AttendanceConnectivityServiceImpl();
//     final queueService = LocalQueueServiceImpl();

//     attendanceService = AttendanceService(ApihttpClient);

//     clockAttendanceRepository = AttendanceRepository(
//       httpClient,
//       connectivityService,
//       queueService,
//       ApihttpClient,
//     );

//     attendanceRepository = HistoryAttendanceRepository(attendanceService);

//     clockSyncService = SyncService(
//       clockAttendanceRepository,
//       connectivityService,
//       queueService,
//     );
//     clockSyncService.startListening();
//     unawaited(clockSyncService.syncPendingData());
//   }
// }

import 'dart:async';

import 'package:Obecno/core/api/api.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/cookie_service.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/features/launch/book_demo/providers/book_demo_provider.dart';
import 'package:Obecno/features/launch/book_demo/repositories/book_demo_repository.dart';
import 'package:Obecno/features/launch/book_demo/services/book_demo_service.dart';
import 'package:Obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
import 'package:Obecno/features/employee_module/attendance/services/attendance_service.dart';

import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
import 'package:Obecno/features/employee_module/clock/services/sync_service.dart';
import 'package:Obecno/features/employee_module/more/providers/profile_provider.dart';
import 'package:Obecno/features/employee_module/more/repositories/profile_repository.dart';
import 'package:Obecno/features/employee_module/more/services/profile_service.dart';
import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:Obecno/shared/location/service/local_queue_service.dart';

class AppBindings {
  late final CookieService cookieService;
  late final NetworkChecker networkChecker;
  late final HttpApiClient httpClient;
  late final TokenService token;
  late final ApiClient ApihttpClient;

  ApiClient get apiClient => ApihttpClient;

  String get userEmail => authProvider.user?.email ?? '';

  late final AuthService authService;
  late final AuthProvider authProvider;
  late final BookDemoRepository bookDemoRepository;
  late final BookDemoService bookDemoService;
  late final BookDemoProvider bookDemoProvider;
  late final ProfileRepository profileRepository;
  late final ProfileService profileService;
  late final ProfileProvider profileProvider;
  late final AttendanceService attendanceService;
  late final AttendanceRepository clockAttendanceRepository;
  late final HistoryAttendanceRepository attendanceRepository;

  late final SyncService clockSyncService;

  Future<void> init() async {
    cookieService = await CookieService.init();
    networkChecker = NetworkCheckerImpl();
    token = TokenService();

    httpClient = HttpApiClient(
      cookieService: cookieService,
      networkChecker: networkChecker,
    );

    ApihttpClient = ApiClient(
      cookieService: cookieService,
      networkChecker: networkChecker,
      tokenService: token,
      onUnauthorized: () => authProvider.validateSessionOnUnauthorized(),
    );

    final tokenService = TokenService();

    authService = AuthService(AuthRepository(ApihttpClient), tokenService);
    authProvider = AuthProvider(authService);

    // Book a Demo -- guest ticket submission via the same
    // `/api/employee/tickets` endpoint the employee ticketing module
    // uses. No auth/session required, so it's fine that this is wired
    // up regardless of login state.
    bookDemoRepository = BookDemoRepository(ApihttpClient);
    bookDemoService = BookDemoService(bookDemoRepository);
    bookDemoProvider = BookDemoProvider(bookDemoService);

    profileRepository = ProfileRepository(ApihttpClient);
    profileService = ProfileService(profileRepository);
    profileProvider = ProfileProvider(profileService);

    final connectivityService = AttendanceConnectivityServiceImpl();
    final queueService = LocalQueueServiceImpl();

    attendanceService = AttendanceService(ApihttpClient);

    clockAttendanceRepository = AttendanceRepository(
      httpClient,
      connectivityService,
      queueService,
      ApihttpClient,
    );

    attendanceRepository = HistoryAttendanceRepository(attendanceService);

    clockSyncService = SyncService(
      clockAttendanceRepository,
      connectivityService,
      queueService,
    );

    clockSyncService.startListening();
    unawaited(clockSyncService.syncPendingData());
  }
}