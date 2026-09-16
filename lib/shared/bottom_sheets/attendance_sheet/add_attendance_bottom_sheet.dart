// ignore_for_file: non_constant_identifier_names

import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/employee_module/attendance/services/scheduled_attendance_times.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/bottom_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class AddAttendanceSaveResult {
  const AddAttendanceSaveResult({
    this.checkIn,
    this.checkOut,
    this.breakStart,
    this.breakEnd,
  });

  /// Only fields the user actually changed. Null means leave the existing value.
  final TimeOfDay? checkIn;
  final TimeOfDay? checkOut;
  final TimeOfDay? breakStart;
  final TimeOfDay? breakEnd;
}

class AddAttendanceBottomSheet {
  /// Returns save result when attendance was saved successfully.
  static Future<AddAttendanceSaveResult?> show(
    BuildContext context, {
    required DateTime day,
    required ApiClient apiClient,
    required String userEmail,
    TimeOfDay? initialCheckIn,
    TimeOfDay? initialCheckOut,
    TimeOfDay? initialBreakStart,
    TimeOfDay? initialBreakEnd,
    String? checkInDetailId,
    String? checkOutDetailId,
    String? breakStartDetailId,
    String? breakEndDetailId,
    int? attendanceId,
    int? employeeUserId,
    String? employeeName,
    bool applyImmediately = false,
    bool isCreating = false,
    bool hadInitialCheckIn = false,
    bool hadInitialCheckOut = false,
    bool hadInitialBreakStart = false,
    bool hadInitialBreakEnd = false,
  }) async {
    var resolvedCheckIn = initialCheckIn;
    var resolvedCheckOut = initialCheckOut;
    var resolvedBreakStart = initialBreakStart;
    var resolvedBreakEnd = initialBreakEnd;
    var resolvedAttendanceId = attendanceId;
    var resolvedCheckInId = checkInDetailId;
    var resolvedCheckOutId = checkOutDetailId;
    var resolvedBreakStartId = breakStartDetailId;
    var resolvedBreakEndId = breakEndDetailId;

    final needsDetails =
        isCreating ||
        resolvedAttendanceId == null ||
        AttendanceDetailItem.serverDetailId(resolvedCheckInId) == null ||
        AttendanceDetailItem.serverDetailId(resolvedCheckOutId) == null ||
        AttendanceDetailItem.serverDetailId(resolvedBreakStartId) == null ||
        AttendanceDetailItem.serverDetailId(resolvedBreakEndId) == null;

    if (needsDetails) {
      final scheduled = await ScheduledAttendanceTimes.load(
        apiClient: apiClient,
        day: day,
        employeeUserId: employeeUserId,
      );
      if (isCreating) {
        resolvedCheckIn ??= scheduled.checkIn;
        resolvedCheckOut ??= scheduled.checkOut;
        resolvedBreakStart ??= scheduled.breakStart;
        resolvedBreakEnd ??= scheduled.breakEnd;
      }
      resolvedAttendanceId ??= scheduled.attendanceId;
      resolvedCheckInId ??= scheduled.checkInDetailId;
      resolvedCheckOutId ??= scheduled.checkOutDetailId;
      resolvedBreakStartId ??= scheduled.breakStartDetailId;
      resolvedBreakEndId ??= scheduled.breakEndDetailId;
    }

    final applyNow =
        applyImmediately ||
        bindings.authProvider.homeTarget == AuthHomeTarget.manager;

    final contentKey = GlobalKey<_AttendanceContentState>();

    return CommonBottomSheet.show<AddAttendanceSaveResult>(
      context: context,
      buttonText: "Save",
      buttonColor: kBlack,
      buttonFontColor: kWhite,

      onButtonTap: () async {
        await contentKey.currentState?.handleSave();
      },
      children: [
        _AttendanceContent(
          key: contentKey,
          day: day,
          apiClient: apiClient,
          userEmail: userEmail,
          initialCheckIn:
              resolvedCheckIn ?? const TimeOfDay(hour: 8, minute: 0),
          initialCheckOut:
              resolvedCheckOut ?? const TimeOfDay(hour: 17, minute: 0),
          initialBreakStart:
              resolvedBreakStart ?? const TimeOfDay(hour: 10, minute: 0),
          initialBreakEnd:
              resolvedBreakEnd ?? const TimeOfDay(hour: 10, minute: 30),
          checkInDetailId: AttendanceDetailItem.serverDetailId(
            resolvedCheckInId,
          ),
          checkOutDetailId: AttendanceDetailItem.serverDetailId(
            resolvedCheckOutId,
          ),
          breakStartDetailId: AttendanceDetailItem.serverDetailId(
            resolvedBreakStartId,
          ),
          breakEndDetailId: AttendanceDetailItem.serverDetailId(
            resolvedBreakEndId,
          ),
          attendanceId: resolvedAttendanceId,
          employeeUserId: employeeUserId,
          employeeName: employeeName,
          applyImmediately: applyNow,
          isCreating: isCreating,
          hadInitialCheckIn: hadInitialCheckIn || initialCheckIn != null,
          hadInitialCheckOut: hadInitialCheckOut || initialCheckOut != null,
          hadInitialBreakStart:
              hadInitialBreakStart || initialBreakStart != null,
          hadInitialBreakEnd: hadInitialBreakEnd || initialBreakEnd != null,
        ),
      ],
    );
  }
}

