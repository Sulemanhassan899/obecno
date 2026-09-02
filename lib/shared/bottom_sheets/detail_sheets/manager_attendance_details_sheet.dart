import 'dart:async';

import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/core/utils/maps_launcher.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/attendance_duration.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_profile_sheet.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

/// Timeline event types for manager attendance details.
enum ManagerAttendanceEventType {
  checkIn,
  checkOut,
  breakStart,
  breakEnd,
  reminder,
}

class ManagerAttendanceTimelineEvent {
  const ManagerAttendanceTimelineEvent({
    required this.type,
    required this.timeLabel,
    this.id,
    this.location,
    this.lat,
    this.lon,
    this.reminderText,
    this.sortTime,
  });

  final ManagerAttendanceEventType type;
  final String timeLabel;
  final String? id;
  final String? location;
  final double? lat;
  final double? lon;
  final String? reminderText;
  final DateTime? sortTime;

  bool get hasCoordinates => lat != null && lon != null;

  String get label {
    switch (type) {
      case ManagerAttendanceEventType.checkIn:
        return "Check-In";
      case ManagerAttendanceEventType.checkOut:
        return "Check-Out";
      case ManagerAttendanceEventType.breakStart:
        return "Break Start";
      case ManagerAttendanceEventType.breakEnd:
        return "Break End";
      case ManagerAttendanceEventType.reminder:
        return reminderText ?? "Please Check-In";
    }
  }

  Color get color {
    switch (type) {
      case ManagerAttendanceEventType.checkIn:
        return kPrimaryColor;
      case ManagerAttendanceEventType.checkOut:
        return kredColor;
      case ManagerAttendanceEventType.breakStart:
      case ManagerAttendanceEventType.breakEnd:
        return kYellowColor;
      case ManagerAttendanceEventType.reminder:
        return kGreyColor;
    }
  }
}

class ManagerAttendanceDetailsData {
  const ManagerAttendanceDetailsData({
    required this.day,
    required this.name,
    this.role,
    this.photo,
    this.userId,
    this.attendanceId,
    this.checkIn,
    this.checkOut,
    this.checkInLocation,
    this.checkOutLocation,
    this.checkInLat,
    this.checkInLon,
    this.checkOutLat,
    this.checkOutLon,
    this.durationLabel = "0h 00m",
    this.timeline = const [],
  });

  final DateTime day;
  final String name;
  final String? role;
  final String? photo;
  final int? userId;
  final int? attendanceId;
  final String? checkIn;
  final String? checkOut;
  final String? checkInLocation;
  final String? checkOutLocation;
  final double? checkInLat;
  final double? checkInLon;
  final double? checkOutLat;
  final double? checkOutLon;
  final String durationLabel;
  final List<ManagerAttendanceTimelineEvent> timeline;

  bool get hasAttendance =>
      (checkIn != null && checkIn!.trim().isNotEmpty) ||
      (checkOut != null && checkOut!.trim().isNotEmpty) ||
      timeline.isNotEmpty;

  bool get hasNetworkPhoto =>
      photo != null &&
      photo!.isNotEmpty &&
      !photo!.startsWith('assets/') &&
      (photo!.startsWith('http://') ||
          photo!.startsWith('https://') ||
          photo!.startsWith('//') ||
          photo!.startsWith('/'));

  String get photoPath =>
      (photo != null && photo!.isNotEmpty) ? photo! : Assets.imagesUserimage;

  ManagerAttendanceDetailsData copyWith({
    String? photo,
    int? userId,
    int? attendanceId,
    String? checkIn,
    String? checkOut,
    String? durationLabel,
    List<ManagerAttendanceTimelineEvent>? timeline,
  }) {
    return ManagerAttendanceDetailsData(
      day: day,
      name: name,
      role: role,
      photo: photo ?? this.photo,
      userId: userId ?? this.userId,
      attendanceId: attendanceId ?? this.attendanceId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      checkInLocation: checkInLocation,
      checkOutLocation: checkOutLocation,
      checkInLat: checkInLat,
      checkInLon: checkInLon,
      checkOutLat: checkOutLat,
      checkOutLon: checkOutLon,
      durationLabel: durationLabel ?? this.durationLabel,
      timeline: timeline ?? this.timeline,
    );
  }

