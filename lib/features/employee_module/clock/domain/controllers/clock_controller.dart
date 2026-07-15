// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:Obecno/core/constants/app_enums.dart';
// import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
// import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';

// enum AttendanceActionResult {
//   checkedIn,
//   checkedOut,
//   breakStarted,
//   breakEnded,
//   outOfRange,
//   none,
// }

// class ClockTicker extends ValueNotifier<DateTime> {
//   ClockTicker() : super(DateTime.now());

//   Timer? _timer;

//   void start() {
//     _timer?.cancel();
//     _timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       value = DateTime.now();
//     });
//   }

//   void stop() {
//     _timer?.cancel();
//     _timer = null;
//   }

//   @override
//   void dispose() {
//     stop();
//     super.dispose();
//   }
// }

// /// All attendance/clock-in business logic for ClockScreen.
// /// Lives outside the widget tree so it's easy to unit-test and easy to
// /// later swap the in-memory `_events` list for real API/repository calls.
// class ClockScreenController extends ChangeNotifier {
//   static const Duration actionCooldown = Duration(seconds: 5);
//   static const Duration tapProcessingDelay = Duration(milliseconds: 700);

//   final List<AttendanceEvent> _events = [];
//   List<AttendanceEvent> get events => List.unmodifiable(_events);
//   bool get hasAnyEventToday => _events.isNotEmpty;

//   bool isInRange = true;
//   bool isCompanyValid = true;

//   String selectedLocationName = "Head Office";
//   String selectedCompanyName = "Company 1";

//   bool isProcessing = false;
//   bool isCoolingDown = false;
//   Timer? _cooldownTimer;

//   bool _disposed = false;

//   void selectLocation(String name, {required bool inRange}) {
//     selectedLocationName = name;
//     isInRange = inRange;
//     notifyListeners();
//   }

//   void selectCompany(String name, {required bool isCompany}) {
//     selectedCompanyName = name;
//     isCompanyValid = isCompany;
//     notifyListeners();
//   }

//   /// Status derived purely from today's event list.
//   AttendanceDayStatus get _statusFromEvents {
//     if (_events.isEmpty) return AttendanceDayStatus.checkedOut;
//     final summary = AttendanceEngine.compute(_events);
//     if (summary.isOnBreak) return AttendanceDayStatus.onBreak;
//     if (summary.isCheckedIn) {
//       final sorted = [..._events]..sort((a, b) => a.time.compareTo(b.time));
//       final everHadBreak = sorted.any(
//         (e) => e.type == AttendanceEventType.breakEnd,
//       );
//       return everHadBreak
//           ? AttendanceDayStatus.endedBreak
//           : AttendanceDayStatus.checkedIn;
//     }
//     return AttendanceDayStatus.checkedOut;
//   }

//   AttendanceDayStatus get effectiveStatus {
//     if (!isInRange) return AttendanceDayStatus.outofRange;
//     return _statusFromEvents;
//   }

//   bool get isOnBreak => effectiveStatus == AttendanceDayStatus.onBreak;

//   bool get isButtonEnabled =>
//       effectiveStatus == AttendanceDayStatus.outofRange ? true : !isCoolingDown;

//   void _addEvent(AttendanceEventType type) {
//     _events.add(
//       AttendanceEvent(
//         type: type,
//         time: DateTime.now(),
//         // NOTE: previously hardcoded to a constant "Head Office" regardless
//         // of the picker selection — using the actual selected location here.
//         location: selectedLocationName,
//       ),
//     );
//   }

//   void _startActionCooldown() {
//     _cooldownTimer?.cancel();
//     isCoolingDown = true;
//     _cooldownTimer = Timer(actionCooldown, () {
//       if (_disposed) return;
//       isCoolingDown = false;
//       notifyListeners();
//     });
//   }

//   Future<AttendanceActionResult> handleMainTap() async {
//     if (isProcessing || isCoolingDown) return AttendanceActionResult.none;
//     if (!isInRange) return AttendanceActionResult.outOfRange;

//     final status = _statusFromEvents;

//     isProcessing = true;
//     notifyListeners();
//     await Future.delayed(tapProcessingDelay);
//     if (_disposed) return AttendanceActionResult.none;

//     var result = AttendanceActionResult.none;

//     switch (status) {
//       case AttendanceDayStatus.checkedOut:
//         _addEvent(AttendanceEventType.checkIn);
//         _startActionCooldown();
//         result = AttendanceActionResult.checkedIn;
//         break;

//       case AttendanceDayStatus.checkedIn:
//       case AttendanceDayStatus.endedBreak:
//         _addEvent(AttendanceEventType.checkOut);
//         _startActionCooldown();
//         result = AttendanceActionResult.checkedOut;
//         break;

//       case AttendanceDayStatus.onBreak:
//         _addEvent(AttendanceEventType.breakEnd);
//         _startActionCooldown();
//         result = AttendanceActionResult.breakEnded;
//         break;

