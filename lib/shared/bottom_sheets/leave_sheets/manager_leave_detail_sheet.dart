import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_status_chip.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_timeline_cards.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/core/routes/app_routes.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_profile_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/apply_leave_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Manager leave timeline / approve-reject-edit sheet.
class ManagerLeaveDetailSheet extends StatefulWidget {
  const ManagerLeaveDetailSheet({
    super.key,
    required this.leave,
    this.employeeName,
    this.employeeRole,
    this.employeePhoto,
    this.headerDate,
    this.lastLeaveLabel,
    this.loadForDayUserId,
  });

  final ManagerLeaveView leave;
  final String? employeeName;
  final String? employeeRole;
  final String? employeePhoto;
  final DateTime? headerDate;
  final String? lastLeaveLabel;

  /// When set, sheet opens instantly then fetches leave for this user/day.
  final int? loadForDayUserId;

  /// Returns `'approve'` / `'reject'` after a successful review, otherwise null.
  static Future<Object?> show({
    required BuildContext context,
    required ManagerLeaveView leave,
    String? employeeName,
    String? employeeRole,
    String? employeePhoto,
    DateTime? headerDate,
    String? lastLeaveLabel,
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
          child: ManagerLeaveDetailSheet(
            leave: leave,
            employeeName: employeeName,
            employeeRole: employeeRole,
            employeePhoto: employeePhoto,
            headerDate: headerDate,
            lastLeaveLabel: lastLeaveLabel,
          ),
        );
      },
    );
  }

  /// Opens the sheet immediately, then loads leave details inside it.
  /// Returns `'approve'` / `'reject'` after a successful review, otherwise null.
  static Future<Object?> showForDay({
    required BuildContext context,
    required DateTime day,
    int? userId,
    String? employeeName,
    String? employeeRole,
    String? employeePhoto,
  }) {
    if (userId == null) {
      ToastHelper.error(context, message: 'Missing employee.');
      return Future.value(null);
    }

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
          child: ManagerLeaveDetailSheet(
            leave: ManagerLeaveView.placeholder(
              day: day,
              userId: userId,
              employeeName: employeeName,
            ),
            employeeName: employeeName,
            employeeRole: employeeRole,
            employeePhoto: employeePhoto,
            headerDate: day,
            loadForDayUserId: userId,
          ),
        );
      },
    );
  }

  static String? _lastLeaveLabel({
    required List<ManagerEmployeeLeaveRequest> leaves,
    required String? currentId,
    required DateTime before,
  }) {
    ManagerEmployeeLeaveRequest? previous;
    DateTime? previousEnd;
    final day = DateTime(before.year, before.month, before.day);

    for (final item in leaves) {
      if (currentId != null && item.id == currentId) continue;
      final status = (item.status ?? '').toLowerCase();
      if (status.contains('reject') || status.contains('deny')) continue;
      final end =
          ManagerTeamLeaveItem.parseLeaveDate(item.toDate) ??
          ManagerTeamLeaveItem.parseLeaveDate(item.fromDate);
      if (end == null) continue;
      final endDay = DateTime(end.year, end.month, end.day);
      if (!endDay.isBefore(day)) continue;
      if (previousEnd == null || endDay.isAfter(previousEnd)) {
        previous = item;
        previousEnd = endDay;
      }
    }
    if (previous == null || previousEnd == null) return null;

    final type = (previous.type ?? 'Leave').trim();
    final daysAgo = day.difference(previousEnd).inDays;
    if (daysAgo <= 0) return 'Last leave: $type';
    if (daysAgo == 1) return 'Last leave: $type, 1 day ago';
    return 'Last leave: $type, $daysAgo days ago';
  }

  @override
  State<ManagerLeaveDetailSheet> createState() =>
      _ManagerLeaveDetailSheetState();
}