  ManagerAttendanceDetailsData withSavedTimes(AddAttendanceSaveResult saved) {
    final checkInLabel = saved.checkIn == null
        ? checkIn
        : _labelFromTime(saved.checkIn!);
    final checkOutLabel = saved.checkOut == null
        ? checkOut
        : _labelFromTime(saved.checkOut!);
    var nextTimeline = timeline;
    if (saved.checkIn != null) {
      nextTimeline = _upsertClock(
        nextTimeline,
        type: ManagerAttendanceEventType.checkIn,
        time: saved.checkIn!,
      );
    }
    if (saved.checkOut != null) {
      nextTimeline = _upsertClock(
        nextTimeline,
        type: ManagerAttendanceEventType.checkOut,
        time: saved.checkOut!,
      );
    }
    if (saved.breakStart != null) {
      nextTimeline = _upsertClock(
        nextTimeline,
        type: ManagerAttendanceEventType.breakStart,
        time: saved.breakStart!,
      );
    }
    if (saved.breakEnd != null) {
      nextTimeline = _upsertClock(
        nextTimeline,
        type: ManagerAttendanceEventType.breakEnd,
        time: saved.breakEnd!,
      );
    }
    nextTimeline = [...nextTimeline]
      ..sort((a, b) {
        final left = a.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });

    return copyWith(
      checkIn: checkInLabel,
      checkOut: checkOutLabel,
      durationLabel: AttendanceDuration.label(
        day: day,
        checkIn: checkInLabel,
        checkOut: checkOutLabel,
      ),
      timeline: nextTimeline,
    );
  }

  List<ManagerAttendanceTimelineEvent> _upsertClock(
    List<ManagerAttendanceTimelineEvent> events, {
    required ManagerAttendanceEventType type,
    required TimeOfDay time,
  }) {
    final label = _labelFromTime(time);
    final sortTime = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    final index = events.indexWhere((event) => event.type == type);
    final previous = index >= 0 ? events[index] : null;
    final event = ManagerAttendanceTimelineEvent(
      type: type,
      timeLabel: label,
      id: previous?.id,
      location: previous?.location,
      lat: previous?.lat,
      lon: previous?.lon,
      sortTime: sortTime,
    );
    if (index < 0) return [...events, event];
    final next = [...events];
    next[index] = event;
    return next;
  }

  static String _labelFromTime(TimeOfDay time) {
    return TeamAttendanceMapper.formatTime(
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}:00',
        ) ??
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static String formatFullDate(DateTime d) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  /// Builds details from a list tile + selected day. Timeline events are
  /// filled in from `/manager/employees/{id}/attendance` when [loadDetails]
  /// runs.
  factory ManagerAttendanceDetailsData.fromEmployee({
    required ManagerAttendanceModel employee,
    required DateTime day,
  }) {
    final checkIn = _usableTime(employee.checkIn);
    final checkOut = _usableTime(employee.checkOut);
    final hasTimes = checkIn != null || checkOut != null;
    final status = employee.status.toLowerCase().trim();
    final isLeave = status == "leave" || status == "on leave";

    if (!hasTimes || isLeave) {
      return ManagerAttendanceDetailsData(
        day: day,
        name: employee.name,
        role: employee.role ?? "Employee",
        photo: employee.photo,
        userId: employee.userId,
        attendanceId: employee.attendanceId,
        durationLabel: "0h 00m",
      );
    }

    return ManagerAttendanceDetailsData(
      day: day,
      name: employee.name,
      role: employee.role ?? "Employee",
      photo: employee.photo,
      userId: employee.userId,
      attendanceId: employee.attendanceId,
      checkIn: checkIn,
      checkOut: checkOut,
      durationLabel: AttendanceDuration.label(
        day: day,
        checkIn: checkIn,
        checkOut: checkOut,
      ),
      timeline: [
        if (checkOut != null && checkOut.trim().isNotEmpty)
          ManagerAttendanceTimelineEvent(
            type: ManagerAttendanceEventType.checkOut,
            timeLabel: checkOut,
          ),
        if (checkIn != null && checkIn.trim().isNotEmpty)
          ManagerAttendanceTimelineEvent(
            type: ManagerAttendanceEventType.checkIn,
            timeLabel: checkIn,
          ),
      ],
    );
  }

