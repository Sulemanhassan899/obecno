import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/model/clock_attendence_event.dart';
import 'package:Obecno/screens/Employee_module/clock_module/widgets/clock_attendance_engine.dart';

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
        // TODO: Handle this case.
        throw UnimplementedError();
      case AttendanceDayStatus.absent:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AttendanceDayStatus.normal:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AttendanceDayStatus.missingCheckOut:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AttendanceDayStatus.manuallyEdited:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AttendanceDayStatus.weekend:
        // TODO: Handle this case.
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
