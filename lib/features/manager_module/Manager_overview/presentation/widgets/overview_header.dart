import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/presentation/screens/all_employees_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/all_locations_screen.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/add_employee_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/date_picker.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/monthly_picker.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/new_location_sheet.dart';
import 'package:obecno/widgets/bottom_nav_bars/manager_nav.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/share_button.dart';
import 'package:obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';

/// =======================================================
/// 🔥 REUSABLE DATE WIDGET
/// =======================================================
class ReusableDateRow extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime>? onDateSelected;

  const ReusableDateRow({super.key, required this.date, this.onDateSelected});

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
    return ButtonAnimations.press(
      onTap: () {
        DateMonthYearPickerSheet.show(
          context,
          initialDate: date,
          onSelected: (selectedDate) {
            onDateSelected?.call(selectedDate);
          },
        );
      },
      child: Row(
        children: [
          CommonImageView(imagePath: Assets.imagesCalender, height: 14),
          const SizedBox(width: 8),
          AppText.p1(formattedDate, color: kSubText, weight: FontWeight.w500),
          const SizedBox(width: 6),
          CommonImageView(imagePath: Assets.imagesDown, height: 8),
        ],
      ),
    );
  }
}

class MonthYearPickerSheet {
  static void show(
    BuildContext context, {
    required DateTime initialDate,
    required Function(DateTime) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Wrap(
          children: [
            MonthYearContent(initialDate: initialDate, onSelected: onSelected),
          ],
        );
      },
    );
  }
}

/// =======================================================
/// 🔥 HEADER
/// =======================================================
class OverviewHeader extends StatelessWidget {
  const OverviewHeader({super.key, required this.date, this.onDateSelected});

  final DateTime date;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return Row(
      children: [
        /// LEFT
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.h2(isToday ? "Today" : "Overview", align: TextAlign.left),

              const SizedBox(height: 10),

              ReusableDateRow(date: date, onDateSelected: onDateSelected),
            ],
          ),
        ),
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
    return GridView.count(
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
        ActionTile("All Locations", Assets.imagesLocationIcon, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllLocationsScreen()),
          );
        }),
        ActionTile(
          "Add Employee",
          Assets.imagesAddEmployee,
          () => AddEmployeeSheet.show(context),
        ),
        ActionTile("All Employee", Assets.imagesAllEmployees, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllEmployeesScreen()),
          );
        }),
      ],
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
