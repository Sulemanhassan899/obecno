
// import 'dart:async';

// import 'package:flutter/foundation.dart';
// import 'package:Obecno/features/employee_module/clock/domain/controllers/clock_controller.dart';
// import 'package:Obecno/shared/location/data/location_model.dart';
// import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
// import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
// import 'package:Obecno/shared/location/service/location_service.dart';

// import '../../repositories/clock_attendance_repository.dart';

// class SyncedClockScreenController extends ClockScreenController {
//   SyncedClockScreenController({
//     required AttendanceRepository repository,
//     AttendancePermissionService permissionService =
//         const AttendancePermissionService(),
//     LocationService? locationService,
//   }) : _repository = repository,
//        _permissionService = permissionService,
//        _locationService = locationService ?? LocationServiceImpl();

//   final AttendanceRepository _repository;
//   final AttendancePermissionService _permissionService;
//   final LocationService _locationService;

//   String? lastServerMessage;
//   bool blockNextAction = false;

//   /// Per spec: the check-in control must stay disabled after a business
//   /// failure (not just block the tap handler) until the state is reset.
//   /// `isButtonEnabled` already feeds directly into `CheckInButton.enabled`
//   /// from ClockScreen, so overriding it here is enough -- no widget
//   /// changes required.
//   @override
//   bool get isButtonEnabled => !blockNextAction && super.isButtonEnabled;

//   @override
//   Future<AttendanceActionResult> handleMainTap() async {
//     if (blockNextAction) return AttendanceActionResult.none;

//     final result = await super.handleMainTap();
//     _syncIfNeeded(result);
//     return result;
//   }

//   @override
//   Future<AttendanceActionResult> handleBreakTap() async {
//     if (blockNextAction) return AttendanceActionResult.none;

//     final result = await super.handleBreakTap();
//     _syncIfNeeded(result);
//     return result;
//   }

//   void _syncIfNeeded(AttendanceActionResult result) {
//     final action = _apiActionFor(result);
//     if (action == null) return;
//     unawaited(_submit(action, result));
//   }

//   Future<void> _submit(
//     String action,
//     AttendanceActionResult localResult,
//   ) async {
//     final capturedAt = events.isEmpty ? DateTime.now() : events.last.time;

//     final permitted = await _permissionService.checkAndRequestPermissions();
//     if (!permitted) return;

//     LocationModel? location;
//     try {
//       location = await _locationService.getCurrentLocation();
//     } catch (_) {}

//     final payload = AttendancePayloadModel(
//       action: action,
//       capturedAt: capturedAt,
//       location: location,
//     );

//     try {
//       await _repository.submitAttendance(payload);

//       // ✅ SUCCESS
//       blockNextAction = false;
//     } catch (e) {
//       // 🔥 NOW YOU GET REAL BACKEND MESSAGE
//       lastServerMessage = e.toString();

//       // ❌ REVERT UI STATE
//       if (events.isNotEmpty) {
//         events.removeLast();
//       }

//       // 🚫 BLOCK invalid next tap
//       blockNextAction = true;

//       notifyListeners();
//     }
//   }

//   String? _apiActionFor(AttendanceActionResult result) {
//     switch (result) {
//       case AttendanceActionResult.checkedIn:
//         return AttendanceAction.checkIn;
//       case AttendanceActionResult.checkedOut:
//         return AttendanceAction.checkOut;
//       case AttendanceActionResult.breakStarted:
//         return AttendanceAction.breakStart;
//       case AttendanceActionResult.breakEnded:
//         return AttendanceAction.breakEnd;
//       case AttendanceActionResult.outOfRange:
//       case AttendanceActionResult.none:
//         return null;
//     }
//   }
// }

import 'dart:async';

import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:flutter/foundation.dart';
import 'package:Obecno/features/employee_module/clock/domain/controllers/clock_controller.dart';
import 'package:Obecno/shared/location/data/location_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
import 'package:Obecno/shared/location/service/location_service.dart';

