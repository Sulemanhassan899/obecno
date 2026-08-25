import 'dart:async';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/employee_module/routes/app_routes.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/resolved_location_text.dart';

import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/attendance_edit_history_section.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';

class ClockAttendanceDetailsSheet {
  ClockAttendanceDetailsSheet._();

  static Future<void> show({
    required BuildContext context,
    required DateTime day,
    required List<AttendanceEvent> events,
    required AttendanceSummary summary,
    required ApiClient apiClient,
    required String userEmail,
    VoidCallback? onEditAttendance,
    ValueChanged<List<AttendanceEvent>>? onTodayEventsLoaded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ClockAttendanceDetailsSheetBody(
          day: day,
          events: events,
          summary: summary,
          apiClient: apiClient,
          userEmail: userEmail,
          onEditAttendance: onEditAttendance,
          onTodayEventsLoaded: onTodayEventsLoaded,
        );
      },
    );
  }
}

class _ClockAttendanceDetailsSheetBody extends StatefulWidget {
  final DateTime day;
  final List<AttendanceEvent> events;
  final AttendanceSummary summary;
  final ApiClient apiClient;
  final String userEmail;
  final VoidCallback? onEditAttendance;
  final ValueChanged<List<AttendanceEvent>>? onTodayEventsLoaded;

  const _ClockAttendanceDetailsSheetBody({
    required this.day,
    required this.events,
    required this.summary,
    required this.apiClient,
    required this.userEmail,
    required this.onEditAttendance,
    this.onTodayEventsLoaded,
  });

  @override
  State<_ClockAttendanceDetailsSheetBody> createState() =>
      _ClockAttendanceDetailsSheetBodyState();
}