class _ManagerLeaveDetailSheetState extends State<ManagerLeaveDetailSheet> {
  late ManagerLeaveView _leave;
  String? _lastLeaveLabel;
  late DateTime _day;
  bool _busy = false;
  bool _loadingDetails = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _leave = widget.leave;
    _lastLeaveLabel = widget.lastLeaveLabel;
    _day = widget.headerDate ?? widget.leave.startDate;
    if (widget.loadForDayUserId != null) {
      _loadingDetails = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDayLeave());
    } else if ((_leave.note == null || _leave.note!.trim().isEmpty) &&
        _leave.userId != null) {
      // List payloads often omit reason — fill note from employee leave API.
      WidgetsBinding.instance.addPostFrameCallback((_) => _enrichNote());
    }
  }

  Future<void> _enrichNote() async {
    final userId = _leave.userId;
    final leaveId = _leave.id;
    if (userId == null) return;
    final from = _leave.startDate;
    final to = _leave.endDate;
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final result = await bindings.managerEmployeesService.loadEmployeeLeaves(
        userId: userId,
        dateFrom: ymd(from),
        dateTo: ymd(to),
      );
      if (!mounted || result.data == null) return;
      ManagerEmployeeLeaveRequest? match;
      for (final item in result.data!) {
        if (leaveId != null && int.tryParse(item.id) == leaveId) {
          match = item;
          break;
        }
        final start = ManagerTeamLeaveItem.parseLeaveDate(item.fromDate);
        final end =
            ManagerTeamLeaveItem.parseLeaveDate(item.toDate) ?? start;
        if (start == null) continue;
        if (start == DateTime(from.year, from.month, from.day) &&
            end == DateTime(to.year, to.month, to.day)) {
          match = item;
          break;
        }
      }
      final reason = match?.reason?.trim();
      if (reason == null || reason.isEmpty) return;
      setState(() {
        _leave = ManagerLeaveView(
          id: _leave.id,
          typeName: _leave.typeName,
          status: _leave.status,
          startDate: _leave.startDate,
          endDate: _leave.endDate,
          dayCount: _leave.dayCount,
          timeline: _leave.timeline,
          userId: _leave.userId,
          employeeName: _leave.employeeName,
          note: reason,
          documentName: _leave.documentName,
        );
      });
    } catch (_) {}
  }

  String? _resolvedPhoto(BuildContext context) {
    final passed = widget.employeePhoto?.trim();
    if (passed != null && passed.isNotEmpty) return passed;

    final employees = context.read<ManagerEmployeesProvider>().members;
    final userId = _leave.userId ?? widget.loadForDayUserId;
    if (userId != null) {
      for (final member in employees) {
        if (member.userId == userId) {
          final photo = member.photo?.trim();
          if (photo != null && photo.isNotEmpty) return photo;
        }
      }
    }
    final name =
        (widget.employeeName ?? _leave.employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final member in employees) {
      if (member.name.trim().toLowerCase() == name) {
        final photo = member.photo?.trim();
        if (photo != null && photo.isNotEmpty) return photo;
      }
    }
    return null;
  }

  Future<void> _loadDayLeave({DateTime? forDay}) async {
    final userId = widget.loadForDayUserId ?? _leave.userId;
    final target = forDay ?? _day;
    if (userId == null) return;
    final token = ++_loadToken;
    setState(() {
      _day = DateTime(target.year, target.month, target.day);
      _loadingDetails = true;
      _leave = ManagerLeaveView.placeholder(
        day: _day,
        userId: userId,
        employeeName: widget.employeeName,
      );
    });

    final day = _day;
    final ymd =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    Future<List<ManagerEmployeeLeaveRequest>> pull(
      String from,
      String to,
    ) async {
      final result = await bindings.managerEmployeesService.loadEmployeeLeaves(
        userId: userId,
        dateFrom: from,
        dateTo: to,
      );
      return result.data ?? const [];
    }

    try {
      final monthStart = DateTime(day.year, day.month, 1);
      final monthEnd = DateTime(day.year, day.month + 1, 0);
      final ms =
          '${monthStart.year.toString().padLeft(4, '0')}-'
          '${monthStart.month.toString().padLeft(2, '0')}-'
          '${monthStart.day.toString().padLeft(2, '0')}';
      final me =
          '${monthEnd.year.toString().padLeft(4, '0')}-'
          '${monthEnd.month.toString().padLeft(2, '0')}-'
          '${monthEnd.day.toString().padLeft(2, '0')}';
      final yearStart = DateTime(day.year - 1, 1, 1);

      // One parallel batch instead of chained calls (avoids long loading loops).
      final results = await Future.wait([
        pull(ymd, ymd),
        pull(ms, me),
        pull('${yearStart.year}-01-01', ymd),
      ]);
      if (!mounted || token != _loadToken) return;

      var leaves = results[0];
      if (leaves.isEmpty) leaves = results[1];
      final allLeaves = <ManagerEmployeeLeaveRequest>[
        ...results[0],
        ...results[1],
        ...results[2],
      ];

      // Prefer approved > pending > rejected for the day (On Leave days are approved).
      ManagerEmployeeLeaveRequest? approved;
      ManagerEmployeeLeaveRequest? pending;
      ManagerEmployeeLeaveRequest? rejected;
      for (final item in leaves) {
        final start = ManagerTeamLeaveItem.parseLeaveDate(item.fromDate);
        if (start == null) continue;
        final end = ManagerTeamLeaveItem.parseLeaveDate(item.toDate) ?? start;
        final d = DateTime(day.year, day.month, day.day);
        if (d.isBefore(start) || d.isAfter(end)) continue;
        final status = (item.status ?? '').toLowerCase();
        if (status.contains('reject') ||
            status.contains('deny') ||
            status.contains('decline') ||
            status.contains('cancel')) {
          rejected ??= item;
          continue;
        }
        if (status.contains('pend') ||
            status.contains('await') ||
            status.contains('submit') ||
            status.contains('review') ||
            status == 'new' ||
            status == 'requested' ||
            status == 'leave_requested' ||
            status.contains('request')) {
          pending ??= item;
          continue;
        }
        // Blank / approved / unknown — same as employee leave overlay.
        approved ??= item;
        if (status.contains('approv') || status.contains('accept')) break;
      }
      final covering = approved ?? pending ?? rejected;

      final leave = covering == null
          ? ManagerLeaveView.placeholder(
              day: day,
              userId: userId,
              employeeName: widget.employeeName,
            )
          : ManagerLeaveView.fromEmployeeLeave(
              covering,
              userId: userId,
              employeeName: widget.employeeName,
            );

      if (!mounted || token != _loadToken) return;
      setState(() {
        _leave = leave;
        _lastLeaveLabel = ManagerLeaveDetailSheet._lastLeaveLabel(
          leaves: allLeaves,
          currentId: leave.id?.toString(),
          before: day,
        );
        _loadingDetails = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() => _loadingDetails = false);
    }
  }

  bool get _isPending => _leave.status == LeaveRequestStatus.pending;
  bool get _isApproved => _leave.status == LeaveRequestStatus.approved;
  bool get _isRejected => _leave.status == LeaveRequestStatus.rejected;

  Future<void> _review(String action) async {
    final leaveId = _leave.id;
    if (leaveId == null) {
      ToastHelper.error(context, message: 'Leave id missing.');
      return;
    }
    setState(() => _busy = true);
    final result = await bindings.managerOverviewService.reviewTeamLeave(
      leaveId: leaveId,
      action: action,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Unable to $action leave',
      );
      return;
    }
    ToastHelper.success(
      context,
      message: action == 'approve' ? 'Leave approved' : 'Leave rejected',
    );
    // Return the action so Alerts can archive the card as approved/rejected.
    Navigator.pop(context, action);
  }

  Future<void> _edit() async {
    final existing = _leave.toLeaveRequest();
    // Close detail first so AppSheet can present the edit sheet.
    Navigator.pop(context);
    await Future<void>.delayed(Duration.zero);
    final host = rootNavigatorKey.currentContext;
    if (host == null || !host.mounted) return;
    await ApplyLeaveSheet.show(host, existing: existing);
  }

  void _openProfile() {
    final data = ManagerAttendanceDetailsData(
      day: widget.headerDate ?? _leave.startDate,
      name: widget.employeeName ?? _leave.employeeName ?? 'Employee',
      role: widget.employeeRole ?? 'Employee',
      photo: _resolvedPhoto(context),
      userId: _leave.userId,
    );
    ManagerEmployeeProfileSheet.show(context: context, data: data);
  }

  Future<void> _openAttendanceHistory() async {
    if (_loadingDetails) return;
    final selected = await ManagerEmployeeAttendanceSheet.show(
      context: context,
      employeeName: widget.employeeName ?? _leave.employeeName ?? 'Employee',
      userId: _leave.userId ?? widget.loadForDayUserId,
      role: widget.employeeRole,
      photo: _resolvedPhoto(context),
      // Return leave days here so we reload this sheet instead of stacking.
      selectLeaveDay: true,
    );
    if (!mounted || selected == null) return;
    final sameDay =
        selected.year == _day.year &&
        selected.month == _day.month &&
        selected.day == _day.day;
    if (sameDay && !_loadingDetails) return;
    await _loadDayLeave(forDay: selected);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final name = widget.employeeName ?? _leave.employeeName ?? 'Employee';
    final title =
        '${_leave.typeName} - ${LeaveFormat.daysLabel(_leave.dayCount)}';
    final lastLeave = _lastLeaveLabel?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: AppText.h5(
                  title,
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
        ),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
        Flexible(
          child: ColoredBox(
            color: kbackground1,
            child: _loadingDetails
                ? const Center(child: ShimmerProgress())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (lastLeave != null && lastLeave.isNotEmpty)
                          _lastLeaveBanner(lastLeave),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Leave summary first, then profile with a clear gap.
                              _summaryCard(),
                              const SizedBox(height: 16),
                              _profileCard(name),
                              const SizedBox(height: 12),
                              _detailsCard(),
                              const SizedBox(height: 20),
                              AppText.h5(
                                'Timeline',
                                weight: FontWeight.w600,
                                align: TextAlign.left,
                              ),
                              const SizedBox(height: 12),
                              LeaveTimelineCards(
                                events: _leave.timeline,
                                onAddReason: _isRejected ? _edit : null,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: MyButton(
                                  width: 160,
                                  height: 44,
                                  size: MyButtonSize.normal,
                                  buttonText: 'Edit Request',
                                  backgroundColor: kWhite,
                                  fontColor: kBlack,
                                  outlineColor: kBorderColor,
                                  hasicon: true,
                                  leftWidget: CommonImageView(
                                    imagePath: Assets.imagesPen,
                                    height: 14,
                                  ),
                                  isactive: !_busy,
                                  onTap: _edit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
          child: _busy || _loadingDetails
              ? const Center(child: ShimmerProgress(strokeWidth: 2))
              : _footerActions(),
        ),
      ],
    );
  }

  Widget _profileCard(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: _employeeHeader(name),
    );
  }

  Widget _footerActions() {
    if (_isPending) {
      return Row(
        children: [
          Expanded(
            child: MyButton(
              height: 48,
              size: MyButtonSize.normal,
              buttonText: 'Reject',
              backgroundColor: kredColor,
              fontColor: kWhite,
              onTap: () => _review('reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MyButton(
              height: 48,
              size: MyButtonSize.normal,
              buttonText: 'Approve',
              backgroundColor: kPrimaryColor,
              fontColor: kWhite,
              onTap: () => _review('approve'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: MyButton(
            height: 48,
            size: MyButtonSize.normal,
            buttonText: 'Change',
            backgroundColor: kWhite,
            fontColor: kBlack,
            outlineColor: kBorderColor,
            hasicon: true,
            leftWidget: CommonImageView(
              imagePath: Assets.imagesPen,
              height: 14,
            ),
            onTap: _edit,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Center(child: _statusBadge())),
      ],
    );
  }

  Widget _statusBadge() {
    final approved = _isApproved;
    final color = approved ? kPrimaryColor : kredColor;
    final label = approved ? 'Approved' : 'Rejected';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          approved ? Icons.check : Icons.close,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 8),
        AppText.p1(
          label,
          color: color,
          weight: FontWeight.w600,
        ),
      ],
    );
  }

  Widget _lastLeaveBanner(String label) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kbackground,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          CommonImageView(imagePath: Assets.imagesInfoCircle, height: 16),
          const SizedBox(width: 8),
          Expanded(
            child: AppText.p2(
              label,
              color: kSubText,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeHeader(String name) {
    final photo = _resolvedPhoto(context)?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;
    final isNetwork =
        hasPhoto && (photo.startsWith('http') || photo.startsWith('//'));
    return Row(
      children: [
        ClipOval(
          child: CommonImageView(
            url: isNetwork ? photo : null,
            imagePath: isNetwork ? null : (photo ?? Assets.imagesUserimage),
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
                name,
                color: kBlack,
                weight: FontWeight.w600,
                align: TextAlign.left,
              ),
              if (widget.employeeRole != null &&
                  widget.employeeRole!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                AppText.caption(
                  widget.employeeRole!,
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
          child: CommonImageView(imagePath: Assets.PersonIconSheet, height: 45),
        ),
        const SizedBox(width: 8),
        ButtonAnimations.press(
          onTap: _openAttendanceHistory,
          child: CommonImageView(
            imagePath: Assets.AttendanceIconSheet,
            height: 45,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.p2(
                      'Leave',
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    AppText.h4(
                      _leave.typeName,
                      color: kPurple,
                      weight: FontWeight.w700,
                      align: TextAlign.left,
                    ),
                  ],
                ),
              ),
              LeaveStatusChip(status: _leave.status),
            ],
          ),
          const SizedBox(height: 10),
          AppText.p2(
            LeaveFormat.rangeWithDays(
              _leave.startDate,
              _leave.endDate,
              _leave.dayCount,
            ),
            color: kGreyColor,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    Widget row(String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: AppText.p2(
                label,
                color: kGreyColor,
                weight: FontWeight.w400,
                align: TextAlign.left,
              ),
            ),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.only(right: 12),
              color: kBorderColor,
            ),
            Expanded(child: value),
          ],
        ),
      );
    }

    final documentName = _leave.documentName?.trim();
    final hasDocument = documentName != null && documentName.isNotEmpty;
    final note = _leave.note?.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            'Days',
            AppText.p2(
              LeaveFormat.daysLabel(_leave.dayCount),
              color: kGreyColor,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          row(
            'Dates',
            AppText.p2(
              LeaveFormat.range(_leave.startDate, _leave.endDate),
              color: kGreyColor,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          row(
            'Type',
            AppText.p2(
              _leave.typeName,
              color: kGreyColor,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          row(
            'Document',
            Row(
              children: [
                Expanded(
                  child: AppText.p2(
                    hasDocument ? documentName : '--',
                    color: kGreyColor,
                    weight: FontWeight.w400,
                    align: TextAlign.left,
                  ),
                ),
                if (hasDocument)
                  AppText.p2('View', color: kPurple, weight: FontWeight.w500),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p2(
                  'Note',
                  color: kGreyColor,
                  weight: FontWeight.w400,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 6),
                AppText.p2(
                  (note == null || note.isEmpty) ? '--' : note,
                  color: kGreyColor,
                  weight: FontWeight.w400,
                  align: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerLeaveView {
  const ManagerLeaveView({
    required this.id,
    required this.typeName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    required this.timeline,
    this.userId,
    this.employeeName,
    this.note,
    this.documentName,
  });

  final int? id;
  final String typeName;
  final LeaveRequestStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;
  final List<LeaveTimelineEvent> timeline;
  final int? userId;
  final String? employeeName;
  final String? note;
  final String? documentName;

  factory ManagerLeaveView.fromTeamItem(ManagerTeamLeaveItem item) {
    final start = _parseDate(item.dateFrom) ?? DateTime.now();
    final end = _parseDate(item.dateTo) ?? start;
    final days = end.difference(start).inDays.abs() + 1;
    final status = item.isRejectedLeave
        ? LeaveRequestStatus.rejected
        : item.isPendingInInbox
            ? LeaveRequestStatus.pending
            : item.countsAsOnLeave
                ? LeaveRequestStatus.approved
                : _statusFrom(item.status ?? item.statusLabel);
    return ManagerLeaveView(
      id: item.id,
      typeName: (item.leaveType ?? 'Leave').trim().isEmpty
          ? 'Leave'
          : item.leaveType!.trim(),
      status: status,
      startDate: start,
      endDate: end,
      dayCount: days,
      userId: item.userId,
      employeeName: item.employeeName,
      note: item.note,
      documentName: item.documentName,
      timeline: _timelineFor(status: status, at: start),
    );
  }

  factory ManagerLeaveView.fromEmployeeLeave(
    ManagerEmployeeLeaveRequest leave, {
    int? userId,
    String? employeeName,
  }) {
    final start = _parseDate(leave.fromDate) ?? DateTime.now();
    final end = _parseDate(leave.toDate) ?? start;
    final parsedDays = int.tryParse((leave.days ?? '').split(' ').first);
    final days = parsedDays ?? end.difference(start).inDays.abs() + 1;
    final status = _statusFrom(leave.status);
    final note = leave.reason;
    return ManagerLeaveView(
      id: int.tryParse(leave.id),
      typeName: (leave.type ?? 'Leave').trim().isEmpty
          ? 'Leave'
          : leave.type!.trim(),
      status: status,
      startDate: start,
      endDate: end,
      dayCount: days,
      userId: userId,
      employeeName: employeeName,
      note: note,
      timeline: _timelineFor(
        status: status,
        at: start,
        rejectionReason: status == LeaveRequestStatus.rejected ? note : null,
      ),
    );
  }

  factory ManagerLeaveView.placeholder({
    required DateTime day,
    int? userId,
    String? employeeName,
    String? note,
  }) {
    return ManagerLeaveView(
      id: null,
      typeName: 'Leave',
      status: LeaveRequestStatus.approved,
      startDate: day,
      endDate: day,
      dayCount: 1,
      userId: userId,
      employeeName: employeeName,
      note: note,
      timeline: _timelineFor(status: LeaveRequestStatus.approved, at: day),
    );
  }

  LeaveRequest toLeaveRequest() {
    return LeaveRequest(
      id: id?.toString() ?? 'local_${startDate.millisecondsSinceEpoch}',
      typeId: typeName.toLowerCase().replaceAll(' ', '_'),
      typeName: typeName,
      startDate: startDate,
      endDate: endDate,
      status: status,
      note: note ?? '',
      createdAt: startDate,
      timeline: timeline,
      documentName: documentName,
    );
  }

  static LeaveRequestStatus _statusFrom(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.contains('reject') ||
        value.contains('deny') ||
        value.contains('decline') ||
        value.contains('cancel')) {
      return LeaveRequestStatus.rejected;
    }
    if (value.contains('pend') ||
        value.contains('await') ||
        value.contains('submit') ||
        value.contains('review') ||
        value.contains('request') ||
        value == 'new') {
      return LeaveRequestStatus.pending;
    }
    if (value.contains('approv') ||
        value.contains('accept') ||
        value == '1' ||
        value == 'true') {
      return LeaveRequestStatus.approved;
    }
    // Blank / unknown — approved (same as employee leaves + On Leave overlay).
    return LeaveRequestStatus.approved;
  }

  static List<LeaveTimelineEvent> _timelineFor({
    required LeaveRequestStatus status,
    required DateTime at,
    String? rejectionReason,
  }) {
    final events = <LeaveTimelineEvent>[
      LeaveTimelineEvent(
        id: 'requested',
        kind: LeaveTimelineKind.requested,
        at: at,
      ),
    ];
    String? actor;
    try {
      actor = bindings.authProvider.user?.name;
    } catch (_) {
      actor = null;
    }
    if (status == LeaveRequestStatus.approved) {
      events.insert(
        0,
        LeaveTimelineEvent(
          id: 'approved',
          kind: LeaveTimelineKind.approved,
          at: at,
          actorName: actor,
        ),
      );
    } else if (status == LeaveRequestStatus.rejected) {
      events.insert(
        0,
        LeaveTimelineEvent(
          id: 'rejected',
          kind: LeaveTimelineKind.rejected,
          at: at,
          actorName: actor,
          reason: rejectionReason,
        ),
      );
    }
    return events;
  }

  static DateTime? _parseDate(String? raw) {
    return ManagerTeamLeaveItem.parseLeaveDate(raw);
  }
}
