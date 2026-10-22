import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/routes/app_routes.dart';
import 'package:obecno/features/employee_module/leaves/data/leaves_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/apply_leave_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_detail_sheet.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_timeline_cards.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:obecno/main.dart';

/// Day overview for absent days. Empty days show the calendar actions.
/// Days with leave keep the summary card and timeline.
class AttendanceDayOverviewSheet extends StatefulWidget {
  const AttendanceDayOverviewSheet({
    super.key,
    required this.day,
    required this.apiClient,
    required this.userEmail,
    this.attendanceId,
    this.employeeUserId,
    this.employeeName,
    this.applyImmediately = false,
  });

  final DateTime day;
  final ApiClient apiClient;
  final String userEmail;
  final int? attendanceId;

  /// When set (manager viewing an employee), Add Attendance targets this user.
  final int? employeeUserId;
  final String? employeeName;

  /// Manager path applies attendance immediately (approved); employee requests.
  final bool applyImmediately;

  /// Returns [AddAttendanceSaveResult] after add-attendance, or the leave
  /// [DateTime] after manager assign-leave, otherwise null.
  static Future<Object?> show(
    BuildContext context, {
    required DateTime day,
    required ApiClient apiClient,
    required String userEmail,
    int? attendanceId,
    int? employeeUserId,
    String? employeeName,
    bool applyImmediately = false,
  }) {
    return AppSheet.show<Object>(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: AppSheetSize.constraintsOf(context),
          child: AttendanceDayOverviewSheet(
            day: day,
            apiClient: apiClient,
            userEmail: userEmail,
            attendanceId: attendanceId,
            employeeUserId: employeeUserId,
            employeeName: employeeName,
            applyImmediately: applyImmediately,
          ),
        );
      },
    );
  }

  @override
  State<AttendanceDayOverviewSheet> createState() =>
      _AttendanceDayOverviewSheetState();
}

class _AttendanceDayOverviewSheetState
    extends State<AttendanceDayOverviewSheet> {
  final LeavesStore _store = bindings.leavesStore;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _store.ensureLoaded();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openApplyLeave() async {
    final day = widget.day;
    final employeeUserId = widget.employeeUserId;
    final employeeName = widget.employeeName;

    // Manager: assign leave for this employee — keep overview until done.
    if (employeeUserId != null) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final result = await ApplyLeaveSheet.show(
        context,
        initialDate: day,
        employeeUserId: employeeUserId,
        employeeName: employeeName,
      );
      if (!mounted) return;
      if (result != null) {
        // Signal the attendance list to stamp On Leave + reload.
        Navigator.pop(context, day);
      }
      return;
    }

    Navigator.pop(context);
    // Wait a frame so this sheet is gone and AppSheet's lock is free.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    final host = rootNavigatorKey.currentContext;
    if (host == null || !host.mounted) return;
    await ApplyLeaveSheet.show(host, initialDate: day);
  }

  Future<void> _openAddAttendance() async {
    // Wait a frame so AppSheet's open-lock is free for a nested sheet.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final saved = await AddAttendanceBottomSheet.show(
      context,
      day: widget.day,
      apiClient: widget.apiClient,
      userEmail: widget.userEmail,
      attendanceId: widget.attendanceId,
      employeeUserId: widget.employeeUserId,
      employeeName: widget.employeeName,
      applyImmediately: widget.applyImmediately,
      isCreating: true,
    );
    if (!mounted) return;
    Navigator.pop(context, saved);
  }

  Future<void> _openLeaveDetail(LeaveTimelineEvent event) async {
    final request = _store.requestForTimelineEvent(event.id);
    if (request == null) return;
    await LeaveDetailSheet.show(
      context,
      requestId: request.id,
      headerDate: widget.day,
    );
  }

  static const _monthsShort = [
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

  static const _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String get _emptyDateLabel =>
      '${_weekdaysShort[widget.day.weekday - 1]}, ${widget.day.day} ${_monthsShort[widget.day.month - 1]} ${widget.day.year}';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final events = _store.timelineEventsForDay(widget.day);
    final hasLeaves = events.isNotEmpty;

    if (!hasLeaves) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const SizedBox(height: 36),
            CommonImageView(imagePath: Assets.imagesCalendarStar, height: 112),
            const SizedBox(height: 30),
            AppText.h4(_emptyDateLabel, weight: FontWeight.w500),
            const SizedBox(height: 30),
            MyButton(
              width: 250,
              height: 48,
              size: MyButtonSize.normal,
              buttonText: 'Add Attendance',
              backgroundColor: kPrimaryColor,
              fontColor: kWhite,
              onTap: _openAddAttendance,
            ),
            const SizedBox(height: 12),
            MyButton(
              width: 250,
              height: 48,
              size: MyButtonSize.normal,
              buttonText: 'Apply Leave',
              backgroundColor: kBlack,
              fontColor: kWhite,
              onTap: _openApplyLeave,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 14 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          const SizedBox(height: 16),
          _summaryCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              CommonImageView(
                imagePath: Assets.imagesClipboardClock,
                height: 22,
              ),
              const SizedBox(width: 8),
              AppText.h5('Timeline', weight: FontWeight.w600),
            ],
          ),
          const SizedBox(height: 12),
          LeaveTimelineCards(events: events, onTapRequested: _openLeaveDetail),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyButton(
                width: 150,
                height: 44,
                size: MyButtonSize.normal,
                buttonText: 'Apply Leave',
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap: _openApplyLeave,
              ),
              MyButton(
                width: 150,
                height: 44,
                size: MyButtonSize.normal,
                buttonText: 'Add Attendance',
                backgroundColor: kPrimaryColor,
                fontColor: kWhite,
                onTap: _openAddAttendance,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppText.h5(
                LeaveFormat.headerFull(widget.day),
                weight: FontWeight.w600,
                align: TextAlign.left,
              ),
            ),
            ButtonAnimations.press(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
      ],
    );
  }

  Widget _summaryCard() {
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
                    AppText.p2('Check-In', color: kPrimaryColor),
                    const SizedBox(height: 6),
                    AppText.h3(
                      '--',
                      align: TextAlign.left,
                      color: kPrimaryColor,
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
                  AppText.p2('0h 00m', weight: FontWeight.w600),
                  const SizedBox(width: 6),
                  _line(),
                  _dot(),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText.p2('Check-Out', color: kGreyColor),
                    const SizedBox(height: 6),
                    AppText.h3(
                      '--',
                      align: TextAlign.right,
                      color: kGreyColor,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_location('--'), _location('--', isRight: true)],
          ),
        ],
      ),
    );
  }

  Widget _dot() =>
      Icon(Icons.circle, size: 10, color: kGreyColor.withValues(alpha: 0.3));

  Widget _line() =>
      Container(width: 15, height: 2, color: kGreyColor.withValues(alpha: 0.3));

  Widget _location(String text, {bool isRight = false}) {
    return Row(
      mainAxisAlignment: isRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!isRight) ...[
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
          const SizedBox(width: 6),
        ],
        AppText.p2(text, color: kGreyColor, weight: FontWeight.w500),
        if (isRight) ...[
          const SizedBox(width: 6),
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
        ],
      ],
    );
  }
}