class _ClockAttendanceDetailsSheetBodyState
    extends State<_ClockAttendanceDetailsSheetBody> {
  Timer? _timer;
  late List<AttendanceEvent> _events;
  late AttendanceSummary _summary;
  late Duration _workingDuration;
  bool _loadingTimeline = true;
  int? _attendanceId;

  @override
  void initState() {
    super.initState();
    _events = _todayOnly(widget.events, widget.day);
    _recompute();
    _startTimer();
    unawaited(_loadFullTodayTimeline());
    unawaited(_mergeEditRequests());
  }

  @override
  void didUpdateWidget(covariant _ClockAttendanceDetailsSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _todayOnly(widget.events, widget.day);
    if (incoming.isEmpty) return;

    final merged = [..._events];
    var changed = false;
    for (final event in incoming) {
      final index = merged.indexWhere((e) => e.isSamePunchAs(event));
      if (index >= 0) {
        final next = AttendanceEvent.preferAuthoritative(merged[index], event);
        if (next.effectiveTime != merged[index].effectiveTime ||
            next.editRequests.length != merged[index].editRequests.length) {
          merged[index] = next;
          changed = true;
        }
      } else {
        merged.add(event);
        changed = true;
      }
    }
    if (!changed) return;
    merged.sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
    _events = merged;
    _recompute();
    unawaited(_mergeEditRequests());
  }

  /// Same day-only filter used for clock timeline rendering.
  static List<AttendanceEvent> _todayOnly(
    List<AttendanceEvent> events,
    DateTime day,
  ) {
    return events
        .where(
          (e) =>
              e.effectiveTime.year == day.year &&
              e.effectiveTime.month == day.month &&
              e.effectiveTime.day == day.day,
        )
        .toList()
      ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
  }

  Future<void> _mergeEditRequests() async {
    final store = AttendanceEditRequestStore.instance;
    await store.ensureLoaded();
    if (!mounted) return;

    final attachedTypes = <String>{};
    final merged = _events.map((event) {
      if (event.editRequests.isNotEmpty) return event;
      final typeName = event.type.name;
      if (!attachedTypes.add(typeName)) return event;
      final stored = store.forEvent(day: widget.day, eventType: typeName);
      if (stored.isEmpty) return event;
      return event.copyWith(editRequests: stored);
    }).toList(growable: false);

    setState(() {
      _events = merged;
      _recompute();
    });
  }

  String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadFullTodayTimeline() async {
    try {
      // Prefer /employee/attendance/details so change_requests/changes
      // power the Edited history UI on each timeline card.
      final detailsResponse = await AttendanceService(widget.apiClient)
          .getAttendanceDetails(date: _yyyyMMdd(widget.day))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (detailsResponse.success && detailsResponse.data != null) {
        final data = detailsResponse.data!;
        final apiEvents = _todayOnly(data.toClockEvents(), widget.day);
        if (apiEvents.isNotEmpty) {
          setState(() {
            _events = apiEvents;
            _attendanceId = data.attendanceId;
            _loadingTimeline = false;
            _recompute();
          });
          widget.onTodayEventsLoaded?.call(apiEvents);
          await _mergeEditRequests();
          return;
        }
        if (mounted) {
          setState(() => _attendanceId = data.attendanceId);
        }
      }

      // Fallback: older attendance list endpoint.
      final serverEvents = await bindings.clockAttendanceRepository
          .fetchTodayEvents(
            cancelToken: bindings.authProvider.sessionCancelToken,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (serverEvents != null && serverEvents.isNotEmpty) {
        final todayEvents = _todayOnly(serverEvents, widget.day);
        if (todayEvents.isNotEmpty) {
          setState(() {
            _events = todayEvents;
            _loadingTimeline = false;
            _recompute();
          });
          widget.onTodayEventsLoaded?.call(todayEvents);
          await _mergeEditRequests();
          return;
        }
      }
    } catch (_) {
      // Fall through to local/controller events already shown.
    }

    if (!mounted) return;
    setState(() => _loadingTimeline = false);
    await _mergeEditRequests();
  }

  void _recompute() {
    _summary = AttendanceEngine.compute(_events);
    _workingDuration = _summary.liveWorkingDuration();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _summary = AttendanceEngine.compute(_events);
        _workingDuration = _summary.liveWorkingDuration();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? get _firstCheckInLocation {
    for (final e in AttendanceEngine.sortedOldestFirst(_events)) {
      if (e.type == AttendanceEventType.checkIn) return e.location;
    }
    return null;
  }

  String? get _lastCheckOutLocation {
    String? location;
    for (final e in AttendanceEngine.sortedOldestFirst(_events)) {
      if (e.type == AttendanceEventType.checkOut) location = e.location;
    }
    return location;
  }

  bool get _isViewingToday {
    final now = DateTime.now();
    final day = widget.day;
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  Color _colorFor(AttendanceEventType type) {
    switch (type) {
      case AttendanceEventType.checkIn:
        return kPrimaryColor;
      case AttendanceEventType.checkOut:
        return kredColor;
      case AttendanceEventType.breakStart:
      case AttendanceEventType.breakEnd:
        return kYellowColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = AttendanceEngine.sortedOldestFirst(_events);
    // Live timer only for today; freeze completed-session total otherwise.
    final workingDuration = _isViewingToday
        ? _workingDuration
        : _summary.totalWorkingDuration;

    final knownLocations = bindings.authProvider.locations
        .map((loc) => KnownLocation(name: loc.name, latLon: loc.latLon))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
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
              /// ================= HEADER =================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText.h5(
                      AttendanceFormat.fullDate(widget.day),
                      weight: FontWeight.w600,
                    ),
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  color: kbackground2,
                  child: ListView(
                    shrinkWrap: true,
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    children: [
                      /// ================= BottomSheet card HEADER =================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                /// LEFT (CHECK IN)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText.p2(
                                        "Check-In",
                                        color: kPrimaryColor,
                                      ),
                                      const SizedBox(height: 6),
                                      AppText.h3(
                                        AttendanceFormat.time(
                                          _summary.firstCheckIn,
                                        ),
                                        align: TextAlign.left,
                                        color: kPrimaryColor,
                                        weight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                ),

                                /// CENTER DURATION
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        _dot(),
                                        _line(),
                                        const SizedBox(width: 6),
                                        AppText.p2(
                                          AttendanceFormat.duration(
                                            workingDuration,
                                          ),
                                          weight: FontWeight.w600,
                                        ),
                                        const SizedBox(width: 6),
                                        _line(),
                                        _dot(),
                                      ],
                                    ),
                                  ],
                                ),

                                /// RIGHT (CHECK OUT)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      AppText.p2("Check-Out", color: kredColor),
                                      const SizedBox(height: 6),
                                      AppText.h3(
                                        AttendanceFormat.time(
                                          _summary.isCheckedIn
                                              ? null
                                              : _summary.lastCheckOut,
                                        ),
                                        align: TextAlign.right,
                                        color: kredColor,
                                        weight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            /// LOCATION ROW
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _summary.firstCheckIn == null
                                      ? _location("--")
                                      : ResolvedLocationText(
                                          rawLocation: _firstCheckInLocation,
                                          knownLocations: knownLocations,
                                          onlyKnownLocations: true,
                                          builder: (context, text) =>
                                              _location(text),
                                        ),
                                ),
                                Expanded(
                                  child:
                                      (_summary.isCheckedIn ||
                                          _summary.lastCheckOut == null)
                                      ? _location("--", isRight: true)
                                      : ResolvedLocationText(
                                          rawLocation: _lastCheckOutLocation,
                                          knownLocations: knownLocations,
                                          onlyKnownLocations: true,
                                          builder: (context, text) =>
                                              _location(text, isRight: true),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      /// ================= TIMELINE HEADER =================
                      Row(
                        children: [
                          CommonImageView(
                            imagePath: Assets.imagesClipboardClock,
                            height: 24,
                          ),
                          const SizedBox(width: 8),
                          AppText.h5("Timeline", weight: FontWeight.w600),
                          if (_loadingTimeline) ...[
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),

                      /// ================= TIMELINE =================
                      if (timeline.isEmpty && !_loadingTimeline)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: AppText.p2(
                            "No events recorded yet",
                            color: kGreyColor,
                          ),
                        )
                      else
                        ...timeline.map(
                          (e) =>
                              _TimelineTile(event: e, color: _colorFor(e.type)),
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              /// ================= BUTTON =================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        MyButton(
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
                          onTap: () async {
                            AttendanceEvent? checkIn;
                            AttendanceEvent? checkOut;
                            AttendanceEvent? breakStart;
                            AttendanceEvent? breakEnd;
                            for (final e
                                in AttendanceEngine.sortedOldestFirst(
                                  _events,
                                )) {
                              switch (e.type) {
                                case AttendanceEventType.checkIn:
                                  checkIn ??= e;
                                  break;
                                case AttendanceEventType.checkOut:
                                  checkOut = e;
                                  break;
                                case AttendanceEventType.breakStart:
                                  breakStart ??= e;
                                  break;
                                case AttendanceEventType.breakEnd:
                                  breakEnd ??= e;
                                  break;
                              }
                            }

                            TimeOfDay? tod(DateTime? t) => t == null
                                ? null
                                : TimeOfDay(hour: t.hour, minute: t.minute);

                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final host = rootNavigatorKey.currentContext;
                              if (host == null || !host.mounted) return;
                              AddAttendanceBottomSheet.show(
                                host,
                                day: widget.day,
                                apiClient: widget.apiClient,
                                userEmail: widget.userEmail,
                                attendanceId: _attendanceId,
                                initialCheckIn: tod(checkIn?.effectiveTime),
                                initialCheckOut: tod(checkOut?.effectiveTime),
                                initialBreakStart: tod(
                                  breakStart?.effectiveTime,
                                ),
                                initialBreakEnd: tod(breakEnd?.effectiveTime),
                                checkInDetailId: checkIn?.id,
                                checkOutDetailId: checkOut?.id,
                                breakStartDetailId: breakStart?.id,
                                breakEndDetailId: breakEnd?.id,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot() {
    return Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3));
  }

  Widget _line() {
    return Container(width: 13, height: 2, color: kGreyColor.withOpacity(0.3));
  }

  Widget _location(String text, {bool isRight = false}) {
    return Row(
      children: [
        if (!isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
        if (!isRight) const SizedBox(width: 6),
        Expanded(
          child: AppText.caption(
            text,
            color: kGreyColor,
            weight: FontWeight.w500,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            align: isRight ? TextAlign.right : TextAlign.left,
          ),
        ),
        if (isRight) const SizedBox(width: 6),
        if (isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final AttendanceEvent event;
  final Color color;

  const _TimelineTile({required this.event, required this.color});

  @override
  Widget build(BuildContext context) {
    final knownLocations = bindings.authProvider.locations
        .map((loc) => KnownLocation(name: loc.name, latLon: loc.latLon))
        .toList();
    final isEdited = event.isEdited;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText.h6(
                  AttendanceFormat.time(event.effectiveTime),
                  weight: FontWeight.w700,
                  align: TextAlign.left,
                ),
              ),
              if (isEdited)
                AppText.p2('Edited', color: kSubText, weight: FontWeight.w400),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              AppText.h5(
                event.label,
                color: color,
                weight: FontWeight.w700,
                align: TextAlign.left,
              ),
              if (isEdited) ...[
                const SizedBox(width: 10),
                CommonImageView(imagePath: Assets.imagesUserPen, height: 20),
              ],
            ],
          ),

          const SizedBox(height: 8),

          ResolvedLocationText(
            rawLocation: event.location,
            knownLocations: knownLocations,
            onlyKnownLocations: true,
            builder: (context, text) => Row(
              children: [
                CommonImageView(
                  imagePath: Assets.imagesLocationDot,
                  height: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText.p2(
                    text,
                    color: kGreyColor,
                    weight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    align: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
          if (isEdited)
            AttendanceEditHistorySection(requests: event.editRequests),
        ],
      ),
    );
  }
}
