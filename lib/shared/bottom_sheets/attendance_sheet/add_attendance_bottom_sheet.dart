// ignore_for_file: non_constant_identifier_names

import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_enums.dart';
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
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
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

class _PunchPair {
  _PunchPair({
    required this.id,
    required this.start,
    required this.end,
    TimeOfDay? initialStart,
    TimeOfDay? initialEnd,
    this.startDetailId,
    this.endDetailId,
    this.hadInitialStart = false,
    this.hadInitialEnd = false,
  }) : initialStart = initialStart ?? start,
       initialEnd = initialEnd ?? end;

  final String id;
  TimeOfDay start;
  TimeOfDay end;
  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;
  String? startDetailId;
  String? endDetailId;
  final bool hadInitialStart;
  final bool hadInitialEnd;

  bool get isExtra => !hadInitialStart && !hadInitialEnd;
}

class _PairSeed {
  const _PairSeed({
    required this.start,
    required this.end,
    this.startDetailId,
    this.endDetailId,
    this.hadInitialStart = false,
    this.hadInitialEnd = false,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final String? startDetailId;
  final String? endDetailId;
  final bool hadInitialStart;
  final bool hadInitialEnd;
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
    if (!AppSheet.acquire()) return null;
    var sheetOpened = false;
    try {
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

      final seeds = await _loadPairSeeds(
        apiClient: apiClient,
        day: day,
        employeeUserId: employeeUserId,
        fallbackWork: _PairSeed(
          start: resolvedCheckIn ?? const TimeOfDay(hour: 8, minute: 0),
          end: resolvedCheckOut ?? const TimeOfDay(hour: 17, minute: 0),
          startDetailId: AttendanceDetailItem.serverDetailId(resolvedCheckInId),
          endDetailId: AttendanceDetailItem.serverDetailId(resolvedCheckOutId),
          hadInitialStart: hadInitialCheckIn || initialCheckIn != null,
          hadInitialEnd: hadInitialCheckOut || initialCheckOut != null,
        ),
        fallbackBreak: _PairSeed(
          start: resolvedBreakStart ?? const TimeOfDay(hour: 10, minute: 0),
          end: resolvedBreakEnd ?? const TimeOfDay(hour: 10, minute: 30),
          startDetailId: AttendanceDetailItem.serverDetailId(
            resolvedBreakStartId,
          ),
          endDetailId: AttendanceDetailItem.serverDetailId(resolvedBreakEndId),
          hadInitialStart: hadInitialBreakStart || initialBreakStart != null,
          hadInitialEnd: hadInitialBreakEnd || initialBreakEnd != null,
        ),
      );

      final contentKey = GlobalKey<_AttendanceContentState>();

      sheetOpened = true;
      return await CommonBottomSheet.show<AddAttendanceSaveResult>(
        context: context,
        acquired: true,
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
            initialWorkPairs: seeds.work,
            initialBreakPairs: seeds.breaks,
            attendanceId: resolvedAttendanceId,
            employeeUserId: employeeUserId,
            employeeName: employeeName,
            applyImmediately: applyNow,
            isCreating: isCreating,
          ),
        ],
      );
    } finally {
      if (!sheetOpened) AppSheet.release();
    }
  }

  static TimeOfDay _tod(DateTime t) =>
      TimeOfDay(hour: t.hour, minute: t.minute);

  static bool _sameClock(TimeOfDay a, TimeOfDay b) =>
      a.hour == b.hour && a.minute == b.minute;

  static List<_PairSeed> _zipPairs({
    required List<(TimeOfDay time, String? id, bool had)> starts,
    required List<(TimeOfDay time, String? id, bool had)> ends,
    required _PairSeed fallback,
  }) {
    final count = starts.length > ends.length ? starts.length : ends.length;
    if (count == 0) return const [];
    return [
      for (var i = 0; i < count; i++)
        _PairSeed(
          start: i < starts.length
              ? starts[i].$1
              : (starts.isNotEmpty ? starts.last.$1 : fallback.start),
          end: i < ends.length
              ? ends[i].$1
              : (ends.isNotEmpty ? ends.last.$1 : fallback.end),
          startDetailId: i < starts.length ? starts[i].$2 : null,
          endDetailId: i < ends.length ? ends[i].$2 : null,
          hadInitialStart: i < starts.length ? starts[i].$3 : false,
          hadInitialEnd: i < ends.length ? ends[i].$3 : false,
        ),
    ];
  }

  static Future<({List<_PairSeed> work, List<_PairSeed> breaks})>
  _loadPairSeeds({
    required ApiClient apiClient,
    required DateTime day,
    int? employeeUserId,
    required _PairSeed fallbackWork,
    required _PairSeed fallbackBreak,
  }) async {
    final checkIns = <(TimeOfDay, String?, bool)>[];
    final checkOuts = <(TimeOfDay, String?, bool)>[];
    final breakStarts = <(TimeOfDay, String?, bool)>[];
    final breakEnds = <(TimeOfDay, String?, bool)>[];

    void addUnique(
      List<(TimeOfDay, String?, bool)> into,
      TimeOfDay time,
      String? id, {
      required bool had,
    }) {
      for (final existing in into) {
        if (_sameClock(existing.$1, time)) return;
      }
      into.add((time, AttendanceDetailItem.serverDetailId(id), had));
    }

    if (employeeUserId == null) {
      try {
        final response = await AttendanceService(apiClient)
            .getAttendanceDetails(
              date:
                  '${day.year.toString().padLeft(4, '0')}-'
                  '${day.month.toString().padLeft(2, '0')}-'
                  '${day.day.toString().padLeft(2, '0')}',
            );
        final details = response.data?.details ?? const [];
        for (final item in details) {
          if (AttendanceEditRequest.isPlaceholderMint(item.time)) continue;
          final time = _tod(item.time);
          switch (item.type) {
            case AttendanceHisotryEventType.checkIn:
              addUnique(checkIns, time, item.id, had: true);
              break;
            case AttendanceHisotryEventType.checkOut:
              addUnique(checkOuts, time, item.id, had: true);
              break;
            case AttendanceHisotryEventType.breakStart:
              addUnique(breakStarts, time, item.id, had: true);
              break;
            case AttendanceHisotryEventType.breakEnd:
              addUnique(breakEnds, time, item.id, had: true);
              break;
          }
        }
      } catch (_) {}
    }

    try {
      final store = AttendanceEditRequestStore.instance;
      await store.ensureLoaded();
      for (final request in store.forDay(day)) {
        if (!request.isPending) continue;
        final type = AttendanceEditRequest.normalizedEventType(
          request.eventType,
        );
        final parsed = AttendanceEditRequest.parseClockTime(
          request.newTime,
          date: day,
        );
        if (type == null || parsed == null) continue;
        if (AttendanceEditRequest.isPlaceholderMint(parsed)) continue;
        final time = _tod(parsed);
        switch (type) {
          case 'checkIn':
            addUnique(checkIns, time, null, had: false);
            break;
          case 'checkOut':
            addUnique(checkOuts, time, null, had: false);
            break;
          case 'breakStart':
            addUnique(breakStarts, time, null, had: false);
            break;
          case 'breakEnd':
            addUnique(breakEnds, time, null, had: false);
            break;
        }
      }
    } catch (_) {}

    if (checkIns.isEmpty && fallbackWork.hadInitialStart) {
      addUnique(
        checkIns,
        fallbackWork.start,
        fallbackWork.startDetailId,
        had: true,
      );
    }
    if (checkOuts.isEmpty && fallbackWork.hadInitialEnd) {
      addUnique(
        checkOuts,
        fallbackWork.end,
        fallbackWork.endDetailId,
        had: true,
      );
    }
    if (breakStarts.isEmpty && fallbackBreak.hadInitialStart) {
      addUnique(
        breakStarts,
        fallbackBreak.start,
        fallbackBreak.startDetailId,
        had: true,
      );
    }
    if (breakEnds.isEmpty && fallbackBreak.hadInitialEnd) {
      addUnique(
        breakEnds,
        fallbackBreak.end,
        fallbackBreak.endDetailId,
        had: true,
      );
    }

    // Seed work/break only when real attendance exists for that section.
    // Empty sections show the "Add … Time" board instead of a placeholder card.
    if (checkIns.isEmpty &&
        checkOuts.isEmpty &&
        (fallbackWork.hadInitialStart || fallbackWork.hadInitialEnd)) {
      addUnique(
        checkIns,
        fallbackWork.start,
        fallbackWork.startDetailId,
        had: fallbackWork.hadInitialStart,
      );
      addUnique(
        checkOuts,
        fallbackWork.end,
        fallbackWork.endDetailId,
        had: fallbackWork.hadInitialEnd,
      );
    }
    if (breakStarts.isEmpty &&
        breakEnds.isEmpty &&
        (fallbackBreak.hadInitialStart || fallbackBreak.hadInitialEnd)) {
      addUnique(
        breakStarts,
        fallbackBreak.start,
        fallbackBreak.startDetailId,
        had: fallbackBreak.hadInitialStart,
      );
      addUnique(
        breakEnds,
        fallbackBreak.end,
        fallbackBreak.endDetailId,
        had: fallbackBreak.hadInitialEnd,
      );
    }

    return (
      work: _zipPairs(
        starts: checkIns,
        ends: checkOuts,
        fallback: fallbackWork,
      ),
      breaks: _zipPairs(
        starts: breakStarts,
        ends: breakEnds,
        fallback: fallbackBreak,
      ),
    );
  }
}