import '../../repositories/clock_attendance_repository.dart';

class SyncedClockScreenController extends ClockScreenController {
  SyncedClockScreenController({
    required AttendanceRepository repository,
    AttendancePermissionService permissionService =
        const AttendancePermissionService(),
    LocationService? locationService,
  }) : _repository = repository,
       _permissionService = permissionService,
       _locationService = locationService ?? LocationServiceImpl() {
    // ✅ ADD THIS: this is the actual fix for the "button shows Check
    // Out but every checkout gets rejected with 409" loop. Local
    // `_events` was only ever built from optimistic taps + whatever got
    // persisted to SharedPreferences on a PREVIOUS run -- nothing ever
    // checked that against what the server actually has for today. If
    // the two drift apart (stale persisted state, an action taken on
    // another device, the server having already auto-closed a session,
    // etc.), the button keeps showing a state the server will reject
    // forever, and restarting the app doesn't help because
    // SharedPreferences just restores the same wrong state again.
    // Correcting it here, before the user can tap anything, fixes that
    // at the source instead of only reacting after another failure.
    unawaited(reconcileWithServer());
  }

  final AttendanceRepository _repository;
  final AttendancePermissionService _permissionService;
  final LocationService _locationService;

  String? lastServerMessage;
  bool blockNextAction = false;

  // ✅ ADD THIS: `reconcileWithServer()` below is fired from the
  // constructor and awaits a network call, so it can still be pending
  // when the screen (and this controller) gets disposed -- e.g. the
  // user backs out fast, or switches tabs before it resolves. Without
  // this guard, the network call finishing later would call
  // `restoreEvents()` -> `notifyListeners()` on an already-disposed
  // `ChangeNotifier` and throw the EXACT "used after being disposed"
  // crash seen in the attendance-history controller log. Tracked here
  // (not in the base class's private `_disposed`) since Dart's `_`
  // privacy is per-file, not per-subclass.
  bool _localDisposed = false;

  @override
  void dispose() {
    _localDisposed = true;
    super.dispose();
  }

  @override
  bool get isButtonEnabled => !blockNextAction && super.isButtonEnabled;

  @override
  Future<AttendanceActionResult> handleMainTap() async {
    if (blockNextAction) return AttendanceActionResult.none;

    // FIXED: snapshot must be taken BEFORE super.handleMainTap() runs --
    // that call is what optimistically adds the new event. Taking the
    // snapshot afterwards (the old code) meant "previousEvents" already
    // included the unconfirmed event, so restoring it on failure was a
    // no-op and the button state never actually rolled back.
    final previousEvents = List.of(events);
    final result = await super.handleMainTap();

    // ✅ ADD THIS: `super.handleMainTap()` already flips `isProcessing`
    // back to false once ITS local delay finishes -- before the real
    // network request below even starts. That meant the loading
    // spinner disappeared and the button became tappable again while
    // the API call was still in flight. Re-raise it for the network
    // leg too, so the spinner covers the FULL round trip as intended.
    isProcessing = true;
    notifyListeners();
    try {
      return await _syncIfNeeded(result, previousEvents);
    } finally {
      isProcessing = false;
      if (!_localDisposed) notifyListeners(); // ✅ ADD THIS: dispose guard
    }
  }

  @override
  Future<AttendanceActionResult> handleBreakTap() async {
    if (blockNextAction) return AttendanceActionResult.none;

    // FIXED: same snapshot-timing issue as handleMainTap above.
    final previousEvents = List.of(events);
    final result = await super.handleBreakTap();

    // ✅ ADD THIS: same isProcessing-covers-the-network-call fix as
    // handleMainTap above.
    isProcessing = true;
    notifyListeners();
    try {
      return await _syncIfNeeded(result, previousEvents);
    } finally {
      isProcessing = false;
      if (!_localDisposed) notifyListeners(); // ✅ ADD THIS: dispose guard
    }
  }