//       case AttendanceDayStatus.outofRange:
//         break;
//       case AttendanceDayStatus.lateCheckIn:
//         throw UnimplementedError();
//       case AttendanceDayStatus.absent:
//         throw UnimplementedError();
//       case AttendanceDayStatus.normal:
//         throw UnimplementedError();
//       case AttendanceDayStatus.missingCheckOut:
//         throw UnimplementedError();
//       case AttendanceDayStatus.manuallyEdited:
//         throw UnimplementedError();
//       case AttendanceDayStatus.weekend:
//         throw UnimplementedError();
//     }

//     isProcessing = false;
//     notifyListeners();
//     return result;
//   }

//   Future<AttendanceActionResult> handleBreakTap() async {
//     if (isProcessing || isCoolingDown) return AttendanceActionResult.none;
//     if (!isInRange) return AttendanceActionResult.outOfRange;

//     final status = _statusFromEvents;
//     if (status != AttendanceDayStatus.checkedIn &&
//         status != AttendanceDayStatus.endedBreak) {
//       return AttendanceActionResult.none;
//     }

//     isProcessing = true;
//     notifyListeners();
//     await Future.delayed(tapProcessingDelay);
//     if (_disposed) return AttendanceActionResult.none;

//     _addEvent(AttendanceEventType.breakStart);
//     _startActionCooldown();

//     isProcessing = false;
//     notifyListeners();
//     return AttendanceActionResult.breakStarted;
//   }

//   @override
//   void dispose() {
//     _disposed = true;
//     _cooldownTimer?.cancel();
//     super.dispose();
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';

enum AttendanceActionResult {
  checkedIn,
  checkedOut,
  breakStarted,
  breakEnded,
  outOfRange,
  none,
}

class ClockTicker extends ValueNotifier<DateTime> {
  ClockTicker() : super(DateTime.now());

  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      value = DateTime.now();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// All attendance/clock-in business logic for ClockScreen.
/// Lives outside the widget tree so it's easy to unit-test and easy to
/// later swap the in-memory `_events` list for real API/repository calls.
class ClockScreenController extends ChangeNotifier {
  static const Duration actionCooldown = Duration(seconds: 5);
  static const Duration tapProcessingDelay = Duration(milliseconds: 700);

  final List<AttendanceEvent> _events = [];
  List<AttendanceEvent> get events => List.unmodifiable(_events);
  bool get hasAnyEventToday => _events.isNotEmpty;

  bool isInRange = true;
  bool isCompanyValid = true;

  String selectedLocationName = "Head Office";
  String selectedCompanyName = "Company 1";

  bool isProcessing = false;
  bool isCoolingDown = false;
  Timer? _cooldownTimer;

  bool _disposed = false;

  // ADDED: persist ONLY the current day's button-state-driving events, so
  // switching tabs or restarting the app doesn't reset the button back to
  // "Check In" while a session is actually still open. This does NOT
  // persist full attendance history -- just today's in-progress events,
  // keyed by date so it naturally rolls over at midnight.
  static const String _prefsKeyPrefix = 'clock_events_';

  ClockScreenController() {
    unawaited(_restorePersistedEvents());
  }

  String get _todayPrefsKey {
    final now = DateTime.now();
    return '$_prefsKeyPrefix${now.year}-${now.month}-${now.day}';
  }

  Future<void> _restorePersistedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_todayPrefsKey);
      if (raw == null || _disposed) return;

