// ignore_for_file: non_constant_identifier_names

import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/bottom_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class AddAttendanceSaveResult {
  const AddAttendanceSaveResult({
    required this.checkIn,
    required this.checkOut,
  });

  final TimeOfDay checkIn;
  final TimeOfDay checkOut;
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
    bool applyImmediately = false,
    bool hadInitialCheckOut = false,
    bool hadInitialBreakStart = false,
    bool hadInitialBreakEnd = false,
  }) {
    final contentKey = GlobalKey<_AttendanceContentState>();

    return CommonBottomSheet.show<AddAttendanceSaveResult>(
      context: context,
      height: MediaQuery.of(context).size.height * 0.8,
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
          initialCheckIn: initialCheckIn ?? const TimeOfDay(hour: 8, minute: 0),
          initialCheckOut:
              initialCheckOut ?? const TimeOfDay(hour: 12, minute: 0),
          initialBreakStart:
              initialBreakStart ?? const TimeOfDay(hour: 10, minute: 0),
          initialBreakEnd:
              initialBreakEnd ?? const TimeOfDay(hour: 10, minute: 30),
          checkInDetailId: checkInDetailId,
          checkOutDetailId: checkOutDetailId,
          breakStartDetailId: breakStartDetailId,
          breakEndDetailId: breakEndDetailId,
          attendanceId: attendanceId,
          employeeUserId: employeeUserId,
          applyImmediately: applyImmediately,
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
  final bool applyImmediately;
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
    this.applyImmediately = false,
    this.hadInitialCheckOut = false,
    this.hadInitialBreakStart = false,
    this.hadInitialBreakEnd = false,
  });

  @override
  State<_AttendanceContent> createState() => _AttendanceContentState();
}

