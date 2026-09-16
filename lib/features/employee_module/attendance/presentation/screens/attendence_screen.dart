import 'dart:async';

import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart'
    as normalized;
import 'package:obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:obecno/features/employee_module/attendance/domain/controllers/attendence_controller.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';

import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_widgets.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/hoilday_detail_sheet.dart';
import 'package:obecno/widgets/back_button.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({
    super.key,
    this.employeeName,
    this.embeddedInSheet = false,
  });

  /// When opened from manager profile, shows employee name in the header.
  final String? employeeName;

  /// Embed inside a bottom sheet (no outer Scaffold / SafeArea padding).
  final bool embeddedInSheet;

  @override
  State<EmployeeAttendanceScreen> createState() =>
      EmployeeAttendanceScreenState();
}

class EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  final MonthlyAttendanceController _controller = MonthlyAttendanceController();
  final AttendanceEditRequestStore _requestStore =
      AttendanceEditRequestStore.instance;

  List<AttendanceDayRecord> get processedRecords {
    final store = _requestStore;
    final ascending =
        List<AttendanceDayRecord>.from(_controller.records)
            .map(
              (record) => record.overlayPendingAdd(
                pendingAdd: store.hasPendingAdd(record.date),
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return AttendanceListGrouping.groupConsecutiveWeekends(ascending);
  }

  String _formatFullWeekdayDate(DateTime date) {
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}";
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      _requestStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void notifyTabResumed() {
    unawaited(_reloadAndReconcile());
  }

  Future<void> _reloadAndReconcile() async {
    await _controller.reloadVisibleMonth();
    await _reconcilePendingAdds();
    if (mounted) setState(() {});
  }

  Future<void> _reconcilePendingAdds() async {
    await _requestStore.ensureLoaded();
    for (final record in _controller.records) {
      if (record.hasVisiblePunch && _requestStore.hasPendingAdd(record.date)) {
        await _requestStore.clearPendingAdd(record.date);
      }
    }
  }

  List<HistoryAttendanceEvent> _eventsFor(normalized.AttendanceDay? day) {
    if (day == null) return [];

    final events = <HistoryAttendanceEvent>[];

    // Preserve EVERY check-in / check-out from the API (not just first/last).
    for (var i = 0; i < day.checkIns.length; i++) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, day.checkIns[i]),
          type: AttendanceHisotryEventType.checkIn,
          location: i < day.checkInLocations.length
              ? day.checkInLocations[i]
              : null,
        ),
      );
    }

    for (var i = 0; i < day.checkOuts.length; i++) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, day.checkOuts[i]),
          type: AttendanceHisotryEventType.checkOut,
          location: i < day.checkOutLocations.length
              ? day.checkOutLocations[i]
              : null,
        ),
      );
    }

    for (final b in day.breaks) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, b.breakOut),
          type: AttendanceHisotryEventType.breakStart,
          location: b.breakOutLocation,
        ),
      );
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, b.breakIn),
          type: AttendanceHisotryEventType.breakEnd,
          location: b.breakInLocation,
        ),
      );
    }

    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  /// Combines a date-only `DateTime` with an "HH:mm[:ss]" time string.
  DateTime _combine(DateTime date, String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  AttendanceHisotryEventType? _historyType(String? eventType) {
    switch (eventType) {
      case 'checkIn':
        return AttendanceHisotryEventType.checkIn;
      case 'checkOut':
        return AttendanceHisotryEventType.checkOut;
      case 'breakStart':
        return AttendanceHisotryEventType.breakStart;
      case 'breakEnd':
        return AttendanceHisotryEventType.breakEnd;
      default:
        return null;
    }
  }

  List<HistoryAttendanceEvent> _eventsFromPending(
    DateTime day,
    List<AttendanceEditRequest> requests,
  ) {
    final byType = <AttendanceHisotryEventType, HistoryAttendanceEvent>{};
    for (final request in requests) {
      final type = _historyType(request.eventType);
      if (type == null) continue;
      final time = AttendanceEditRequest.parseClockTime(
        request.newTime,
        date: day,
      );
      if (time == null) continue;
      byType[type] = HistoryAttendanceEvent(
        time: time,
        type: type,
        editRequests: [request],
      );
    }
    return byType.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<void> _onDayTap(AttendanceDayRecord record) async {
    if (record.status == AttendanceDayStatus.holiday ||
        record.status == AttendanceDayStatus.weekend) {
      HolidayBottomSheet.show(
        context,
        day: record.date,
        title: record.status == AttendanceDayStatus.holiday
            ? (record.weekendLabel ?? "Public Holiday")
            : "Weekend Holiday",
        apiClient: _controller.apiClient,
        userEmail: _controller.userEmail,
      );
      return;
    }

    if (!record.isOnLeave && record.isAbsent) {
      await _requestStore.ensureLoaded();
      final pending = _requestStore
          .forDay(record.date)
          .where((request) => request.isPending)
          .toList();
      if (pending.isNotEmpty) {
        final dayEvents = _eventsFromPending(record.date, pending);
        await AttendanceDetailsSheet.show(
          context: context,
          day: record.date,
          events: dayEvents,
          summary: HistoryAttendanceEngine.compute(dayEvents),
          apiClient: _controller.apiClient,
          userEmail: _controller.userEmail,
          onEditAttendance: () {},
          preferLocalEvents: true,
        );
        await _reloadAndReconcile();
        return;
      }

      await AddAttendanceBottomSheet.show(
        context,
        day: record.date,
        apiClient: _controller.apiClient,
        userEmail: _controller.userEmail,
        attendanceId: _controller.dayFor(record.date)?.recordId,
        isCreating: true,
      );
      await _requestStore.ensureLoaded();
      if (mounted) setState(() {});
      await _reloadAndReconcile();
      return;
    }

    final day = record.date;
    final normalizedDay = _controller.dayFor(day);
    final dayEvents = _eventsFor(normalizedDay);
    final summary = HistoryAttendanceEngine.compute(dayEvents);

    await AttendanceDetailsSheet.show(
      context: context,
      day: day,
      events: dayEvents,
      summary: summary,
      apiClient: _controller.apiClient,
      userEmail: _controller.userEmail,
      onEditAttendance: () {},
      onLeave: record.isOnLeave,
    );
    await _reloadAndReconcile();
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final summary = _controller.summary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embeddedInSheet) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    BackCircleButton(onTap: () => Navigator.pop(context)),
                    Expanded(
                      child: Column(
                        children: [
                          AppText.h5('Attendance'),
                          if (widget.employeeName != null) ...[
                            const SizedBox(height: 2),
                            AppText.caption(
                              widget.employeeName!,
                              color: kGreyColor,
                              weight: FontWeight.w400,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.embeddedInSheet ? 16 : 0,
              ),
              child: AttendanceMonthHeader(
                month: _controller.selectedMonth,
                onPrevious: _controller.previousMonth,
                onNext: _controller.nextMonth,
                isNextEnabled: _controller.canGoNext,
                isPreviousEnabled: _controller.canGoPrevious,
                onTapDropdown: () {
                  MonthYearPickerSheet.show(
                    context,
                    initialDate: _controller.selectedMonth,
                    minDate: _controller.joiningDate,
                    onSelected: (date) {
                      _controller.setMonth(date);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ShimmerRefreshIndicator(
                  onRefresh: () async {
                    await _controller.refresh();
                    await _reconcilePendingAdds();
                    if (mounted) setState(() {});
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.embeddedInSheet ? 16 : 0,
                    ),
                    child: _controller.isLoading && summary == null
                        ? _buildLoadingShimmer()
                        : _controller.records.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.dataset_outlined,
                                      size: 60,
                                      color: kGreyColor.withOpacity(0.7),
                                    ),
                                    const SizedBox(height: 12),
                                    AppText.p2(
                                      "No Record",
                                      color: kGreyColor,
                                      weight: FontWeight.w600,
                                    ),
                                    const SizedBox(height: 6),
                                    AppText.p2(
                                      "You don’t have any records yet",
                                      color: kGreyColor.withOpacity(0.7),
                                      weight: FontWeight.w400,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: processedRecords.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Column(
                                  children: [
                                    AttendanceSummaryCard(
                                      summary:
                                          summary ??
                                          const MonthSummary(
                                            workingDays: 0,
                                            totalDays: 0,
                                            absentOrLeaves: 0,
                                            lateCheckIns: 0,
                                            lateCheckOuts: 0,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                );
                              }

                              final record = processedRecords[index - 1];
                              if (record.status ==
                                  AttendanceDayStatus.holiday) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: AttendanceHolidayCard(
                                    title:
                                        record.weekendLabel ?? "Public Holiday",
                                    date: _formatFullWeekdayDate(record.date),
                                    onTap: () => _onDayTap(record),
                                  ),
                                );
                              }

                              if (record.status ==
                                  AttendanceDayStatus.weekend) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 10,
                                    top: 10,
                                  ),
                                  child: AttendanceWeekendCard(
                                    label: record.weekendLabel ?? "Weekend",
                                  ),
                                );
                              }

                              return AttendanceDayTile(
                                record: record,
                                onTap: () => _onDayTap(record),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.embeddedInSheet) {
      return ColoredBox(color: kbackground2, child: content);
    }

    final padding = AppSizes.page(context);
    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: padding.copyWith(top: MediaQuery.paddingOf(context).top),
        child: content,
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      children: [
        /// Summary shimmer
        Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 20)),
                  const SizedBox(width: 20),
                  Expanded(child: _shimmerBox(height: 20)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 20)),
                  const SizedBox(width: 20),
                  Expanded(child: _shimmerBox(height: 20)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        /// List shimmer
        ...List.generate(6, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                _shimmerBox(
                  height: 60,
                  width: 60,
                  radius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 16),
                Expanded(child: _shimmerBox(height: 16)),
                const SizedBox(width: 16),
                _shimmerBox(height: 16, width: 80),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _shimmerBox({
    double height = 16,
    double width = double.infinity,
    BorderRadius? radius,
  }) {
    return AppShimmer(
      isLoading: true,
      height: height,
      width: width,
      borderRadius: radius ?? BorderRadius.zero,
    );
  }
}