class _AttendanceContent extends StatefulWidget {
  final DateTime day;
  final ApiClient apiClient;
  final String userEmail;
  final TimeOfDay initialCheckIn;
  final TimeOfDay initialCheckOut;
  final TimeOfDay initialBreakStart;
  final TimeOfDay initialBreakEnd;
  final String? checkInDetailId;
  final String? checkOutDetailId;
  final String? breakStartDetailId;
  final String? breakEndDetailId;
  final int? attendanceId;
  final int? employeeUserId;
  final String? employeeName;
  final bool applyImmediately;
  final bool isCreating;
  final bool hadInitialCheckIn;
  final bool hadInitialCheckOut;
  final bool hadInitialBreakStart;
  final bool hadInitialBreakEnd;

  const _AttendanceContent({
    super.key,
    required this.day,
    required this.apiClient,
    required this.userEmail,
    required this.initialCheckIn,
    required this.initialCheckOut,
    required this.initialBreakStart,
    required this.initialBreakEnd,
    this.checkInDetailId,
    this.checkOutDetailId,
    this.breakStartDetailId,
    this.breakEndDetailId,
    this.attendanceId,
    this.employeeUserId,
    this.employeeName,
    this.applyImmediately = false,
    this.isCreating = false,
    this.hadInitialCheckIn = false,
    this.hadInitialCheckOut = false,
    this.hadInitialBreakStart = false,
    this.hadInitialBreakEnd = false,
  });

  @override
  State<_AttendanceContent> createState() => _AttendanceContentState();
}