class _AttendanceContentState extends State<_AttendanceContent>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$min $period";
  }

  // ✅ FIX: convert to DateTime
  DateTime _toDateTime(TimeOfDay t) {
    return DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      t.hour,
      t.minute,
    );
  }

  // ✅ FIX: dynamic working hours
  String _calculateWorkingHours() {
    final total = _toDateTime(checkOut).difference(_toDateTime(checkIn));
    final breakDur = _toDateTime(breakEnd).difference(_toDateTime(breakStart));

    final working = total - breakDur;

    final h = working.inHours;
    final m = working.inMinutes.remainder(60);

    return "${h}h ${m.toString().padLeft(2, '0')}m";
  }

  void openPicker(String fieldKey) async {
    setState(() {
      editingField = editingField == fieldKey ? null : fieldKey;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final contextKey = _itemKeys[fieldKey]?.currentContext;
    if (contextKey == null || !contextKey.mounted) return;

    final renderObject = contextKey.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return;

    final box = renderObject;
    final position = box.localToGlobal(Offset.zero);

    final screenHeight = MediaQuery.of(context).size.height;
    final itemCenter = position.dy + (box.size.height / 2);

    final offset = _scrollController.offset + (itemCenter - screenHeight / 2);

    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      offset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
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

    void maybeAdd({
      required String eventType,
      required String? detailId,
      required TimeOfDay initial,
      required TimeOfDay updated,
      bool force = false,
    }) {
      if (!force && !_timeChanged(initial, updated)) return;

      localRequests.add(
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: now,
          originalTime: formatTime(initial),
          newTime: formatTime(updated),
          eventType: eventType,
        ),
      );

      if (detailId == null || detailId.isEmpty) return;

      payloads.add(
        AttendanceChangeRequestPayload(
          attendanceDetailId: detailId,
          oldValue: formatTime(initial),
          newValue: formatTime(updated),
        ),
      );
    }

    maybeAdd(
      eventType: 'checkIn',
      detailId: widget.checkInDetailId,
      initial: widget.initialCheckIn,
      updated: checkIn,
    );
    maybeAdd(
      eventType: 'breakStart',
      detailId: widget.breakStartDetailId,
      initial: widget.initialBreakStart,
      updated: breakStart,
    );
    maybeAdd(
      eventType: 'breakEnd',
      detailId: widget.breakEndDetailId,
      initial: widget.initialBreakEnd,
      updated: breakEnd,
    );
    maybeAdd(
      eventType: 'checkOut',
      detailId: widget.checkOutDetailId,
      initial: widget.initialCheckOut,
      updated: checkOut,
    );

    // Save with no time change: still submit the field the user was editing.
    if (payloads.isEmpty && localRequests.isEmpty) {
      switch (editingField ?? 'checkin') {
        case 'checkout':
          maybeAdd(
            eventType: 'checkOut',
            detailId: widget.checkOutDetailId,
            initial: widget.initialCheckOut,
            updated: checkOut,
            force: true,
          );
          break;
        case 'breakstart':
          maybeAdd(
            eventType: 'breakStart',
            detailId: widget.breakStartDetailId,
            initial: widget.initialBreakStart,
            updated: breakStart,
            force: true,
          );
          break;
        case 'breakend':
          maybeAdd(
            eventType: 'breakEnd',
            detailId: widget.breakEndDetailId,
            initial: widget.initialBreakEnd,
            updated: breakEnd,
            force: true,
          );
          break;
        default:
          maybeAdd(
            eventType: 'checkIn',
            detailId: widget.checkInDetailId,
            initial: widget.initialCheckIn,
            updated: checkIn,
            force: true,
          );
      }
    }

    try {
      if (payloads.isEmpty && !widget.applyImmediately) {
        if (!mounted) return;
        ToastHelper.error(
          context,
          message:
              'No attendance detail found to update. Reopen the day and try again.',
        );
        setState(() => _isSaving = false);
        return;
      }

      final deviceDetails =
          (await bindings.deviceInfoService.collect()).deviceDetails;
      final gps = await _currentLatLon();

      String clock(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

      String? clockIf(TimeOfDay t, {required bool include}) =>
          include ? clock(t) : null;

      final isNewAttendance =
          widget.applyImmediately && widget.attendanceId == null;

      final result = widget.applyImmediately
          ? await bindings.managerAttendanceService.saveEmployeeAttendance(
              attendanceId: widget.attendanceId,
              userId: widget.employeeUserId,
              day: widget.day,
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
              checkIn: clock(checkIn),
              // New attendance (e.g. On Leave day) must send both times.
              checkOut: clockIf(
                checkOut,
                include:
                    isNewAttendance ||
                    widget.hadInitialCheckOut ||
                    _timeChanged(widget.initialCheckOut, checkOut),
              ),
              breakStart: clockIf(
                breakStart,
                include:
                    widget.hadInitialBreakStart ||
                    _timeChanged(widget.initialBreakStart, breakStart),
              ),
              breakEnd: clockIf(
                breakEnd,
                include:
                    widget.hadInitialBreakEnd ||
                    _timeChanged(widget.initialBreakEnd, breakEnd),
              ),
              changes: payloads,
            )
          : await AttendanceService(
              widget.apiClient,
            ).submitAttendanceChangeRequests(
              attendanceId: widget.attendanceId,
              deviceDetails: deviceDetails,
              lat: gps.lat,
              lon: gps.lon,
              changes: payloads,
            );

      if (!mounted) return;

      final success = result.success;

      if (success && !widget.applyImmediately && localRequests.isNotEmpty) {
        await AttendanceEditRequestStore.instance.addMany(
          day: widget.day,
          requests: localRequests,
        );
      }

      if (!mounted) return;

      if (success) {
        if (widget.applyImmediately) {
          ToastHelper.changesSaved(context);
          bindings.managerAttendanceProvider.refresh();
        } else {
          ToastHelper.attendanceRequestSent(
            context,
            ok: true,
            message: result.data,
          );
        }
        Navigator.of(context, rootNavigator: true).pop(
          AddAttendanceSaveResult(checkIn: checkIn, checkOut: checkOut),
        );
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.circle, color: kDividerColor, size: 12),
                  if (!isLast)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 2,
                      height: safeHeight,
                      margin: const EdgeInsets.only(top: 2),
                      color: kDividerColor,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    children: [
                      Row(
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
                      inlinePicker(
                        fieldKey: fieldKey,
                        value: _getValue(fieldKey),
                        onChanged: (v) => _setValue(fieldKey, v),
                      ),
                    ],
                  ),
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
                                final hour = selectedPeriod == 0
                                    ? selectedHour
                                    : (selectedHour + 12) % 24;
                                onChanged(
                                  TimeOfDay(hour: hour, minute: selectedMinute),
                                );
                              }),
                              _wheel(60, selectedMinute, (v) {
                                selectedMinute = v;
                                final hour = selectedPeriod == 0
                                    ? selectedHour
                                    : (selectedHour + 12) % 24;
                                onChanged(
                                  TimeOfDay(hour: hour, minute: selectedMinute),
                                );
                              }),
                              _wheel(2, selectedPeriod, (v) {
                                selectedPeriod = v;
                                final hour = selectedPeriod == 0
                                    ? selectedHour
                                    : (selectedHour + 12) % 24;
                                onChanged(
                                  TimeOfDay(hour: hour, minute: selectedMinute),
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
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.h5("Edit Attendance", weight: FontWeight.w600),
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
                CommonImageView(
                  imagePath: Assets.imagesCalendarDay,
                  height: 16,
                ),
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
      ),
    );
  }
}
