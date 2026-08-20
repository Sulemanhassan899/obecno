import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/profile_settings_screen.dart';
import 'package:Obecno/features/manager_module/Manager_alerts/presentation/screens/manager_alerts_screen.dart';
import 'package:Obecno/features/manager_module/Manager_attendance/presentation/screens/manager_attendence_screen.dart';
import 'package:Obecno/features/manager_module/Manager_overview/presentation/screens/overview_screen.dart';

import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/features/clock/presentation/screens/clock_screen.dart';

import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class ManagerBottomNavBar extends StatefulWidget {
  const ManagerBottomNavBar({super.key});

  /// Switch to Attendance tab with an optional status filter.
  static void goToAttendance(BuildContext context, {String? statusFilter}) {
    context
        .findAncestorStateOfType<_ManagerBottomNavBarState>()
        ?.openAttendance(statusFilter: statusFilter);
  }

  @override
  State<ManagerBottomNavBar> createState() => _ManagerBottomNavBarState();
}

class _ManagerBottomNavBarState extends State<ManagerBottomNavBar> {
  int selectedIndex = 0;
  String? _attendanceStatusFilter;

  void openAttendance({String? statusFilter}) {
    setState(() {
      selectedIndex = 2;
      _attendanceStatusFilter = statusFilter;
    });
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return const OverviewScreen();
      case 1:
        return const ClockScreen();
      case 2:
        return ManagerAttendanceScreen(
          key: ValueKey(_attendanceStatusFilter ?? 'Status'),
          initialStatus: _attendanceStatusFilter,
        );
      case 3:
        return const ManagerAlertsScreen();
      case 4:
      default:
        return const ProfileSettingsScreen();
    }
  }

  final List<Map<String, dynamic>> items = [
    {
      "activeIcon": Assets.navigationActiveOverviewIcon,
      "inactiveIcon": Assets.navigationUnactiveOverviewIcon,
      "label": "Overview",
    },
    {
      "activeIcon": Assets.navigationActiveClockIcon,
      "inactiveIcon": Assets.navigationUnactiveClockIcon,
      "label": "Clock",
    },
    {
      "activeIcon": Assets.navigationActiveAttendenceIcon,
      "inactiveIcon": Assets.navigationUnactiveAttendenceIcon,
      "label": "Attendance",
    },
    {
      "activeIcon": Assets.navigationActiveAlertsIcon,
      "inactiveIcon": Assets.navigationUnactiveAlertsIcon,
      "label": "Alerts",
    },
    {
      "activeIcon": Assets.navigationActiveMoreIcon,
      "inactiveIcon": Assets.navigationUnactiveMoreIcon,
      "label": "More",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screenForIndex(selectedIndex),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = selectedIndex == index;

            return ButtonAnimations.press(
              onTap: () {
                setState(() {
                  if (index != 2) {
                    _attendanceStatusFilter = null;
                  }
                  selectedIndex = index;
                });
              },
              child: GestureDetector(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommonImageView(
                      imagePath: isSelected
                          ? items[index]["activeIcon"]
                          : items[index]["inactiveIcon"],
                      height: 20,
                    ),
                    const SizedBox(height: 6),
                    AppText.p4(
                      items[index]["label"],
                      color: isSelected ? kPrimaryColor : kGreyColor,
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
