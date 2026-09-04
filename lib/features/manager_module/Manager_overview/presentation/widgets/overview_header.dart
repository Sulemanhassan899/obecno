import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/presentation/screens/all_employees_screen.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/all_locations_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/add_employee_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/new_location_sheet.dart';
import 'package:obecno/widgets/bottom_nav_bars/manager_nav.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/share_button.dart';
import 'package:obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';

/// =======================================================
/// 🔥 READ-ONLY TODAY DATE
/// =======================================================
class ReusableDateRow extends StatelessWidget {
  final DateTime date;

  const ReusableDateRow({super.key, required this.date});

  String get formattedDate {
    return "${date.day} ${_monthName(date.month)} ${date.year}";
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CommonImageView(imagePath: Assets.imagesCalender, height: 14),
        const SizedBox(width: 8),
        AppText.p1(formattedDate, color: kSubText, weight: FontWeight.w500),
      ],
    );
  }
}

/// =======================================================
/// 🔥 HEADER
/// =======================================================
class OverviewHeader extends StatelessWidget {
  const OverviewHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.h2("Today", align: TextAlign.left),
        const SizedBox(height: 10),
        ReusableDateRow(date: DateTime.now()),
      ],
    );
  }
}

class OverviewStatsCard extends StatelessWidget {
  final OverviewSummary summary;

  const OverviewStatsCard({super.key, required this.summary});

  /// Stack only on very tight widths; phones keep the 2-column design.
  static const double _narrowBreakpoint = 280;

  @override
  Widget build(BuildContext context) {
    final items = <_StatData>[
      _StatData(
        value: "${summary.presentToday}",
        suffix: " / ${summary.totalTeamMembers}",
        valueColor: kPrimaryColor,
        label: "Present Today",
        showShare: false,
      ),
      _StatData(
        value: summary.active.toString().padLeft(2, '0'),
        valueColor: kPurple,
        label: "Active",
        showShare: true,
        statusFilter: "Active",
      ),
      _StatData(
        value: summary.onBreak.toString().padLeft(2, '0'),
        valueColor: kYellowColor,
        label: "On Break",
        showShare: true,
        statusFilter: "On Break",
      ),
      _StatData(
        value: summary.lateCheckIn.toString().padLeft(2, '0'),
        valueColor: kredColor,
        label: "Late Check-in",
        showShare: true,
        statusFilter: "Late",
      ),
      _StatData(
        value: summary.absent.toString().padLeft(2, '0'),
        valueColor: kBlack,
        label: "Absent",
        showShare: true,
        statusFilter: "Absent",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _narrowBreakpoint;
        final horizontalPad = isNarrow ? 14.0 : 20.0;
        final verticalPad = isNarrow ? 14.0 : 18.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: verticalPad,
          ),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorderColor),
          ),
          child: isNarrow
              ? _StackedStats(items: items)
              : _GridStats(items: items),
        );
      },
    );
  }
}

class _StatData {
  const _StatData({
    required this.value,
    required this.valueColor,
    required this.label,
    required this.showShare,
    this.suffix,
    this.statusFilter,
  });

  final String value;
  final String? suffix;
  final Color valueColor;
  final String label;
  final bool showShare;

  /// Status filter passed to [ManagerAttendanceScreen] when tapped.
  final String? statusFilter;
}

class _GridStats extends StatelessWidget {
  const _GridStats({required this.items});

  final List<_StatData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatItem(data: items[0])),
              const _VerticalStatDivider(),
              Expanded(child: _StatItem(data: items[1])),
            ],
          ),
        ),
        const _HorizontalStatDivider(),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatItem(data: items[2])),
              const _VerticalStatDivider(),
              Expanded(child: _StatItem(data: items[3])),
            ],
          ),
        ),
        const _HorizontalStatDivider(),
        _StatItem(data: items[4]),
      ],
    );
  }
}

class _StackedStats extends StatelessWidget {
  const _StackedStats({required this.items});

  final List<_StatData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const _HorizontalStatDivider(),
          _StatItem(data: items[i]),
        ],
      ],
    );
  }
}

class _HorizontalStatDivider extends StatelessWidget {
  const _HorizontalStatDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: kDividerColor),
    );
  }
}

class _VerticalStatDivider extends StatelessWidget {
  const _VerticalStatDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: VerticalDivider(width: 1, thickness: 1, color: kDividerColor),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.data});

  final _StatData data;

  void _onTap(BuildContext context) {
    if (!data.showShare || data.statusFilter == null) return;
    ManagerBottomNavBar.goToAttendance(
      context,
      statusFilter: data.statusFilter,
      date: context.read<ManagerOverviewProvider>().selectedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final valueSize = width < 360 ? 20.0 : (width < 600 ? 24.0 : 28.0);

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
            ShareButton(onTap: () => _onTap(context)),
          ],
        ],
      ),
    );

    if (!data.showShare) return content;

    return ButtonAnimations.press(onTap: () => _onTap(context), child: content);
  }
}

/// =======================================================
/// 🔥 ACTION GRID
/// =======================================================
class OverviewActionsGrid extends StatelessWidget {
  const OverviewActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final overview = context.watch<ManagerOverviewProvider>();
    final employees = context.watch<ManagerEmployeesProvider>();
    final locations = context.watch<ManagerLocationsProvider>();

    final employeeCount = employees.total > 0
        ? employees.total
        : overview.summary?.totalTeamMembers ?? 0;
    final locationCount = locations.locations.length;

    return Column(
      children: [
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          childAspectRatio: 2,
          children: [
            ActionTile(
              "Add Location",
              Assets.imagesAddLocationIcon,
              () => NewLocationSheet.show(context),
            ),
            ActionTile(
              "Add Employee",
              Assets.imagesAddEmployee,
              () => AddEmployeeSheet.show(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DirectoryCard(
          employeeCount: employeeCount,
          locationCount: locationCount,
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.employeeCount,
    required this.locationCount,
  });

  final int employeeCount;
  final int locationCount;

  String _countLabel(int count) => count.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          _DirectoryRow(
            icon: Assets.imagesAllEmployees,
            label: 'Employees',
            count: _countLabel(employeeCount),
            onViewAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllEmployeesScreen()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: kDividerColor),
          ),
          _DirectoryRow(
            icon: Assets.imagesLocationIcon,
            label: 'Locations',
            count: _countLabel(locationCount),
            onViewAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(
                    name: AllLocationsScreen.routeName,
                  ),
                  builder: (_) => const AllLocationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.onViewAll,
  });

  final String icon;
  final String label;
  final String count;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CommonImageView(imagePath: icon, height: 16),
          const SizedBox(width: 12),
          AppText.p2(label, weight: FontWeight.w600, align: TextAlign.left),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: kbackgroundBlueContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AppText.p2(count, color: kBlue2, weight: FontWeight.w600),
          ),
          const Spacer(),
          ButtonAnimations.press(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText.p2('View All',color: kSubText, weight: FontWeight.w400),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 16, color: kSubText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// 🔥 ACTION TILE
/// =======================================================
class ActionTile extends StatelessWidget {
  final String title;
  final String icon;
  final VoidCallback? onTap;

  const ActionTile(this.title, this.icon, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CommonImageView(imagePath: icon, height: 20),
            const SizedBox(height: 10),
            AppText.p2(title, color: kSubText, weight: FontWeight.w500),
          ],
        ),
      ),
    );
  }
}