      final decoded = jsonDecode(raw) as List;
      final restored = decoded
          .map((e) => AttendanceEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      _events
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } catch (_) {
      // Corrupt or missing persisted state should never crash the screen
      // -- just fall back to starting from checked-out, as before.
    }
  }

  Future<void> _persistEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
      await prefs.setString(_todayPrefsKey, encoded);
    } catch (_) {
      // Persistence is a convenience, not the source of truth -- never
      // let a disk/storage failure interrupt the actual clock action.
    }
  }

  void selectLocation(String name, {required bool inRange}) {
    selectedLocationName = name;
    isInRange = inRange;
    notifyListeners();
  }

  void selectCompany(String name, {required bool isCompany}) {
    selectedCompanyName = name;
    isCompanyValid = isCompany;
    notifyListeners();
  }

  /// Status derived purely from today's event list.
  AttendanceDayStatus get _statusFromEvents {
    if (_events.isEmpty) return AttendanceDayStatus.checkedOut;
    final summary = AttendanceEngine.compute(_events);
    if (summary.isOnBreak) return AttendanceDayStatus.onBreak;
    if (summary.isCheckedIn) {
      final sorted = [..._events]..sort((a, b) => a.time.compareTo(b.time));
      final everHadBreak = sorted.any(
        (e) => e.type == AttendanceEventType.breakEnd,
      );
      return everHadBreak
          ? AttendanceDayStatus.endedBreak
          : AttendanceDayStatus.checkedIn;
    }
    return AttendanceDayStatus.checkedOut;
  }

  AttendanceDayStatus get effectiveStatus {
    if (!isInRange) return AttendanceDayStatus.outofRange;
    return _statusFromEvents;
  }

  bool get isOnBreak => effectiveStatus == AttendanceDayStatus.onBreak;

  bool get isButtonEnabled =>
      effectiveStatus == AttendanceDayStatus.outofRange ? true : !isCoolingDown;

  void _addEvent(AttendanceEventType type) {
    _events.add(
      AttendanceEvent(
        type: type,
        time: DateTime.now(),
        // NOTE: previously hardcoded to a constant "Head Office" regardless
        // of the picker selection — using the actual selected location here.
        location: selectedLocationName,
      ),
    );
    unawaited(_persistEvents()); // ADDED: keep persisted state in sync
  }

  void _startActionCooldown() {
    _cooldownTimer?.cancel();
    isCoolingDown = true;
    _cooldownTimer = Timer(actionCooldown, () {
      if (_disposed) return;
      isCoolingDown = false;
      notifyListeners();
    });
  }

  // ADDED: `events` is intentionally exposed as `List.unmodifiable(_events)`
  // -- a brand new read-only view generated on every access -- so external
  // callers (e.g. SyncedClockScreenController) can look but never mutate it.
  // When a subclass optimistically commits a local event and then finds out
  // the server rejected it, it still needs a safe, sanctioned way to roll
  // that single event back. This is that seam: it mutates the real backing
  // `_events` list (not a throwaway unmodifiable copy) and notifies once.
  @protected
  void revertLastEvent() {
    if (_events.isEmpty || _disposed) return; // ✅ ADD THIS: dispose guard
    _events.removeLast(); // ADDED
    unawaited(_persistEvents()); // ADDED: keep persisted state in sync
    notifyListeners(); // ADDED
  }

  // ADDED: full-snapshot restore, for subclasses that optimistically
  // commit an event and then need to roll the WHOLE list back to a
  // prior snapshot (not just drop the last entry) if the server
  // rejects the action. Mutates the real backing `_events` list
  // directly -- unlike the `events` getter, which returns a brand new
  // `List.unmodifiable(...)` wrapper on every access and therefore
  // cannot be mutated by a caller outside this file.
  @protected
  void restoreEvents(List<AttendanceEvent> snapshot) {
    if (_disposed) return; // ✅ ADD THIS: dispose guard -- see revertLastEvent
    _events
      ..clear()
      ..addAll(snapshot);
    unawaited(_persistEvents()); // ADDED: keep persisted state in sync
    notifyListeners();
  }

  Future<AttendanceActionResult> handleMainTap() async {
    if (isProcessing || isCoolingDown) return AttendanceActionResult.none;
    if (!isInRange) return AttendanceActionResult.outOfRange;

    final status = _statusFromEvents;

    isProcessing = true;
    notifyListeners();
    await Future.delayed(tapProcessingDelay);
    if (_disposed) return AttendanceActionResult.none;

    var result = AttendanceActionResult.none;

    switch (status) {
      case AttendanceDayStatus.checkedOut:
        _addEvent(AttendanceEventType.checkIn);
        _startActionCooldown();
        result = AttendanceActionResult.checkedIn;
        break;

      case AttendanceDayStatus.checkedIn:
      case AttendanceDayStatus.endedBreak:
        _addEvent(AttendanceEventType.checkOut);
        _startActionCooldown();
        result = AttendanceActionResult.checkedOut;
        break;

      case AttendanceDayStatus.onBreak:
        _addEvent(AttendanceEventType.breakEnd);
        _startActionCooldown();
        result = AttendanceActionResult.breakEnded;
        break;

      case AttendanceDayStatus.outofRange:
        break;
      case AttendanceDayStatus.lateCheckIn:
        throw UnimplementedError();
      case AttendanceDayStatus.absent:
        throw UnimplementedError();
      case AttendanceDayStatus.normal:
        throw UnimplementedError();
      case AttendanceDayStatus.missingCheckOut:
        throw UnimplementedError();
      case AttendanceDayStatus.manuallyEdited:
        throw UnimplementedError();
      case AttendanceDayStatus.weekend:
        throw UnimplementedError();
    }

    isProcessing = false;
    notifyListeners();
    return result;
  }

  Future<AttendanceActionResult> handleBreakTap() async {
    if (isProcessing || isCoolingDown) return AttendanceActionResult.none;
    if (!isInRange) return AttendanceActionResult.outOfRange;

    final status = _statusFromEvents;
    if (status != AttendanceDayStatus.checkedIn &&
        status != AttendanceDayStatus.endedBreak) {
      return AttendanceActionResult.none;
    }

    isProcessing = true;
    notifyListeners();
    await Future.delayed(tapProcessingDelay);
    if (_disposed) return AttendanceActionResult.none;

    _addEvent(AttendanceEventType.breakStart);
    _startActionCooldown();

    isProcessing = false;
    notifyListeners();
    return AttendanceActionResult.breakStarted;
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    super.dispose();
  }
}