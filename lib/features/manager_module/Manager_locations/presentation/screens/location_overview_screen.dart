import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/presentation/screens/all_employees_screen.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_attendance_stats.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/location_setup_screen.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/share_button.dart';
import 'package:obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';

class LocationOverviewScreen extends StatefulWidget {
  const LocationOverviewScreen({super.key, required this.location});

  final ManagerLocationModel location;

  @override
  State<LocationOverviewScreen> createState() => _LocationOverviewScreenState();
}

class _LocationOverviewScreenState extends State<LocationOverviewScreen> {
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// True after the first location-scoped employees load finishes.
  bool _locationReady = false;

  ManagerLocationModel get location => widget.location;

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    final attendance = context.read<ManagerAttendanceProvider>();
    final employees = context.read<ManagerEmployeesProvider>();
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    await Future.wait([
      attendance.selectedDate == today
          ? attendance.load()
          : attendance.setDate(today),
      employees.load(locationId: location.id),
    ]);
    if (!mounted) return;
    setState(() => _locationReady = true);
  }

  List<ManagerTeamAttendanceItem> _mergedItems({
    required ManagerAttendanceProvider attendance,
    required ManagerEmployeesProvider employees,
  }) {
    if (!_locationReady) return const [];

    return LocationAttendanceStats.merge(
      location: location,
      attendance: attendance.items,
      members: employees.members,
    );
  }

  void _openAttendance(BuildContext context, {String? statusFilter}) {
    ManagerEmployeeAttendanceSheet.show(
      context: context,
      locationId: location.id,
      locationName: location.name,
      locationAddress: location.address,
      statusFilter: statusFilter,
    );
  }

  void _openEmployees(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllEmployeesScreen(locationId: location.id),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSetupScreen(location: location),
      ),
    );
  }

  void _openDetails(BuildContext context, ManagerAttendanceModel employee) {
    final provider = context.read<ManagerAttendanceProvider>();
    final day = provider.selectedDate;
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: day,
      ),
      loadDetails: employee.userId == null
          ? null
          : () => provider.loadEmployeeDay(employee: employee, day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<ManagerAttendanceProvider>();
    final employees = context.watch<ManagerEmployeesProvider>();
    final merged = _mergedItems(attendance: attendance, employees: employees);
    final tiles = TeamAttendanceMapper.toTiles(merged);
    final teamCount = merged.isNotEmpty
        ? merged.length
        : (location.total > 0 ? location.total : 0);
    final summary = OverviewSummary.fromAttendance(
      attendance: merged,
      teamMemberCount: teamCount,
    );
    final onLeaves = merged.where((e) => e.isOnLeave).length;
    final absent = merged.where((e) => !e.hasCheckIn && !e.isOnLeave).length;
    final isInitialLoad =
        !_locationReady ||
        ((attendance.isLoading || employees.isLoading) && merged.isEmpty);
    final hasError =
        (attendance.hasError || employees.hasError) && merged.isEmpty;

    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              BackButtonBg(
                title: location.name,
                padding: EdgeInsets.zero,
                rightWidget: ButtonAnimations.press(
                  onTap: () => _openSettings(context),
                  child: Container(
                    height: 42,
                    width: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: kGreyContainerColor,
                      shape: BoxShape.circle,
                    ),
                    child: CommonImageView(
                      imagePath: Assets.imagesSetting,
                      height: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _OverviewActionCard(
                                    label: 'Attendance',
                                    icon: Assets.ProfileAttendanceIcon,
                                    onTap: () => _openAttendance(context),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _OverviewActionCard(
                                    label: 'Employees',
                                    icon: Assets.PersonIcon,
                                    onTap: () => _openEmployees(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            AppText.h6(
                              'Today Attendance',
                              weight: FontWeight.w700,
                              align: TextAlign.left,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CommonImageView(
                                  imagePath: Assets.imagesCalender,
                                  height: 14,
                                ),
                                const SizedBox(width: 8),
                                AppText.p1(
                                  _todayLabel,
                                  color: kSubText,
                                  weight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _LocationOverviewStatsCard(
                              summary: summary,
                              onLeaves: onLeaves,
                              absent: absent,
                              onStatTap: (status) => _openAttendance(
                                context,
                                statusFilter: status,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      if (isInitialLoad)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (hasError)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppText.p1(
                                    attendance.errorMessage ??
                                        employees.errorMessage ??
                                        'Failed to load location attendance.',
                                    color: kSubText,
                                    align: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (tiles.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: AppText.p1(
                              'No employees assigned to this location.',
                              color: kSubText,
                              align: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        SliverList.separated(
                          itemCount: tiles.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: kDividerColor),
                          itemBuilder: (context, index) {
                            final item = tiles[index];
                            return ManagerAttendanceTile(
                              data: item,
                              onTap: () => _openDetails(context, item),
                            );
                          },
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationOverviewStatsCard extends StatelessWidget {
  const _LocationOverviewStatsCard({
    required this.summary,
    required this.onLeaves,
    required this.absent,
    required this.onStatTap,
  });

  final OverviewSummary summary;
  final int onLeaves;
  final int absent;
  final ValueChanged<String> onStatTap;

  @override
  Widget build(BuildContext context) {
    final items = <_OverviewStatData>[
      _OverviewStatData(
        value: '${summary.presentToday}',
        suffix: ' / ${summary.totalTeamMembers}',
        valueColor: kPrimaryColor,
        label: 'Present Today',
        statusFilter: 'Present',
      ),
      _OverviewStatData(
        value: summary.active.toString().padLeft(2, '0'),
        valueColor: kBlue,
        label: 'Active',
        showShare: true,
        statusFilter: 'Active',
      ),
      _OverviewStatData(
        value: summary.onBreak.toString().padLeft(2, '0'),
        valueColor: kYellowColor,
        label: 'On Break',
        showShare: true,
        statusFilter: 'On Break',
      ),
      _OverviewStatData(
        value: summary.lateCheckIn.toString().padLeft(2, '0'),
        valueColor: kredColor,
        label: 'Late Check-in',
        showShare: true,
        statusFilter: 'Late',
      ),
      _OverviewStatData(
        value: onLeaves.toString().padLeft(2, '0'),
        valueColor: kPurple,
        label: 'On Leaves',
        showShare: true,
        statusFilter: 'On Leaves',
      ),
      _OverviewStatData(
        value: absent.toString().padLeft(2, '0'),
        valueColor: kBlack,
        label: 'Absent',
        showShare: true,
        statusFilter: 'Absent',
      ),
    ];

    Widget row(int a, int b) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _OverviewStatItem(
                data: items[a],
                onTap: () => onStatTap(items[a].statusFilter),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: kDividerColor,
              ),
            ),
            Expanded(
              child: _OverviewStatItem(
                data: items[b],
                onTap: () => onStatTap(items[b].statusFilter),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          row(0, 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: kDividerColor),
          ),
          row(2, 3),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: kDividerColor),
          ),
          row(4, 5),
        ],
      ),
    );
  }
}

class _OverviewStatData {
  const _OverviewStatData({
    required this.value,
    required this.valueColor,
    required this.label,
    required this.statusFilter,
    this.suffix,
    this.showShare = false,
  });

  final String value;
  final String? suffix;
  final Color valueColor;
  final String label;
  final String statusFilter;
  final bool showShare;
}

class _OverviewStatItem extends StatelessWidget {
  const _OverviewStatItem({required this.data, required this.onTap});

  final _OverviewStatData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final valueSize = width < 360 ? 20.0 : 24.0;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextWidget(
                        text: data.value,
                        size: valueSize,
                        weight: FontWeight.w600,
                        color: data.valueColor,
                        fontFamily: AppFonts.Poppins,
                        letterSpacing: -0.56,
                      ),
                      if (data.suffix != null)
                        TextWidget(
                          text: data.suffix!,
                          size: valueSize,
                          weight: FontWeight.w600,
                          color: kSubText,
                          fontFamily: AppFonts.Poppins,
                          letterSpacing: -0.56,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AppText.caption(
                  data.label,
                  color: kGreyColor,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ],
            ),
          ),
          if (data.showShare) ...[
            const SizedBox(width: 8),
            ShareButton(onTap: onTap),
          ],
        ],
      ),
    );

    return ButtonAnimations.press(onTap: onTap, child: content);
  }
}

class _OverviewActionCard extends StatelessWidget {
  const _OverviewActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CommonImageView(imagePath: icon, height: 22),
            const SizedBox(height: 10),
            AppText.p2(label, color: kSubText, weight: FontWeight.w500),
          ],
        ),
      ),
    );
  }
}
