import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/demo/demo_list.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/demo/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/features/manager_module/Manager_employees/presentation/screens/all_employees_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/location_setup_screen.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/share_button.dart';
import 'package:obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';

class LocationOverviewScreen extends StatelessWidget {
  const LocationOverviewScreen({super.key, required this.location});

  final ManagerLocationModel location;

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

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  void _openAttendance(BuildContext context) {
    ManagerEmployeeAttendanceSheet.show(
      context: context,
      locationName: location.name,
      locationAddress: location.address,
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
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = dummyManagerAttendance;

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
                            location: location,
                            onStatTap: () => _openAttendance(context),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    SliverList.separated(
                      itemCount: people.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: kDividerColor),
                      itemBuilder: (context, index) {
                        final item = people[index];
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
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationOverviewStatsCard extends StatelessWidget {
  const _LocationOverviewStatsCard({
    required this.location,
    required this.onStatTap,
  });

  final ManagerLocationModel location;
  final VoidCallback onStatTap;

  @override
  Widget build(BuildContext context) {
    final items = <_OverviewStatData>[
      _OverviewStatData(
        value: '${location.present}',
        suffix: ' / ${location.total}',
        valueColor: kPrimaryColor,
        label: 'Present Today',
      ),
      _OverviewStatData(
        value: '24',
        valueColor: kBlue,
        label: 'Active',
        showShare: true,
      ),
      _OverviewStatData(
        value: '04',
        valueColor: kYellowColor,
        label: 'On Break',
        showShare: true,
      ),
      _OverviewStatData(
        value: location.lateCheckIns.toString().padLeft(2, '0'),
        valueColor: kredColor,
        label: 'Late Check-in',
        showShare: true,
      ),
      _OverviewStatData(
        value: '04',
        valueColor: kPurple,
        label: 'On Leaves',
        showShare: true,
      ),
      _OverviewStatData(
        value: '03',
        valueColor: kBlack,
        label: 'Absent',
        showShare: true,
      ),
    ];

    Widget row(int a, int b) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _OverviewStatItem(data: items[a], onTap: onStatTap)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: kDividerColor,
              ),
            ),
            Expanded(child: _OverviewStatItem(data: items[b], onTap: onStatTap)),
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
    this.suffix,
    this.showShare = false,
  });

  final String value;
  final String? suffix;
  final Color valueColor;
  final String label;
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

    if (!data.showShare) return content;
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