  static String? _usableTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'leave' ||
        lower == 'holiday' ||
        lower == '--' ||
        lower.startsWith('--:--')) {
      return null;
    }
    return value;
  }
}

class ManagerAttendanceDetailsSheet {
  ManagerAttendanceDetailsSheet._();

  static Future<AddAttendanceSaveResult?> show({
    required BuildContext context,
    required ManagerAttendanceDetailsData data,
    Future<ManagerAttendanceDetailsData> Function()? loadDetails,
    VoidCallback? onProfileTap,
    VoidCallback? onAttendanceTap,
    VoidCallback? onAddAttendance,
    VoidCallback? onEditAttendance,
  }) {
    return showModalBottomSheet<AddAttendanceSaveResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ManagerAttendanceDetailsSheetBody(
        data: data,
        loadDetails: loadDetails,
        onProfileTap: onProfileTap,
        onAttendanceTap: onAttendanceTap,
        onAddAttendance: onAddAttendance,
        onEditAttendance: onEditAttendance,
      ),
    );
  }
}

class _ManagerAttendanceDetailsSheetBody extends StatefulWidget {
  const _ManagerAttendanceDetailsSheetBody({
    required this.data,
    this.loadDetails,
    this.onProfileTap,
    this.onAttendanceTap,
    this.onAddAttendance,
    this.onEditAttendance,
  });

  final ManagerAttendanceDetailsData data;
  final Future<ManagerAttendanceDetailsData> Function()? loadDetails;
  final VoidCallback? onProfileTap;
  final VoidCallback? onAttendanceTap;
  final VoidCallback? onAddAttendance;
  final VoidCallback? onEditAttendance;

  @override
  State<_ManagerAttendanceDetailsSheetBody> createState() =>
      _ManagerAttendanceDetailsSheetBodyState();
}