class _AttendanceContentState extends State<_AttendanceContent>
    with TickerProviderStateMixin {
  final Map<String, GlobalKey> _itemKeys = {
    "checkin": GlobalKey(),
    "checkout": GlobalKey(),
    "breakstart": GlobalKey(),
    "breakend": GlobalKey(),
  };

  final Map<String, double> _pickerHeights = {};

  late TimeOfDay checkIn;
  late TimeOfDay checkOut;
  late TimeOfDay breakStart;
  late TimeOfDay breakEnd;

  String? editingField;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    checkIn = widget.initialCheckIn;
    checkOut = widget.initialCheckOut;
    breakStart = widget.initialBreakStart;
    breakEnd = widget.initialBreakEnd;
  }

  String formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$min $period";
  }

  String clockHms(TimeOfDay t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:00';
  }

  /// 12:25 AM → hour 0, 8:00 PM → hour 20, 12:00 PM → hour 12.
  static int _hour24(int hour12, int periodAm0) {
    return AttendanceEditRequest.hourTo24(hour12, isPm: periodAm0 == 1);
  }

  DateTime _toDateTime(TimeOfDay t) {
    return DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      t.hour,
      t.minute,
    );
  }

  String _calculateWorkingHours() {
    var breakDur = _toDateTime(breakEnd).difference(_toDateTime(breakStart));
    if (breakDur.isNegative) breakDur = Duration.zero;
    return AttendanceFormat.duration(
      AttendanceFormat.workedDuration(
        start: _toDateTime(checkIn),
        end: _toDateTime(checkOut),
        breaks: breakDur,
      ),
    );
  }

  void openPicker(String fieldKey) async {
    setState(() {
      editingField = editingField == fieldKey ? null : fieldKey;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final contextKey = _itemKeys[fieldKey]?.currentContext;
    if (contextKey == null || !contextKey.mounted) return;

    await Scrollable.ensureVisible(
      contextKey,
      alignment: 0.35,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // 🔥 NO CHANGE BELOW (UI untouched)

  TimeOfDay _getValue(String fieldKey) {
    switch (fieldKey) {
      case "checkin":
        return checkIn;
      case "checkout":
        return checkOut;
      case "breakstart":
        return breakStart;
      case "breakend":
        return breakEnd;
      default:
        return checkIn;
    }
  }

  void _setValue(String fieldKey, TimeOfDay v) {
    setState(() {
      switch (fieldKey) {
        case "checkin":
          checkIn = v;
          break;
        case "checkout":
          checkOut = v;
          break;
        case "breakstart":
          breakStart = v;
          break;
        case "breakend":
          breakEnd = v;
          break;
      }
    });
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _apiEventType(String eventType) {
    switch (eventType) {
      case 'checkOut':
        return 'check out';
      case 'breakStart':
        return 'break out';
      case 'breakEnd':
        return 'break in';
      default:
        return 'check in';
    }
  }

  Future<
    ({
      int? attendanceId,
      String? checkInDetailId,
      String? checkOutDetailId,
      String? breakStartDetailId,
      String? breakEndDetailId,
    })
  >
  _resolveDayDetails() async {
    try {
      final scheduled = await ScheduledAttendanceTimes.load(
        apiClient: widget.apiClient,
        day: widget.day,
        employeeUserId: widget.employeeUserId,
      );
      return (
        attendanceId: scheduled.attendanceId,
        checkInDetailId: scheduled.checkInDetailId,
        checkOutDetailId: scheduled.checkOutDetailId,
        breakStartDetailId: scheduled.breakStartDetailId,
        breakEndDetailId: scheduled.breakEndDetailId,
      );
    } catch (_) {
      return (
        attendanceId: null,
        checkInDetailId: null,
        checkOutDetailId: null,
        breakStartDetailId: null,
        breakEndDetailId: null,
      );
    }
  }

  String get _sheetTitle {
    if (!widget.isCreating) return 'Edit Attendance';
    return widget.applyImmediately ? 'Add Attendance' : 'Request Attendance';
  }

  bool _timeChanged(TimeOfDay a, TimeOfDay b) =>
      a.hour != b.hour || a.minute != b.minute;

  Future<({double lat, double lon})> _currentLatLon() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return (lat: 0.0, lon: 0.0);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (lat: 0.0, lon: 0.0);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      return (lat: position.latitude, lon: position.longitude);
    } catch (_) {
      return (lat: 0.0, lon: 0.0);
    }
  }

  Future<void> handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final payloads = <AttendanceChangeRequestPayload>[];
    final localRequests = <AttendanceEditRequest>[];

    var checkInId = AttendanceDetailItem.serverDetailId(widget.checkInDetailId);
    var checkOutId = AttendanceDetailItem.serverDetailId(
      widget.checkOutDetailId,
    );
    var breakStartId = AttendanceDetailItem.serverDetailId(
      widget.breakStartDetailId,
    );
    var breakEndId = AttendanceDetailItem.serverDetailId(
      widget.breakEndDetailId,
    );
    var attendanceId = widget.attendanceId;
    var checkInHms = clockHms(widget.initialCheckIn);
    var checkOutHms = clockHms(widget.initialCheckOut);
    var breakStartHms = clockHms(widget.initialBreakStart);
    var breakEndHms = clockHms(widget.initialBreakEnd);

    final attendanceService = AttendanceService(widget.apiClient);
    try {
      final snapshot = await attendanceService.loadPunchSnapshot(
        _yyyyMMdd(widget.day),
      );
      attendanceId ??= snapshot.attendanceId;
      checkInId ??= snapshot.checkInId;
      checkOutId ??= snapshot.checkOutId;
      breakStartId ??= snapshot.breakStartId;
      breakEndId ??= snapshot.breakEndId;
      checkInHms = snapshot.checkInHms ?? checkInHms;
      checkOutHms = snapshot.checkOutHms ?? checkOutHms;
      breakStartHms = snapshot.breakStartHms ?? breakStartHms;
      breakEndHms = snapshot.breakEndHms ?? breakEndHms;
    } catch (_) {}

    if (attendanceId == null ||
        checkInId == null ||
        checkOutId == null ||
        ((widget.hadInitialBreakStart ||
                _timeChanged(widget.initialBreakStart, breakStart)) &&
            breakStartId == null) ||
        ((widget.hadInitialBreakEnd ||
                _timeChanged(widget.initialBreakEnd, breakEnd)) &&
            breakEndId == null)) {
      final resolved = await _resolveDayDetails();
      attendanceId ??= resolved.attendanceId;
      checkInId ??= resolved.checkInDetailId;
      checkOutId ??= resolved.checkOutDetailId;
      breakStartId ??= resolved.breakStartDetailId;
      breakEndId ??= resolved.breakEndDetailId;
    }

    // Employee edit/add requests need a root attendance `id` and a detail id
    // on every `changes` row. Previous-day edits often have punches but no
    // numeric detail ids from the month list — mint those rows too.
    if (!widget.applyImmediately) {
      try {
        final deviceDetails =
            (await bindings.deviceInfoService.collect()).deviceDetails;
        final gps = await _currentLatLon();
        final mint = <String>[];
        final mintCheckIn =
            widget.isCreating ||
            widget.hadInitialCheckIn ||
            _timeChanged(widget.initialCheckIn, checkIn);
        final mintCheckOut =
            widget.isCreating ||
            widget.hadInitialCheckOut ||
            _timeChanged(widget.initialCheckOut, checkOut);
        final mintBreakStart =
            widget.isCreating ||
            widget.hadInitialBreakStart ||
            _timeChanged(widget.initialBreakStart, breakStart);
        final mintBreakEnd =
            widget.isCreating ||
            widget.hadInitialBreakEnd ||
            _timeChanged(widget.initialBreakEnd, breakEnd);
        if (checkInId == null && mintCheckIn) mint.add('checkin');
        if (checkOutId == null && mintCheckOut) mint.add('checkout');
        if (breakStartId == null && mintBreakStart) mint.add('breakout');
        if (breakEndId == null && mintBreakEnd) mint.add('breakin');
        if (attendanceId == null || mint.isNotEmpty) {
          final ensured = await attendanceService.ensureAttendanceRecord(
            date: _yyyyMMdd(widget.day),
            deviceDetails: deviceDetails,
            lat: gps.lat,
            lon: gps.lon,
            attendanceId: attendanceId,
            mintActions: mint,
          );
          attendanceId = ensured.attendanceId ?? attendanceId;
          checkInId = ensured.checkInId ?? checkInId;
          checkOutId = ensured.checkOutId ?? checkOutId;
          breakStartId = ensured.breakStartId ?? breakStartId;
          breakEndId = ensured.breakEndId ?? breakEndId;
          checkInHms = ensured.checkInHms ?? checkInHms;
          checkOutHms = ensured.checkOutHms ?? checkOutHms;
          breakStartHms = ensured.breakStartHms ?? breakStartHms;
          breakEndHms = ensured.breakEndHms ?? breakEndHms;
        }
      } catch (_) {}
    }

    void maybeAdd({
      required String eventType,
      required String? detailId,
      required TimeOfDay initial,
      required TimeOfDay updated,
      required String fallbackHms,
      bool force = false,
    }) {
      if (!force && !_timeChanged(initial, updated)) return;

      final serverId = AttendanceDetailItem.serverDetailId(detailId);
      // `/edit` rejects the whole `changes` array if any row is missing
      // `attendancedetail_id` (e.g. default break times on a day with none).
      if (serverId == null) return;

      localRequests.add(
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: now,
          originalTime: widget.isCreating ? '--' : formatTime(initial),
          newTime: formatTime(updated),
          eventType: eventType,
        ),
      );

      payloads.add(
        AttendanceChangeRequestPayload(
          attendanceDetailId: serverId,
          oldValue: fallbackHms,
          newValue: clockHms(updated),
          type: _apiEventType(eventType),
        ),
      );
    }

    maybeAdd(
      eventType: 'checkIn',
      detailId: checkInId,
      initial: widget.initialCheckIn,
      updated: checkIn,
      fallbackHms: checkInHms,
    );
    maybeAdd(
      eventType: 'breakStart',
      detailId: breakStartId,
      initial: widget.initialBreakStart,
      updated: breakStart,
      fallbackHms: breakStartHms,
    );
    maybeAdd(
      eventType: 'breakEnd',
      detailId: breakEndId,
      initial: widget.initialBreakEnd,
      updated: breakEnd,
      fallbackHms: breakEndHms,
    );
    maybeAdd(
      eventType: 'checkOut',
      detailId: checkOutId,
      initial: widget.initialCheckOut,
      updated: checkOut,
      fallbackHms: checkOutHms,
    );

    if (widget.isCreating) {
      final added = localRequests.map((e) => e.eventType).toSet();
      if (!added.contains('checkIn')) {
        maybeAdd(
          eventType: 'checkIn',
          detailId: checkInId,
          initial: widget.initialCheckIn,
          updated: checkIn,
          fallbackHms: checkInHms,
          force: true,
        );
      }
      if (!added.contains('checkOut')) {
        maybeAdd(
          eventType: 'checkOut',
          detailId: checkOutId,
          initial: widget.initialCheckOut,
          updated: checkOut,
          fallbackHms: checkOutHms,
          force: true,
        );
      }
    }

    // Save with no time change: still submit the field the user was editing.
    // Creating a new day always sends check-in and check-out below.
    if (payloads.isEmpty && localRequests.isEmpty && !widget.isCreating) {
      switch (editingField ?? 'checkin') {
        case 'checkout':
          maybeAdd(
            eventType: 'checkOut',
            detailId: checkOutId,
            initial: widget.initialCheckOut,
            updated: checkOut,
            fallbackHms: checkOutHms,
            force: true,
          );
          break;
        case 'breakstart':
          maybeAdd(
            eventType: 'breakStart',
            detailId: breakStartId,
            initial: widget.initialBreakStart,
            updated: breakStart,
            fallbackHms: breakStartHms,
            force: true,
          );
          break;
        case 'breakend':
          maybeAdd(
            eventType: 'breakEnd',
            detailId: breakEndId,
            initial: widget.initialBreakEnd,
            updated: breakEnd,
            fallbackHms: breakEndHms,
            force: true,
          );
          break;
        default:
          maybeAdd(
            eventType: 'checkIn',
            detailId: checkInId,
            initial: widget.initialCheckIn,
            updated: checkIn,
            fallbackHms: checkInHms,
            force: true,
          );
      }
    }

    try {
      final deviceDetails =
          (await bindings.deviceInfoService.collect()).deviceDetails;
      final gps = await _currentLatLon();

      String clock(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

      String? clockIf(TimeOfDay time, {required bool include}) =>
          include ? clock(time) : null;

      final checkInDirty = _timeChanged(widget.initialCheckIn, checkIn);
      final checkOutDirty = _timeChanged(widget.initialCheckOut, checkOut);
      final breakStartDirty = _timeChanged(
        widget.initialBreakStart,
        breakStart,
      );
      final breakEndDirty = _timeChanged(widget.initialBreakEnd, breakEnd);

      // New attendance always sends in/out. Edits preserve existing punches
      // and only include times the user actually changed.
      final sendCheckIn =
          widget.isCreating || widget.hadInitialCheckIn || checkInDirty;
      final sendCheckOut =
          widget.isCreating || widget.hadInitialCheckOut || checkOutDirty;
      final sendBreakStart = widget.hadInitialBreakStart || breakStartDirty;
      final sendBreakEnd = widget.hadInitialBreakEnd || breakEndDirty;

      debugPrint(
        '[ManagerAttendance] handleSave userId=${widget.employeeUserId} '
        'attendanceId=$attendanceId day=${widget.day} '
        'dirty in=$checkInDirty out=$checkOutDirty '
        'break=$breakStartDirty/$breakEndDirty '
        'send in=$sendCheckIn(${checkIn.hour}:${checkIn.minute}) '
        'out=$sendCheckOut(${checkOut.hour}:${checkOut.minute})',
      );

      final validPayloads = [
        for (final payload in payloads)
          if (payload.hasDetailId) payload,
      ];

      if (!widget.applyImmediately &&
          (attendanceId == null || validPayloads.isEmpty)) {
        if (!mounted) return;
        ToastHelper.attendanceRequestSent(
          context,
          ok: false,
          message:
              'Could not submit this attendance request. Please try again.',
        );
        setState(() => _isSaving = false);
        return;
      }

      final result = widget.applyImmediately
          ? await bindings.managerAttendanceService.saveEmployeeAttendance(
              attendanceId: attendanceId,
              userId: widget.employeeUserId,
              day: widget.day,
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
              checkIn: clockIf(checkIn, include: sendCheckIn),
              checkOut: clockIf(checkOut, include: sendCheckOut),
              breakStart: clockIf(breakStart, include: sendBreakStart),
              breakEnd: clockIf(breakEnd, include: sendBreakEnd),
              checkInDetailId: checkInId,
              checkOutDetailId: checkOutId,
              breakStartDetailId: breakStartId,
              breakEndDetailId: breakEndId,
              changes: payloads,
            )
          : await attendanceService.submitAttendanceChangeRequests(
              attendanceId: attendanceId,
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
              changes: validPayloads,
              date: _yyyyMMdd(widget.day),
              // Request only — punch fields would write the times onto the
              // day before a manager approves.
              checkIn: null,
              checkOut: null,
              breakStart: null,
              breakEnd: null,
            );

      if (!mounted) return;

      final success = result.success;

      if (success &&
          !widget.applyImmediately &&
          (localRequests.isNotEmpty || widget.isCreating)) {
        final toStore = localRequests.isNotEmpty
            ? localRequests
            : [
                AttendanceEditRequest(
                  status: AttendanceEditRequestStatus.pending,
                  requestedAt: now,
                  originalTime: '--',
                  newTime: formatTime(checkIn),
                  eventType: 'checkIn',
                ),
                AttendanceEditRequest(
                  status: AttendanceEditRequestStatus.pending,
                  requestedAt: now,
                  originalTime: '--',
                  newTime: formatTime(checkOut),
                  eventType: 'checkOut',
                ),
              ];
        await AttendanceEditRequestStore.instance.addMany(
          day: widget.day,
          requests: toStore,
        );
      }

      if (!mounted) return;

      if (success) {
        final saved = AddAttendanceSaveResult(
          checkIn: (checkInDirty || widget.isCreating) ? checkIn : null,
          checkOut: (checkOutDirty || widget.isCreating) ? checkOut : null,
          breakStart: breakStartDirty ? breakStart : null,
          breakEnd: breakEndDirty ? breakEnd : null,
        );
        if (widget.applyImmediately) {
          ToastHelper.changesSaved(context);
          bindings.managerAttendanceProvider.applySavedTimes(
            userId: widget.employeeUserId,
            employeeName: widget.employeeName,
            day: widget.day,
            checkIn: saved.checkIn,
            checkOut: saved.checkOut,
          );
        } else {
          ToastHelper.attendanceRequestSent(
            context,
            ok: true,
            message: result.data,
          );
        }
        Navigator.of(context, rootNavigator: true).pop(saved);
      } else {
        if (widget.applyImmediately) {
          ToastHelper.error(
            context,
            message: result.message ?? 'Failed to update attendance.',
          );
        } else {
          ToastHelper.attendanceRequestSent(
            context,
            ok: false,
            message: result.message,
          );
        }
        setState(() => _isSaving = false);
      }
    } catch (_) {
      if (!mounted) return;
      ToastHelper.attendanceRequestSent(context, ok: false);
      setState(() => _isSaving = false);
    }
  }

  Widget timelineItem({
    required String title,
    required String value,
    required VoidCallback onTap,
    required String fieldKey,
    bool isLast = false,
    Color? valueColor,
  }) {
    final isActive = editingField == fieldKey;
    double safeHeight;
    if (!isActive) {
      safeHeight = 40;
    } else {
      final h = _pickerHeights[fieldKey];
      safeHeight = (h == null || !h.isFinite) ? 200 : h + 60;
    }
    return Container(
      key: _itemKeys[fieldKey],
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  child: Icon(Icons.circle, color: kDividerColor, size: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        AppText.p2(
                          title,
                          color: kSubText,
                          weight: FontWeight.w400,
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.all(isActive ? 12 : 0),
                          decoration: BoxDecoration(
                            color: isActive ? kbackground : kTransperentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AppText.p1(
                            value,
                            color: valueColor,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CommonImageView(
                          imagePath: Assets.imagesPen,
                          height: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isLast)
                Container(
                  width: 12,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 2,
                    height: safeHeight,
                    color: kDividerColor,
                  ),
                )
              else
                const SizedBox(width: 12),
              const SizedBox(width: 12),
              Expanded(
                child: inlinePicker(
                  fieldKey: fieldKey,
                  value: _getValue(fieldKey),
                  onChanged: (v) => _setValue(fieldKey, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget inlinePicker({
    required String fieldKey,
    required TimeOfDay value,
    required Function(TimeOfDay) onChanged,
  }) {
    int selectedHour = value.hourOfPeriod;
    int selectedMinute = value.minute;
    int selectedPeriod = value.period == DayPeriod.am ? 0 : 1;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: editingField == fieldKey
          ? AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(fieldKey),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final h = constraints.maxHeight;
                        if (h.isFinite && h > 0) {
                          _pickerHeights[fieldKey] = h;
                        }
                      });
                      return SizedBox(
                        height: 200,
                        child: SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _wheel(13, selectedHour, (v) {
                                selectedHour = v;
                                onChanged(
                                  TimeOfDay(
                                    hour: _hour24(selectedHour, selectedPeriod),
                                    minute: selectedMinute,
                                  ),
                                );
                              }),
                              _wheel(60, selectedMinute, (v) {
                                selectedMinute = v;
                                onChanged(
                                  TimeOfDay(
                                    hour: _hour24(selectedHour, selectedPeriod),
                                    minute: selectedMinute,
                                  ),
                                );
                              }),
                              _wheel(2, selectedPeriod, (v) {
                                selectedPeriod = v;
                                onChanged(
                                  TimeOfDay(
                                    hour: _hour24(selectedHour, selectedPeriod),
                                    minute: selectedMinute,
                                  ),
                                );
                              }, labels: ["AM", "PM"]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _wheel(
    int max,
    int initial,
    Function(int) onChanged, {
    List<String>? labels,
  }) {
    final bool isLooping = labels == null;
    final controller = FixedExtentScrollController(
      initialItem: isLooping ? (1000 * max + initial) : initial,
    );
    return SizedBox(
      width: 90,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            perspective: 0.0025,
            diameterRatio: 1.4,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              final realIndex = isLooping ? (val % max) : val;
              HapticFeedback.selectionClick();
              onChanged(realIndex);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: isLooping ? null : max,
              builder: (context, index) {
                final realIndex = isLooping ? (index % max) : index;
                final text = labels != null
                    ? labels[realIndex]
                    : realIndex.toString().padLeft(2, '0');
                return Center(child: AppText.p1(text, weight: FontWeight.w500));
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText.h5(_sheetTitle, weight: FontWeight.w600),
            ButtonAnimations.press(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.h5(_dateLabel(widget.day), weight: FontWeight.w600),
              CommonImageView(imagePath: Assets.imagesCalendarDay, height: 16),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            children: [
              timelineItem(
                title: "Check-in",
                value: formatTime(checkIn),
                fieldKey: "checkin",
                valueColor: Colors.green,
                onTap: () => openPicker("checkin"),
              ),
              timelineItem(
                title: "Check-out",
                value: formatTime(checkOut),
                fieldKey: "checkout",
                isLast: true,
                valueColor: Colors.red,
                onTap: () => openPicker("checkout"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kbackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.p2("Working hours", weight: FontWeight.w400),
              AppText.p2(
                _calculateWorkingHours(), // ✅ FIX
                weight: FontWeight.w400,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          spacing: 5,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 7, left: 6),
              child: CommonImageView(
                imagePath: Assets.imagesMugHotYellow,
                height: 24,
              ),
            ),
            AppText.h5("Break"),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            children: [
              timelineItem(
                title: "Break start",
                value: formatTime(breakStart),
                fieldKey: "breakstart",
                valueColor: kYellowColor,
                onTap: () => openPicker("breakstart"),
              ),
              timelineItem(
                title: "Break end",
                value: formatTime(breakEnd),
                fieldKey: "breakend",
                isLast: true,
                valueColor: kBlack,
                onTap: () => openPicker("breakend"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
