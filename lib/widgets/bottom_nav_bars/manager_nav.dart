import 'dart:async';

import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/more/presentation/screens/profile_settings_screen.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/features/manager_module/Manager_alerts/presentation/screens/manager_alerts_screen.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/screens/manager_attendence_screen.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/presentation/screens/overview_screen.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/clock/presentation/screens/clock_screen.dart';

import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class ManagerBottomNavBar extends StatefulWidget {
  const ManagerBottomNavBar({super.key});

  /// Switch to Attendance tab with an optional status filter and date.
  static void goToAttendance(
    BuildContext context, {
    String? statusFilter,
    DateTime? date,
    List<ManagerTeamAttendanceItem>? seedItems,
  }) {
    context.read<ManagerAttendanceProvider>().open(
      date: date,
      statusFilter: statusFilter,
      seedItems: seedItems,
    );
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
  final GlobalKey<ClockScreenState> _clockKey = GlobalKey<ClockScreenState>();

  late final List<Widget> screens = [
    const OverviewScreen(),
    ClockScreen(key: _clockKey),
    const ManagerAttendanceScreen(),
    const ManagerAlertsScreen(),
    const ProfileSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Employees land on Clock, which arms reminders. Managers land on
    // Overview, so arm the same reminder schedule here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ReminderSettingsProvider>().activateFromClock());
    });
  }

  void openAttendance({String? statusFilter}) {
    setState(() {
      selectedIndex = 2;
      _attendanceStatusFilter = statusFilter;
    });
  }

  void _selectTab(int index) {
    final previousIndex = selectedIndex;
    setState(() {
      if (index != 2) {
        _attendanceStatusFilter = null;
      } else if (_attendanceStatusFilter == null) {
        context.read<ManagerAttendanceProvider>().setStatus(
          StatusFilterOption.allId,
        );
        context.read<ManagerAttendanceProvider>().setLocation(
          id: LocationFilterOption.allId,
        );
      }
      selectedIndex = index;
    });
    if (index == 1 && previousIndex != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clockKey.currentState?.notifyTabResumed();
      });
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
      body: IndexedStack(index: selectedIndex, children: screens),
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
              onTap: () => _selectTab(index),
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