class _ManagerAttendanceDetailsSheetBodyState
    extends State<_ManagerAttendanceDetailsSheetBody> {
  late ManagerAttendanceDetailsData _data;
  bool _loading = false;
  Timer? _hoursTimer;
  AddAttendanceSaveResult? _savedResult;

  DateTime? _joiningDateFor(int? userId) {
    if (userId == null) return null;
    for (final member in bindings.managerEmployeesProvider.members) {
      if (member.userId == userId) return member.joiningDate;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _syncHoursTimer();
    _load();
  }

  @override
  void dispose() {
    _hoursTimer?.cancel();
    super.dispose();
  }

  bool get _isOpenShift {
    final checkIn = _data.checkIn?.trim() ?? '';
    final checkOut = _data.checkOut?.trim() ?? '';
    return checkIn.isNotEmpty && checkOut.isEmpty;
  }

  String get _durationLabel => AttendanceDuration.label(
    day: _data.day,
    checkIn: _data.checkIn,
    checkOut: _data.checkOut,
    hoursWorked: _data.durationLabel == '0h 00m' ? null : _data.durationLabel,
  );

  void _syncHoursTimer() {
    _hoursTimer?.cancel();
    if (!_isOpenShift) return;
    _hoursTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _load({bool silent = false}) async {
    final loader = widget.loadDetails;
    if (loader == null) return;
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final next = await loader();
      if (!mounted) return;
      setState(() {
        _data = _savedResult == null
            ? next
            : next.withSavedTimes(_savedResult!);
        _loading = false;
      });
      _syncHoursTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openProfile() {
    if (widget.onProfileTap != null) {
      widget.onProfileTap!();
      return;
    }
    ManagerEmployeeProfileSheet.show(context: context, data: _data);
  }

  void _openAttendance() {
    if (widget.onAttendanceTap != null) {
      widget.onAttendanceTap!();
      return;
    }
    ManagerEmployeeAttendanceSheet.show(
      context: context,
      employeeName: _data.name,
      userId: _data.userId,
      role: _data.role,
      photo: _data.photo,
      joiningDate: _joiningDateFor(_data.userId),
    );
  }

  void _openEditor({required bool isAdd}) async {
    if (widget.onEditAttendance != null && !isAdd) {
      widget.onEditAttendance!();
      return;
    }
    if (widget.onAddAttendance != null && isAdd) {
      widget.onAddAttendance!();
      return;
    }

    final checkIn = _eventOf(ManagerAttendanceEventType.checkIn, latest: false);
    final checkOut = _eventOf(
      ManagerAttendanceEventType.checkOut,
      latest: true,
    );
    final breakStart = _eventOf(
      ManagerAttendanceEventType.breakStart,
      latest: false,
    );
    final breakEnd = _eventOf(
      ManagerAttendanceEventType.breakEnd,
      latest: true,
    );

    final saved = await AddAttendanceBottomSheet.show(
      context,
      day: _data.day,
      apiClient: bindings.apiClient,
      userEmail: bindings.userEmail,
      attendanceId: _data.attendanceId,
      employeeUserId: _data.userId,
      employeeName: _data.name,
      applyImmediately:
          bindings.authProvider.homeTarget == AuthHomeTarget.manager,
      initialCheckIn: _timeOfDay(checkIn),
      initialCheckOut: _timeOfDay(checkOut),
      initialBreakStart: _timeOfDay(breakStart),
      initialBreakEnd: _timeOfDay(breakEnd),
      checkInDetailId: checkIn?.id,
      checkOutDetailId: checkOut?.id,
      breakStartDetailId: breakStart?.id,
      breakEndDetailId: breakEnd?.id,
    );
    if (saved != null && mounted) {
      debugPrint(
        '[ManagerAttendance] details saved ${_data.name}/${_data.userId} '
        'in=${saved.checkIn} out=${saved.checkOut}',
      );
      _savedResult = saved;
      setState(() {
        _data = _data.withSavedTimes(saved);
        _loading = false;
      });
      _syncHoursTimer();
      bindings.managerAttendanceProvider.applySavedTimes(
        userId: _data.userId,
        employeeName: _data.name,
        day: _data.day,
        checkIn: saved.checkIn,
        checkOut: saved.checkOut,
      );
      await _load(silent: true);
    }
  }

  ManagerAttendanceTimelineEvent? _eventOf(
    ManagerAttendanceEventType type, {
    required bool latest,
  }) {
    ManagerAttendanceTimelineEvent? found;
    for (final event in _data.timeline) {
      if (event.type != type) continue;
      if (found == null) {
        found = event;
        continue;
      }
      final current = event.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final selected = found.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (latest ? current.isAfter(selected) : current.isBefore(selected)) {
        found = event;
      }
    }
    return found;
  }

  TimeOfDay? _timeOfDay(ManagerAttendanceTimelineEvent? event) {
    final time = event?.sortTime;
    if (time != null && time.millisecondsSinceEpoch != 0) {
      return TimeOfDay(hour: time.hour, minute: time.minute);
    }
    return _parseTimeLabel(event?.timeLabel);
  }

  TimeOfDay? _parseTimeLabel(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(4)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final hasAttendance = _data.hasAttendance;
    final locations = context.watch<ManagerLocationsProvider>().locations;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _savedResult);
      },
      child: DraggableScrollableSheet(
        initialChildSize: hasAttendance ? 0.88 : 0.62,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText.h5(
                          ManagerAttendanceDetailsData.formatFullDate(
                            _data.day,
                          ),
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                      ),
                      ButtonAnimations.press(
                        onTap: () => Navigator.pop(context, _savedResult),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kDividerColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      ClipOval(
                        child: CommonImageView(
                          url: _data.hasNetworkPhoto ? _data.photo : null,
                          imagePath: _data.hasNetworkPhoto
                              ? null
                              : _data.photoPath,
                          height: 48,
                          width: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText.p2(
                              _data.name,
                              color: kBlack,
                              weight: FontWeight.w600,
                              align: TextAlign.left,
                            ),
                            if (_data.role != null &&
                                _data.role!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              AppText.caption(
                                _data.role!,
                                color: kGreyColor,
                                weight: FontWeight.w400,
                                align: TextAlign.left,
                              ),
                            ],
                          ],
                        ),
                      ),
                      ButtonAnimations.press(
                        onTap: _openProfile,
                        child: CommonImageView(
                          imagePath: Assets.PersonIconSheet,
                          height: 45,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ButtonAnimations.press(
                        onTap: _openAttendance,
                        child: CommonImageView(
                          imagePath: Assets.AttendanceIconSheet,
                          height: 45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kDividerColor),
                Expanded(
                  child: Container(
                    color: kbackground2,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      children: [
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        _SummaryCard(
                          data: _data,
                          durationLabel: _durationLabel,
                          locations: locations,
                        ),
                        if (hasAttendance && _data.timeline.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              CommonImageView(
                                imagePath: Assets.imagesClipboardClock,
                                height: 22,
                              ),
                              const SizedBox(width: 8),
                              AppText.h5("Timeline", weight: FontWeight.w600),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ..._data.timeline.map(
                            (e) => _ManagerTimelineTile(
                              event: e,
                              locations: locations,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: kWhite,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SafeArea(
                    top: false,
                    child: hasAttendance
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: MyButton(
                              size: MyButtonSize.normal,
                              width: 200,
                              buttonText: 'Edit Attendance',
                              backgroundColor: kWhite,
                              fontColor: kBlack,
                              outlineColor: kBorderColor,
                              hasicon: true,
                              leftWidget: CommonImageView(
                                imagePath: Assets.imagesPen,
                                height: 16,
                              ),
                              onTap: () async => _openEditor(isAdd: false),
                            ),
                          )
                        : MyButton(
                            buttonText: "Add Attendance",
                            backgroundColor: kPrimaryColor,
                            onTap: () async => _openEditor(isAdd: true),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.data,
    required this.durationLabel,
    required this.locations,
  });

  final ManagerAttendanceDetailsData data;
  final String durationLabel;
  final List<ManagerLocationModel> locations;

  String get _checkIn =>
      (data.checkIn?.trim().isNotEmpty ?? false) ? data.checkIn! : "--";

  String get _checkOut =>
      (data.checkOut?.trim().isNotEmpty ?? false) ? data.checkOut! : "--";

  bool get _hasCheckIn => _checkIn != "--";
  bool get _hasCheckOut => _checkOut != "--";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.p2("Check-In", color: kPrimaryColor),
                    const SizedBox(height: 6),
                    AppText.h3(
                      _checkIn,
                      align: TextAlign.left,
                      color: _hasCheckIn ? kPrimaryColor : kPrimaryColor,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _dot(),
                  _line(),
                  const SizedBox(width: 6),
                  AppText.p2(durationLabel, weight: FontWeight.w600),
                  const SizedBox(width: 6),
                  _line(),
                  _dot(),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText.p2("Check-Out", color: kredColor),
                    const SizedBox(height: 6),
                    AppText.h3(
                      _checkOut,
                      align: TextAlign.right,
                      color: kredColor,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AttendanceLocationLine(
                  name: _officeName(
                    lat: data.checkInLat,
                    lon: data.checkInLon,
                    raw: data.checkInLocation,
                    locations: locations,
                  ),
                  lat: data.checkInLat,
                  lon: data.checkInLon,
                  raw: data.checkInLocation,
                  showCoordinates: false,
                ),
              ),
              Expanded(
                child: _AttendanceLocationLine(
                  name: _officeName(
                    lat: data.checkOutLat,
                    lon: data.checkOutLon,
                    raw: data.checkOutLocation,
                    locations: locations,
                  ),
                  lat: data.checkOutLat,
                  lon: data.checkOutLon,
                  raw: data.checkOutLocation,
                  isRight: true,
                  showCoordinates: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() =>
      Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3));

  Widget _line() =>
      Container(width: 18, height: 2, color: kGreyColor.withOpacity(0.3));
}

class _ManagerTimelineTile extends StatelessWidget {
  const _ManagerTimelineTile({required this.event, required this.locations});

  final ManagerAttendanceTimelineEvent event;
  final List<ManagerLocationModel> locations;

  bool get _isReminder => event.type == ManagerAttendanceEventType.reminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: _isReminder
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CommonImageView(imagePath: Assets.imagesBell, height: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.p2(event.timeLabel, align: TextAlign.left),
                      const SizedBox(height: 4),
                      AppText.p4(event.label, align: TextAlign.left),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h6(event.timeLabel, weight: FontWeight.w700),
                const SizedBox(height: 6),
                AppText.h5(
                  event.label,
                  color: event.color,
                  weight: FontWeight.w700,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 6),
                _AttendanceLocationLine(
                  name: _officeName(
                    lat: event.lat,
                    lon: event.lon,
                    raw: event.location,
                    locations: locations,
                  ),
                  lat: event.lat,
                  lon: event.lon,
                  raw: event.location,
                ),
              ],
            ),
    );
  }
}

class _AttendanceLocationLine extends StatelessWidget {
  const _AttendanceLocationLine({
    this.name,
    this.lat,
    this.lon,
    this.raw,
    this.isRight = false,
    this.showCoordinates = true,
  });

  final String? name;
  final double? lat;
  final double? lon;
  final String? raw;
  final bool isRight;
  final bool showCoordinates;

  (double, double)? get _coords {
    if (lat != null && lon != null) return (lat!, lon!);
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final parts = value.split(',');
    if (parts.length != 2) return null;
    final parsedLat = double.tryParse(parts[0].trim());
    final parsedLon = double.tryParse(parts[1].trim());
    if (parsedLat == null || parsedLon == null) return null;
    return (parsedLat, parsedLon);
  }

  String? get _coordsLabel {
    final coords = _coords;
    if (coords == null) return null;
    return '${coords.$1}, ${coords.$2}';
  }

  @override
  Widget build(BuildContext context) {
    final label = name?.trim();
    final coords = _coordsLabel;
    final hasName = label != null && label.isNotEmpty;
    final showCoords = showCoordinates && coords != null;
    if (!hasName && !showCoords) {
      return AppText.caption(
        "--",
        color: kGreyColor,
        weight: FontWeight.w500,
        align: isRight ? TextAlign.right : TextAlign.left,
      );
    }

    final row = Row(
      children: [
        if (!isRight) ...[
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Wrap(
            alignment: isRight ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              if (hasName)
                AppText.caption(
                  label,
                  color: kGreyColor,
                  weight: FontWeight.w500,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  align: isRight ? TextAlign.right : TextAlign.left,
                ),
              if (showCoords)
                AppText.caption(
                  coords,
                  color: kBlue,
                  weight: FontWeight.w500,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  align: isRight ? TextAlign.right : TextAlign.left,
                ),
            ],
          ),
        ),
        if (isRight) ...[
          const SizedBox(width: 6),
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
        ],
      ],
    );

    final point = _coords;
    if (point == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MapsLauncher.open(lat: point.$1, lon: point.$2);
      },
      child: row,
    );
  }
}

String? _officeName({
  required double? lat,
  required double? lon,
  required String? raw,
  required List<ManagerLocationModel> locations,
}) {
  if (lat != null && lon != null) {
    String? best;
    var bestDistance = double.infinity;
    for (final location in locations) {
      if (location.latitude == null || location.longitude == null) continue;
      final distance = GeofenceHelper.distanceMeters(
        GeoPoint(lat: lat, lon: lon),
        GeoPoint(lat: location.latitude!, lon: location.longitude!),
      );
      final radius = location.radiusMeters ?? kDefaultGeofenceRadiusMeters;
      if (distance <= radius && distance < bestDistance) {
        bestDistance = distance;
        best = location.name;
      }
    }
    if (best != null && best.trim().isNotEmpty) return best;
  }

  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(value)) {
    return null;
  }
  return value;
}