  /// ✅ FIXED: snapshot + restore instead of partial rollback
  Future<AttendanceActionResult> _syncIfNeeded(
    AttendanceActionResult localResult,
    List<AttendanceEvent> previousEvents,
  ) async {
    final action = _apiActionFor(localResult);
    if (action == null) return localResult;

    final succeeded = await _submit(action, localResult);

    if (!succeeded) {
      // ✅ CHANGED: prefer correcting from the server (authoritative)
      // over the local pre-tap snapshot. `previousEvents` can itself
      // already be wrong if local state had drifted from the server
      // BEFORE this tap happened -- which is exactly the root cause of
      // the repeated-409 loop. Only fall back to the plain local
      // rollback if the server genuinely can't be reached right now
      // (offline / request itself failed).
      final reconciled = await reconcileWithServer();
      if (!reconciled) {
        // restoreEvents() already calls notifyListeners() once internally.
        restoreEvents(previousEvents);
      }

      return AttendanceActionResult.none;
    }

    return localResult;
  }

  /// ✅ ADD THIS: replaces local `_events` with what the server actually
  /// has recorded for today, so the button can never keep showing a
  /// state the server will reject. Safe to call any time the button
  /// isn't mid-action -- it's just a snapshot restore under the hood,
  /// same as the rollback path already used on failure.
  Future<bool> reconcileWithServer() async {
    try {
      final serverEvents = await _repository.fetchTodayEvents();
      if (_localDisposed) return false; // ✅ ADD THIS: disposed while awaiting
      if (serverEvents == null) {
        // Offline, unreachable, or the repository wasn't wired with a
        // status client -- keep whatever local state already exists
        // rather than wiping it out based on nothing.
        return false;
      }
      restoreEvents(serverEvents);
      // A freshly server-confirmed state was never itself rejected --
      // don't leave the button stuck disabled from a previous failure.
      blockNextAction = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _submit(
    String action,
    AttendanceActionResult localResult,
  ) async {
    final capturedAt = events.isEmpty ? DateTime.now() : events.last.time;

    final permitted = await _permissionService.checkAndRequestPermissions();
    if (!permitted) return true;

    LocationModel? location;
    try {
      location = await _locationService.getCurrentLocation();
    } catch (_) {}

    final payload = AttendancePayloadModel(
      action: action,
      capturedAt: capturedAt,
      location: location,
    );

    try {
      await _repository.submitAttendance(payload);

      // ✅ SUCCESS
      blockNextAction = false;
      return true;
    } catch (e) {
      // ❌ FAILURE
      lastServerMessage = e.toString();

      // ⚠️ OLD rollback removed (we now do full restore instead)
      // revertLastEvent(); ❌ NO LONGER USED

      blockNextAction = true;

      if (!_localDisposed) notifyListeners(); // ✅ ADD THIS: dispose guard
      return false;
    }
  }

  String? _apiActionFor(AttendanceActionResult result) {
    switch (result) {
      case AttendanceActionResult.checkedIn:
        return AttendanceAction.checkIn;
      case AttendanceActionResult.checkedOut:
        return AttendanceAction.checkOut;
      case AttendanceActionResult.breakStarted:
        return AttendanceAction.breakStart;
      case AttendanceActionResult.breakEnded:
        return AttendanceAction.breakEnd;
      case AttendanceActionResult.outOfRange:
      case AttendanceActionResult.none:
        return null;
    }
  }

  // FIXED: the old local `restoreEvents` here mutated `events`, which is
  // `List.unmodifiable(_events)` -- a fresh read-only wrapper on every
  // access -- so `.clear()`/`.addAll()` threw `UnsupportedError` at
  // runtime any time the server rejected an action (e.g. duplicate
  // check-in / 409). Removed in favor of the protected helper on
  // `ClockScreenController`, which mutates the real backing list.
}