class _AttendanceContent extends StatefulWidget {
  final DateTime day;
  final ApiClient apiClient;
  final String userEmail;
  final List<_PairSeed> initialWorkPairs;
  final List<_PairSeed> initialBreakPairs;
  final int? attendanceId;
  final int? employeeUserId;
  final String? employeeName;
  final bool applyImmediately;
  final bool isCreating;

  const _AttendanceContent({
    super.key,
    required this.day,
    required this.apiClient,
    required this.userEmail,
    required this.initialWorkPairs,
    required this.initialBreakPairs,
    this.attendanceId,
    this.employeeUserId,
    this.employeeName,
    this.applyImmediately = false,
    this.isCreating = false,
  });

  @override
  State<_AttendanceContent> createState() => _AttendanceContentState();
}

class _AttendanceContentState extends State<_AttendanceContent>
    with TickerProviderStateMixin {
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<String, double> _pickerHeights = {};

  late final List<_PunchPair> workPairs;
  late final List<_PunchPair> breakPairs;
  int _pairSeq = 0;

  String? editingField;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    workPairs = [
      for (final seed in widget.initialWorkPairs)
        _PunchPair(
          id: 'work_${_pairSeq++}',
          start: seed.start,
          end: seed.end,
          startDetailId: seed.startDetailId,
          endDetailId: seed.endDetailId,
          hadInitialStart: seed.hadInitialStart,
          hadInitialEnd: seed.hadInitialEnd,
        ),
    ];
    breakPairs = [
      for (final seed in widget.initialBreakPairs)
        _PunchPair(
          id: 'break_${_pairSeq++}',
          start: seed.start,
          end: seed.end,
          startDetailId: seed.startDetailId,
          endDetailId: seed.endDetailId,
          hadInitialStart: seed.hadInitialStart,
          hadInitialEnd: seed.hadInitialEnd,
        ),
    ];
  }

  GlobalKey _keyFor(String fieldKey) =>
      _itemKeys.putIfAbsent(fieldKey, GlobalKey.new);

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

  String _calculateTotalHours() {
    var worked = Duration.zero;
    for (final pair in workPairs) {
      worked += AttendanceFormat.workedDuration(
        start: _toDateTime(pair.start),
        end: _toDateTime(pair.end),
      );
    }
    var breaks = Duration.zero;
    for (final pair in breakPairs) {
      var breakDur = _toDateTime(pair.end).difference(_toDateTime(pair.start));
      if (breakDur.isNegative) breakDur = Duration.zero;
      breaks += breakDur;
    }
    worked -= breaks;
    if (worked.isNegative) worked = Duration.zero;
    return AttendanceFormat.duration(worked);
  }

  void openPicker(String fieldKey) async {
    setState(() {
      editingField = editingField == fieldKey ? null : fieldKey;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final contextKey = _keyFor(fieldKey).currentContext;
    if (contextKey == null || !contextKey.mounted) return;

    await Scrollable.ensureVisible(
      contextKey,
      alignment: 0.35,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  ({String kind, String side, String id})? _parseFieldKey(String fieldKey) {
    // work_start_work_0 / break_end_break_1
    final match = RegExp(
      r'^(work|break)_(start|end)_(.+)$',
    ).firstMatch(fieldKey);
    if (match == null) return null;
    return (kind: match.group(1)!, side: match.group(2)!, id: match.group(3)!);
  }

  _PunchPair? _pairFor(String kind, String id) {
    final list = kind == 'break' ? breakPairs : workPairs;
    for (final pair in list) {
      if (pair.id == id) return pair;
    }
    return null;
  }

  TimeOfDay _getValue(String fieldKey) {
    final parsed = _parseFieldKey(fieldKey);
    final fallback = workPairs.isNotEmpty
        ? workPairs.first.start
        : const TimeOfDay(hour: 8, minute: 0);
    if (parsed == null) return fallback;
    final pair = _pairFor(parsed.kind, parsed.id);
    if (pair == null) return fallback;
    return parsed.side == 'end' ? pair.end : pair.start;
  }

  void _setValue(String fieldKey, TimeOfDay v) {
    final parsed = _parseFieldKey(fieldKey);
    if (parsed == null) return;
    setState(() {
      final pair = _pairFor(parsed.kind, parsed.id);
      if (pair == null) return;
      if (parsed.side == 'end') {
        pair.end = v;
      } else {
        pair.start = v;
      }
    });
  }

  String _fieldKey(String kind, String side, String id) =>
      '${kind}_${side}_$id';

  void _addWorkPair() {
    if (workPairs.isEmpty) {
      setState(() {
        workPairs.add(
          _PunchPair(
            id: 'work_${_pairSeq++}',
            start: const TimeOfDay(hour: 8, minute: 0),
            end: const TimeOfDay(hour: 17, minute: 0),
          ),
        );
      });
      return;
    }
    final last = workPairs.last;
    // Chain from the previous check-out so a new segment does not reuse the
    // prior check-in (avoids accidental duplicate 12:00 PM check-in requests).
    final start = last.end;
    final endMinutes = start.hour * 60 + start.minute + 60;
    final wrapped = ((endMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    setState(() {
      workPairs.add(
        _PunchPair(
          id: 'work_${_pairSeq++}',
          start: start,
          end: TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60),
        ),
      );
    });
  }

  void _addBreakPair() {
    if (breakPairs.isEmpty) {
      setState(() {
        breakPairs.add(
          _PunchPair(
            id: 'break_${_pairSeq++}',
            start: const TimeOfDay(hour: 0, minute: 0), // 12:00 AM
            end: const TimeOfDay(hour: 12, minute: 0), // 12:00 PM
          ),
        );
      });
      return;
    }
    final last = breakPairs.last;
    final startMinutes = last.end.hour * 60 + last.end.minute + 30;
    final startWrapped = ((startMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final start = TimeOfDay(
      hour: startWrapped ~/ 60,
      minute: startWrapped % 60,
    );
    final endMinutes = start.hour * 60 + start.minute + 25;
    final endWrapped = ((endMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    setState(() {
      breakPairs.add(
        _PunchPair(
          id: 'break_${_pairSeq++}',
          start: start,
          end: TimeOfDay(hour: endWrapped ~/ 60, minute: endWrapped % 60),
        ),
      );
    });
  }

  void _removeWorkPair(String id) {
    // Keep at least one check-in/out card; only extras are removable.
    if (workPairs.length <= 1) return;
    setState(() {
      workPairs.removeWhere((pair) => pair.id == id);
      if (editingField != null && editingField!.contains(id)) {
        editingField = null;
      }
    });
  }

  void _removeBreakPair(String id) {
    setState(() {
      breakPairs.removeWhere((pair) => pair.id == id);
      if (editingField != null && editingField!.contains(id)) {
        editingField = null;
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

  /// Red console dump of sheet times vs payloads actually sent to `/edit`.
  void _logAttendanceRequestRed({
    required DateTime day,
    required int? attendanceId,
    required List<_PunchPair> workPairs,
    required List<_PunchPair> breakPairs,
    required List<AttendanceChangeRequestPayload> payloads,
    required List<AttendanceChangeRequestPayload> validPayloads,
    required List<AttendanceEditRequest> localRequests,
  }) {
    const red = '\x1B[31m';
    const reset = '\x1B[0m';
    void log(String message) => debugPrint('$red$message$reset');

    log('========== ATTENDANCE REQUEST DUMP ==========');
    log('day=${_yyyyMMdd(day)} attendanceId=$attendanceId');
    log('workPairs=${workPairs.length} breakPairs=${breakPairs.length}');

    final expectedHms = <String, String>{};
    void expectEvent(String type, TimeOfDay time) {
      final hms = clockHms(time);
      expectedHms[hms] = '$type ${formatTime(time)}';
    }

    for (var i = 0; i < workPairs.length; i++) {
      final pair = workPairs[i];
      expectEvent('checkIn', pair.start);
      expectEvent('checkOut', pair.end);
      log(
        '  work[$i] ${formatTime(pair.start)} → ${formatTime(pair.end)} '
        'ids=${pair.startDetailId}/${pair.endDetailId}',
      );
    }
    for (var i = 0; i < breakPairs.length; i++) {
      final pair = breakPairs[i];
      expectEvent('breakStart', pair.start);
      expectEvent('breakEnd', pair.end);
      log(
        '  break[$i] ${formatTime(pair.start)} → ${formatTime(pair.end)} '
        'ids=${pair.startDetailId}/${pair.endDetailId}',
      );
    }

    log(
      'payloads built=${payloads.length} '
      'submitted=${validPayloads.length} '
      '(with detail id=${validPayloads.where((p) => p.hasDetailId).length})',
    );
    final sentHms = <String>{};
    for (final payload in validPayloads) {
      sentHms.add(payload.newValue);
      log(
        '  SEND ${payload.type} '
        'detail=${payload.attendanceDetailId ?? 'null'} '
        '${payload.oldValue} → ${payload.newValue}'
        '${payload.hasDetailId ? '' : ' (change_requests only)'}',
      );
    }

    for (final entry in expectedHms.entries) {
      if (!sentHms.contains(entry.key)) {
        log('  MISSING from request: ${entry.value} (new_value=${entry.key})');
      }
    }

    final dropped = [
      for (final payload in payloads)
        if (!validPayloads.contains(payload) && !payload.hasDetailId) payload,
    ];
    for (final payload in dropped) {
      log(
        '  DROPPED (no detail id) ${payload.type} '
        '${payload.oldValue} → ${payload.newValue}',
      );
    }

    log('localRequests=${localRequests.length}');
    for (final request in localRequests) {
      log(
        '  LOCAL ${request.eventType} '
        '${request.originalTime} → ${request.newTime}',
      );
    }
    log('========== END ATTENDANCE REQUEST DUMP ==========');
  }

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

  Map<String, dynamic> _managerEvent(String type, String time, String? id) {
    final payload = <String, dynamic>{'type': type, 'time': time};
    final parsedId = int.tryParse((id ?? '').trim());
    if (parsedId != null) {
      payload['id'] = parsedId;
    } else if (id != null && id.trim().isNotEmpty) {
      payload['id'] = id.trim();
    }
    return payload;
  }

  Future<void> handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    if (workPairs.isEmpty) {
      if (mounted) {
        ToastHelper.error(
          context,
          message: 'Add check-in and check-out time first.',
        );
      }
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final now = DateTime.now();
    final payloads = <AttendanceChangeRequestPayload>[];
    final localRequests = <AttendanceEditRequest>[];
    final additionalManagerEvents = <Map<String, dynamic>>[];
    final usedDetailIds = <String>{};

    final primary = workPairs.first;
    final hasBreakSection = breakPairs.isNotEmpty;
    // Placeholder only so existing break references compile when section empty;
    // break mint/submit paths are gated by [hasBreakSection].
    final primaryBreak = hasBreakSection
        ? breakPairs.first
        : _PunchPair(
            id: '__no_break__',
            start: const TimeOfDay(hour: 10, minute: 0),
            end: const TimeOfDay(hour: 10, minute: 30),
            hadInitialStart: true,
            hadInitialEnd: true,
          );

    var checkInId = AttendanceDetailItem.serverDetailId(primary.startDetailId);
    var checkOutId = AttendanceDetailItem.serverDetailId(primary.endDetailId);
    var breakStartId = AttendanceDetailItem.serverDetailId(
      primaryBreak.startDetailId,
    );
    var breakEndId = AttendanceDetailItem.serverDetailId(
      primaryBreak.endDetailId,
    );
    var attendanceId = widget.attendanceId;
    var checkInHms = clockHms(primary.initialStart);
    var checkOutHms = clockHms(primary.initialEnd);
    var breakStartHms = clockHms(primaryBreak.initialStart);
    var breakEndHms = clockHms(primaryBreak.initialEnd);

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
        (hasBreakSection &&
            (primaryBreak.hadInitialStart ||
                _timeChanged(primaryBreak.initialStart, primaryBreak.start)) &&
            breakStartId == null) ||
        (hasBreakSection &&
            (primaryBreak.hadInitialEnd ||
                _timeChanged(primaryBreak.initialEnd, primaryBreak.end)) &&
            breakEndId == null)) {
      final resolved = await _resolveDayDetails();
      attendanceId ??= resolved.attendanceId;
      checkInId ??= resolved.checkInDetailId;
      checkOutId ??= resolved.checkOutDetailId;
      breakStartId ??= resolved.breakStartDetailId;
      breakEndId ??= resolved.breakEndDetailId;
    }

    primary.startDetailId = checkInId ?? primary.startDetailId;
    primary.endDetailId = checkOutId ?? primary.endDetailId;
    if (hasBreakSection) {
      primaryBreak.startDetailId = breakStartId ?? primaryBreak.startDetailId;
      primaryBreak.endDetailId = breakEndId ?? primaryBreak.endDetailId;
    }

    for (final id in [checkInId, checkOutId, breakStartId, breakEndId]) {
      if (id != null) usedDetailIds.add(id);
    }

    // Employee edit/add requests need a root attendance `id` and a detail id
    // on every `changes` row. When the sheet has multiple work/break pairs,
    // do NOT mint the primary four punches here — a premature checkout blocks
    // a later breakout on the backend. Chronological mint below handles all
    // missing punches in state-machine order instead.
    final hasExtraPairs = workPairs.length > 1 || breakPairs.length > 1;
    if (!widget.applyImmediately) {
      try {
        final deviceDetails =
            (await bindings.deviceInfoService.collect()).deviceDetails;
        final gps = await _currentLatLon();
        final mint = <String>[];
        if (!hasExtraPairs) {
          final mintCheckIn =
              widget.isCreating ||
              primary.hadInitialStart ||
              _timeChanged(primary.initialStart, primary.start);
          final mintCheckOut =
              widget.isCreating ||
              primary.hadInitialEnd ||
              _timeChanged(primary.initialEnd, primary.end);
          final mintBreakStart =
              hasBreakSection &&
              (widget.isCreating ||
                  primaryBreak.hadInitialStart ||
                  _timeChanged(primaryBreak.initialStart, primaryBreak.start) ||
                  !primaryBreak.hadInitialStart);
          final mintBreakEnd =
              hasBreakSection &&
              (widget.isCreating ||
                  primaryBreak.hadInitialEnd ||
                  _timeChanged(primaryBreak.initialEnd, primaryBreak.end) ||
                  !primaryBreak.hadInitialEnd);
          if (checkInId == null && mintCheckIn) mint.add('checkin');
          if (checkOutId == null && mintCheckOut) mint.add('checkout');
          if (breakStartId == null && mintBreakStart) mint.add('breakout');
          if (breakEndId == null && mintBreakEnd) mint.add('breakin');
        }
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
          if (!hasExtraPairs) {
            checkInId = ensured.checkInId ?? checkInId;
            checkOutId = ensured.checkOutId ?? checkOutId;
            breakStartId = ensured.breakStartId ?? breakStartId;
            breakEndId = ensured.breakEndId ?? breakEndId;
            checkInHms = ensured.checkInHms ?? checkInHms;
            checkOutHms = ensured.checkOutHms ?? checkOutHms;
            breakStartHms = ensured.breakStartHms ?? breakStartHms;
            breakEndHms = ensured.breakEndHms ?? breakEndHms;
            primary.startDetailId = checkInId;
            primary.endDetailId = checkOutId;
            if (hasBreakSection) {
              primaryBreak.startDetailId = breakStartId;
              primaryBreak.endDetailId = breakEndId;
            }
            for (final id in [
              checkInId,
              checkOutId,
              breakStartId,
              breakEndId,
            ]) {
              if (id != null) usedDetailIds.add(id);
            }
          } else if (ensured.attendanceId != null) {
            attendanceId = ensured.attendanceId;
          }
        }
      } catch (_) {}
    }

    void maybeAdd({
      required String eventType,
      required String? detailId,
      required TimeOfDay initial,
      required TimeOfDay updated,
      required String fallbackHms,
      required bool hadInitial,
      bool force = false,
      bool allowWithoutDetailId = false,
    }) {
      if (!force && !_timeChanged(initial, updated)) return;

      final serverId = AttendanceDetailItem.serverDetailId(detailId);
      // `/edit` rejects the whole `changes` array if any row is missing
      // `attendancedetail_id`. Orphan rows still go into `change_requests`
      // so a second break can reach the portal without a minted detail id.
      if (serverId == null && !allowWithoutDetailId) return;

      final isAdd = widget.isCreating || !hadInitial;
      localRequests.add(
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: now,
          originalTime: isAdd ? '--' : formatTime(initial),
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
      if (serverId != null) usedDetailIds.add(serverId);
    }

    Future<String?> ensureExtraDetail({
      required _PunchPair pair,
      required bool isStart,
      required String action,
      required String deviceDetails,
      required double lat,
      required double lon,
    }) async {
      final existing = AttendanceDetailItem.serverDetailId(
        isStart ? pair.startDetailId : pair.endDetailId,
      );
      if (existing != null) {
        usedDetailIds.add(existing);
        return isStart
            ? '00:00:00'
            : (action == 'checkout'
                  ? '00:03:00'
                  : (action == 'breakout' ? '00:01:00' : '00:02:00'));
      }
      if (widget.applyImmediately) return null;

      final preferred = clockHms(isStart ? pair.start : pair.end);
      final minted = await attendanceService.mintAdditionalPunch(
        date: _yyyyMMdd(widget.day),
        action: action,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
        excludeDetailIds: usedDetailIds,
        preferredTimeHms: preferred,
      );
      attendanceId = minted.attendanceId ?? attendanceId;
      final id = minted.detailId;
      debugPrint(
        '\x1B[31m[AttendanceRequest] mint action=$action '
        'placeholder=${minted.hms} detailId=$id '
        'pair=${isStart ? formatTime(pair.start) : formatTime(pair.end)}'
        '\x1B[0m',
      );
      if (id == null) {
        debugPrint(
          '\x1B[31m[AttendanceRequest][MISSING] failed to mint $action '
          'for ${isStart ? formatTime(pair.start) : formatTime(pair.end)} — '
          'will still send via change_requests without detail id'
          '\x1B[0m',
        );
        return null;
      }
      usedDetailIds.add(id);
      if (isStart) {
        pair.startDetailId = id;
      } else {
        pair.endDetailId = id;
      }
      return minted.hms;
    }

    // Multi-pair request: mint every missing punch in chronological order so
    // the backend state machine still allows a second breakout (check-in →
    // … → break → … → check-out). Minting checkout before breaks fails.
    final Map<String, String> mintedFallbackHms = {};
    if (!widget.applyImmediately && hasExtraPairs) {
      try {
        final deviceDetails =
            (await bindings.deviceInfoService.collect()).deviceDetails;
        final gps = await _currentLatLon();

        final targets =
            <
              ({
                _PunchPair pair,
                bool isStart,
                String action,
                String eventType,
                TimeOfDay time,
              })
            >[];

        void addTarget({
          required _PunchPair pair,
          required bool isStart,
          required String action,
          required String eventType,
          required TimeOfDay time,
        }) {
          final existing = AttendanceDetailItem.serverDetailId(
            isStart ? pair.startDetailId : pair.endDetailId,
          );
          if (existing != null) {
            usedDetailIds.add(existing);
            return;
          }
          targets.add((
            pair: pair,
            isStart: isStart,
            action: action,
            eventType: eventType,
            time: time,
          ));
        }

        for (final pair in workPairs) {
          addTarget(
            pair: pair,
            isStart: true,
            action: 'checkin',
            eventType: 'checkIn',
            time: pair.start,
          );
          addTarget(
            pair: pair,
            isStart: false,
            action: 'checkout',
            eventType: 'checkOut',
            time: pair.end,
          );
        }
        for (final pair in breakPairs) {
          addTarget(
            pair: pair,
            isStart: true,
            action: 'breakout',
            eventType: 'breakStart',
            time: pair.start,
          );
          addTarget(
            pair: pair,
            isStart: false,
            action: 'breakin',
            eventType: 'breakEnd',
            time: pair.end,
          );
        }

        int typeOrder(String action) {
          switch (action) {
            case 'checkout':
              return 0;
            case 'checkin':
              return 1;
            case 'breakout':
              return 2;
            case 'breakin':
              return 3;
            default:
              return 4;
          }
        }

        targets.sort((a, b) {
          final aMin = a.time.hour * 60 + a.time.minute;
          final bMin = b.time.hour * 60 + b.time.minute;
          final byTime = aMin.compareTo(bMin);
          if (byTime != 0) return byTime;
          return typeOrder(a.action).compareTo(typeOrder(b.action));
        });

        debugPrint(
          '\x1B[31m[AttendanceRequest] chronological mint '
          '${targets.length} punch(es): '
          '${targets.map((t) => '${t.action}@${formatTime(t.time)}').join(' → ')}'
          '\x1B[0m',
        );

        for (final target in targets) {
          final hms = await ensureExtraDetail(
            pair: target.pair,
            isStart: target.isStart,
            action: target.action,
            deviceDetails: deviceDetails,
            lat: gps.lat,
            lon: gps.lon,
          );
          if (hms != null) {
            mintedFallbackHms['${target.eventType}:${clockHms(target.time)}'] =
                hms;
          }
        }

        checkInId = primary.startDetailId ?? checkInId;
        checkOutId = primary.endDetailId ?? checkOutId;
        if (hasBreakSection) {
          breakStartId = primaryBreak.startDetailId ?? breakStartId;
          breakEndId = primaryBreak.endDetailId ?? breakEndId;
          breakStartHms =
              mintedFallbackHms['breakStart:${clockHms(primaryBreak.start)}'] ??
              breakStartHms;
          breakEndHms =
              mintedFallbackHms['breakEnd:${clockHms(primaryBreak.end)}'] ??
              breakEndHms;
        }
        checkInHms =
            mintedFallbackHms['checkIn:${clockHms(primary.start)}'] ??
            checkInHms;
        checkOutHms =
            mintedFallbackHms['checkOut:${clockHms(primary.end)}'] ??
            checkOutHms;
      } catch (_) {}
    }

    // Primary pair — same change-request path as before.
    maybeAdd(
      eventType: 'checkIn',
      detailId: checkInId,
      initial: primary.initialStart,
      updated: primary.start,
      fallbackHms: checkInHms,
      hadInitial: primary.hadInitialStart,
    );
    if (hasBreakSection) {
      maybeAdd(
        eventType: 'breakStart',
        detailId: breakStartId,
        initial: primaryBreak.initialStart,
        updated: primaryBreak.start,
        fallbackHms: breakStartHms,
        hadInitial: primaryBreak.hadInitialStart,
      );
      maybeAdd(
        eventType: 'breakEnd',
        detailId: breakEndId,
        initial: primaryBreak.initialEnd,
        updated: primaryBreak.end,
        fallbackHms: breakEndHms,
        hadInitial: primaryBreak.hadInitialEnd,
      );
    }
    maybeAdd(
      eventType: 'checkOut',
      detailId: checkOutId,
      initial: primary.initialEnd,
      updated: primary.end,
      fallbackHms: checkOutHms,
      hadInitial: primary.hadInitialEnd,
    );

    if (widget.isCreating) {
      final added = localRequests.map((e) => e.eventType).toSet();
      if (!added.contains('checkIn')) {
        maybeAdd(
          eventType: 'checkIn',
          detailId: checkInId,
          initial: primary.initialStart,
          updated: primary.start,
          fallbackHms: checkInHms,
          hadInitial: primary.hadInitialStart,
          force: true,
        );
      }
      if (!added.contains('checkOut')) {
        maybeAdd(
          eventType: 'checkOut',
          detailId: checkOutId,
          initial: primary.initialEnd,
          updated: primary.end,
          fallbackHms: checkOutHms,
          hadInitial: primary.hadInitialEnd,
          force: true,
        );
      }
      // Only request break when the user added a break card on the sheet.
      if (hasBreakSection) {
        if (!added.contains('breakStart')) {
          maybeAdd(
            eventType: 'breakStart',
            detailId: breakStartId ?? primaryBreak.startDetailId,
            initial: primaryBreak.initialStart,
            updated: primaryBreak.start,
            fallbackHms: breakStartHms,
            hadInitial: primaryBreak.hadInitialStart,
            force: true,
          );
        }
        if (!added.contains('breakEnd')) {
          maybeAdd(
            eventType: 'breakEnd',
            detailId: breakEndId ?? primaryBreak.endDetailId,
            initial: primaryBreak.initialEnd,
            updated: primaryBreak.end,
            fallbackHms: breakEndHms,
            hadInitial: primaryBreak.hadInitialEnd,
            force: true,
          );
        }
      }
    }

    // When the user added extra break rows, also ensure the primary break
    // pair is included in the request (even if left at the scheduled default).
    if (!widget.applyImmediately && hasBreakSection && breakPairs.length > 1) {
      final added = localRequests.map((e) => e.eventType).toSet();
      if (!added.contains('breakStart')) {
        maybeAdd(
          eventType: 'breakStart',
          detailId: breakStartId ?? primaryBreak.startDetailId,
          initial: primaryBreak.initialStart,
          updated: primaryBreak.start,
          fallbackHms: breakStartHms,
          hadInitial: primaryBreak.hadInitialStart,
          force: true,
        );
      }
      if (!added.contains('breakEnd')) {
        maybeAdd(
          eventType: 'breakEnd',
          detailId: breakEndId ?? primaryBreak.endDetailId,
          initial: primaryBreak.initialEnd,
          updated: primaryBreak.end,
          fallbackHms: breakEndHms,
          hadInitial: primaryBreak.hadInitialEnd,
          force: true,
        );
      }
    }

    // Include new break times when a break card is on the sheet and other
    // changes are already being submitted.
    if (!widget.applyImmediately &&
        hasBreakSection &&
        (!primaryBreak.hadInitialStart || !primaryBreak.hadInitialEnd) &&
        payloads.isNotEmpty) {
      final added = localRequests.map((e) => e.eventType).toSet();
      if (!primaryBreak.hadInitialStart && !added.contains('breakStart')) {
        maybeAdd(
          eventType: 'breakStart',
          detailId: breakStartId ?? primaryBreak.startDetailId,
          initial: primaryBreak.initialStart,
          updated: primaryBreak.start,
          fallbackHms: breakStartHms,
          hadInitial: false,
          force: true,
        );
      }
      if (!primaryBreak.hadInitialEnd && !added.contains('breakEnd')) {
        maybeAdd(
          eventType: 'breakEnd',
          detailId: breakEndId ?? primaryBreak.endDetailId,
          initial: primaryBreak.initialEnd,
          updated: primaryBreak.end,
          fallbackHms: breakEndHms,
          hadInitial: false,
          force: true,
        );
      }
    }

    // Save with no time change: still submit the field the user was editing.
    if (payloads.isEmpty && localRequests.isEmpty && !widget.isCreating) {
      final editing = editingField ?? '';
      if (hasBreakSection &&
          editing.contains('break') &&
          editing.contains('end')) {
        maybeAdd(
          eventType: 'breakEnd',
          detailId: breakEndId,
          initial: primaryBreak.initialEnd,
          updated: primaryBreak.end,
          fallbackHms: breakEndHms,
          hadInitial: primaryBreak.hadInitialEnd,
          force: true,
        );
      } else if (hasBreakSection && editing.contains('break')) {
        maybeAdd(
          eventType: 'breakStart',
          detailId: breakStartId,
          initial: primaryBreak.initialStart,
          updated: primaryBreak.start,
          fallbackHms: breakStartHms,
          hadInitial: primaryBreak.hadInitialStart,
          force: true,
        );
      } else if (editing.contains('end')) {
        maybeAdd(
          eventType: 'checkOut',
          detailId: checkOutId,
          initial: primary.initialEnd,
          updated: primary.end,
          fallbackHms: checkOutHms,
          hadInitial: primary.hadInitialEnd,
          force: true,
        );
      } else {
        maybeAdd(
          eventType: 'checkIn',
          detailId: checkInId,
          initial: primary.initialStart,
          updated: primary.start,
          fallbackHms: checkInHms,
          hadInitial: primary.hadInitialStart,
          force: true,
        );
      }
    }

    try {
      final deviceDetails =
          (await bindings.deviceInfoService.collect()).deviceDetails;
      final gps = await _currentLatLon();

      // Extra work / break pairs beyond the primary.
      for (var i = 1; i < workPairs.length; i++) {
        final pair = workPairs[i];
        if (widget.applyImmediately) {
          additionalManagerEvents.add(
            _managerEvent('checkin', clockHms(pair.start), pair.startDetailId),
          );
          additionalManagerEvents.add(
            _managerEvent('checkout', clockHms(pair.end), pair.endDetailId),
          );
          localRequests.add(
            AttendanceEditRequest(
              status: AttendanceEditRequestStatus.pending,
              requestedAt: now,
              originalTime: '--',
              newTime: formatTime(pair.start),
              eventType: 'checkIn',
            ),
          );
          localRequests.add(
            AttendanceEditRequest(
              status: AttendanceEditRequestStatus.pending,
              requestedAt: now,
              originalTime: '--',
              newTime: formatTime(pair.end),
              eventType: 'checkOut',
            ),
          );
        } else {
          // Multi-pair days already minted chronologically above.
          if (!hasExtraPairs) {
            await ensureExtraDetail(
              pair: pair,
              isStart: true,
              action: 'checkin',
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
            );
            await ensureExtraDetail(
              pair: pair,
              isStart: false,
              action: 'checkout',
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
            );
          }
          maybeAdd(
            eventType: 'checkIn',
            detailId: pair.startDetailId,
            initial: pair.initialStart,
            updated: pair.start,
            fallbackHms:
                mintedFallbackHms['checkIn:${clockHms(pair.start)}'] ??
                '00:00:00',
            hadInitial: false,
            force: true,
          );
          maybeAdd(
            eventType: 'checkOut',
            detailId: pair.endDetailId,
            initial: pair.initialEnd,
            updated: pair.end,
            fallbackHms:
                mintedFallbackHms['checkOut:${clockHms(pair.end)}'] ??
                '00:03:00',
            hadInitial: false,
            force: true,
          );
        }
      }

      for (var i = 1; i < breakPairs.length; i++) {
        final pair = breakPairs[i];
        if (widget.applyImmediately) {
          additionalManagerEvents.add(
            _managerEvent('breakout', clockHms(pair.start), pair.startDetailId),
          );
          additionalManagerEvents.add(
            _managerEvent('breakin', clockHms(pair.end), pair.endDetailId),
          );
          localRequests.add(
            AttendanceEditRequest(
              status: AttendanceEditRequestStatus.pending,
              requestedAt: now,
              originalTime: '--',
              newTime: formatTime(pair.start),
              eventType: 'breakStart',
            ),
          );
          localRequests.add(
            AttendanceEditRequest(
              status: AttendanceEditRequestStatus.pending,
              requestedAt: now,
              originalTime: '--',
              newTime: formatTime(pair.end),
              eventType: 'breakEnd',
            ),
          );
        } else {
          if (!hasExtraPairs) {
            await ensureExtraDetail(
              pair: pair,
              isStart: true,
              action: 'breakout',
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
            );
            await ensureExtraDetail(
              pair: pair,
              isStart: false,
              action: 'breakin',
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
            );
          }
          maybeAdd(
            eventType: 'breakStart',
            detailId: pair.startDetailId,
            initial: pair.initialStart,
            updated: pair.start,
            fallbackHms:
                mintedFallbackHms['breakStart:${clockHms(pair.start)}'] ??
                '00:01:00',
            hadInitial: false,
            force: true,
            allowWithoutDetailId: true,
          );
          maybeAdd(
            eventType: 'breakEnd',
            detailId: pair.endDetailId,
            initial: pair.initialEnd,
            updated: pair.end,
            fallbackHms:
                mintedFallbackHms['breakEnd:${clockHms(pair.end)}'] ??
                '00:02:00',
            hadInitial: false,
            force: true,
            allowWithoutDetailId: true,
          );
        }
      }

      String clock(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

      String? clockIf(TimeOfDay time, {required bool include}) =>
          include ? clock(time) : null;

      final checkInDirty = _timeChanged(primary.initialStart, primary.start);
      final checkOutDirty = _timeChanged(primary.initialEnd, primary.end);
      final breakStartDirty =
          hasBreakSection &&
          _timeChanged(primaryBreak.initialStart, primaryBreak.start);
      final breakEndDirty =
          hasBreakSection &&
          _timeChanged(primaryBreak.initialEnd, primaryBreak.end);

      final sendCheckIn =
          widget.isCreating || primary.hadInitialStart || checkInDirty;
      final sendCheckOut =
          widget.isCreating || primary.hadInitialEnd || checkOutDirty;
      final sendBreakStart =
          hasBreakSection && (primaryBreak.hadInitialStart || breakStartDirty);
      final sendBreakEnd =
          hasBreakSection && (primaryBreak.hadInitialEnd || breakEndDirty);

      debugPrint(
        '[ManagerAttendance] handleSave userId=${widget.employeeUserId} '
        'attendanceId=$attendanceId day=${widget.day} '
        'dirty in=$checkInDirty out=$checkOutDirty '
        'break=$breakStartDirty/$breakEndDirty '
        'extras work=${workPairs.length} break=${breakPairs.length} '
        'send in=$sendCheckIn(${primary.start.hour}:${primary.start.minute}) '
        'out=$sendCheckOut(${primary.end.hour}:${primary.end.minute})',
      );

      // Submit in chronological sequence so portal pending rows match the
      // employee's event order (9:00 → … → 6:00).
      int payloadMinutes(AttendanceChangeRequestPayload p) {
        final parts = p.newValue.split(':');
        if (parts.length < 2) return 0;
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }

      int payloadTypeOrder(AttendanceChangeRequestPayload p) {
        switch (p.type?.toLowerCase()) {
          case 'check out':
          case 'checkout':
            return 0;
          case 'check in':
          case 'checkin':
            return 1;
          case 'break out':
          case 'breakout':
            return 2;
          case 'break in':
          case 'breakin':
            return 3;
          default:
            return 4;
        }
      }

      final validPayloads =
          [
            for (final payload in payloads)
              if (payload.hasDetailId) payload,
          ]..sort((a, b) {
            final byTime = payloadMinutes(a).compareTo(payloadMinutes(b));
            if (byTime != 0) return byTime;
            return payloadTypeOrder(a).compareTo(payloadTypeOrder(b));
          });

      // Orphan break rows (no detail id) still go in change_requests.
      final submitPayloads = [
        ...validPayloads,
        for (final payload in payloads)
          if (!payload.hasDetailId) payload,
      ];

      localRequests.sort((a, b) {
        final aTime =
            AttendanceEditRequest.parseClockTime(a.newTime, date: widget.day) ??
            a.requestedAt;
        final bTime =
            AttendanceEditRequest.parseClockTime(b.newTime, date: widget.day) ??
            b.requestedAt;
        final byTime = aTime.compareTo(bTime);
        if (byTime != 0) return byTime;
        return (a.eventType ?? '').compareTo(b.eventType ?? '');
      });

      _logAttendanceRequestRed(
        day: widget.day,
        attendanceId: attendanceId,
        workPairs: workPairs,
        breakPairs: breakPairs,
        payloads: payloads,
        validPayloads: submitPayloads,
        localRequests: localRequests,
      );

      if (!widget.applyImmediately &&
          (attendanceId == null ||
              (validPayloads.isEmpty &&
                  submitPayloads.isEmpty &&
                  !hasExtraPairs))) {
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

      if (!widget.applyImmediately &&
          attendanceId == null &&
          validPayloads.isEmpty &&
          submitPayloads.isEmpty) {
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
              checkIn: clockIf(primary.start, include: sendCheckIn),
              checkOut: clockIf(primary.end, include: sendCheckOut),
              breakStart: clockIf(primaryBreak.start, include: sendBreakStart),
              breakEnd: clockIf(primaryBreak.end, include: sendBreakEnd),
              checkInDetailId: checkInId,
              checkOutDetailId: checkOutId,
              breakStartDetailId: breakStartId,
              breakEndDetailId: breakEndId,
              additionalEvents: additionalManagerEvents,
              changes: payloads,
            )
          : await attendanceService.submitAttendanceChangeRequests(
              attendanceId: attendanceId,
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
              changes: submitPayloads,
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
                  newTime: formatTime(primary.start),
                  eventType: 'checkIn',
                ),
                AttendanceEditRequest(
                  status: AttendanceEditRequestStatus.pending,
                  requestedAt: now,
                  originalTime: '--',
                  newTime: formatTime(primary.end),
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
          checkIn: (checkInDirty || widget.isCreating) ? primary.start : null,
          checkOut: (checkOutDirty || widget.isCreating) ? primary.end : null,
          breakStart: breakStartDirty ? primaryBreak.start : null,
          breakEnd: breakEndDirty ? primaryBreak.end : null,
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
      key: _keyFor(fieldKey),
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

  Widget _pairCard({
    required _PunchPair pair,
    required String kind,
    required String startTitle,
    required String endTitle,
    required Color startColor,
    required Color endColor,
  }) {
    final startKey = _fieldKey(kind, 'start', pair.id);
    final endKey = _fieldKey(kind, 'end', pair.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          timelineItem(
            title: startTitle,
            value: formatTime(pair.start),
            fieldKey: startKey,
            valueColor: startColor,
            onTap: () => openPicker(startKey),
          ),
          timelineItem(
            title: endTitle,
            value: formatTime(pair.end),
            fieldKey: endKey,
            isLast: true,
            valueColor: endColor,
            onTap: () => openPicker(endKey),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required String iconPath,
    required VoidCallback onTap,
    bool showIcon = true,
  }) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              CommonImageView(imagePath: iconPath, height: 16),
              const SizedBox(width: 6),
            ],
            AppText.p2(label, weight: FontWeight.w500, color: kSubText),
          ],
        ),
      ),
    );
  }

  Widget _emptyBoard({
    required String label,
    required VoidCallback onTap,
    String? iconPath,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Center(
        child: _pillButton(
          label: label,
          iconPath: iconPath ?? Assets.imagesClockGrey,
          showIcon: iconPath != null,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _removeIconButton(VoidCallback onTap) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CommonImageView(imagePath: Assets.TrashBin, height: 28),
      ),
    );
  }

  Widget _pairActionsRow({
    Widget? leading,
    bool showRemove = false,
    VoidCallback? onRemove,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) leading,
        const Spacer(),
        if (showRemove && onRemove != null) _removeIconButton(onRemove),
      ],
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
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),

        Row(
          spacing: 5,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: CommonImageView(
                imagePath: Assets.navigationActiveClockIcon,
                height: 20,
              ),
            ),
            AppText.h5('Check In'),
          ],
        ),
        const SizedBox(height: 10),

        if (workPairs.isEmpty)
          _emptyBoard(label: 'Add Check and out Time', onTap: _addWorkPair)
        else ...[
          for (var i = 0; i < workPairs.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _pairCard(
              pair: workPairs[i],
              kind: 'work',
              startTitle: 'Check-in',
              endTitle: 'Check-out',
              startColor: Colors.green,
              endColor: Colors.red,
            ),
          ],
          const SizedBox(height: 12),
          _pairActionsRow(
            leading: _pillButton(
              label: 'Add more',
              iconPath: Assets.imagesClockGrey,
              onTap: _addWorkPair,
            ),
            // Only the latest newly added check-in card shows remove.
            showRemove: workPairs.last.isExtra,
            onRemove: () => _removeWorkPair(workPairs.last.id),
          ),
        ],

        const SizedBox(height: 30),
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

        if (breakPairs.isEmpty)
          _emptyBoard(
            label: 'Add break Time',
            iconPath: Assets.imagesMugHot,
            onTap: _addBreakPair,
          )
        else ...[
          for (var i = 0; i < breakPairs.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _pairCard(
              pair: breakPairs[i],
              kind: 'break',
              startTitle: 'Break start',
              endTitle: 'Break end',
              startColor: kYellowColor,
              endColor: kYellowColor,
            ),
            const SizedBox(height: 8),
            _pairActionsRow(
              leading: i == breakPairs.length - 1
                  ? _pillButton(
                      label: 'Add break',
                      iconPath: Assets.imagesMugHot,
                      onTap: _addBreakPair,
                    )
                  : null,
              // Existing breaks stay removable; extras too.
              showRemove: true,
              onRemove: () => _removeBreakPair(breakPairs[i].id),
            ),
          ],
        ],

        if (workPairs.isNotEmpty) ...[
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.p2('Total hours', weight: FontWeight.w400),
              AppText.p2(_calculateTotalHours(), weight: FontWeight.w600),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
