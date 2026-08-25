import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/alerts/presentation/screens/alerts_screen.dart';
import 'package:obecno/features/employee_module/attendance/presentation/screens/attendence_screen.dart';
import 'package:obecno/features/clock/presentation/screens/clock_screen.dart';
import 'package:obecno/features/employee_module/more/presentation/screens/profile_settings_screen.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class EmployeeBottomNavBar extends StatefulWidget {
  const EmployeeBottomNavBar({super.key});

  @override
  State<EmployeeBottomNavBar> createState() => _EmployeeBottomNavBarState();
}

class _EmployeeBottomNavBarState extends State<EmployeeBottomNavBar> {
  int selectedIndex = 0;

  // GlobalKey lets us call notifyTabResumed() on ClockScreen's state
  // when the user switches back to the Clock tab.
  final GlobalKey<ClockScreenState> _clockKey = GlobalKey<ClockScreenState>();

  late final List<Widget> screens = [
    ClockScreen(key: _clockKey),
    EmployeeAttendanceScreen(),
    AlertsScreen(),
    ProfileSettingsScreen(),
  ];

  final List<Map<String, dynamic>> items = [
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = selectedIndex == index;

                return ButtonAnimations.press(
                  onTap: () {
                    final previousIndex = selectedIndex;
                    setState(() {
                      selectedIndex = index;
                    });
                    // When switching back to the Clock tab (index 0),
                    // tell the screen to refresh the geofence immediately
                    // so the user sees the correct state without any delay.
                    if (index == 0 && previousIndex != 0) {
                      _clockKey.currentState?.notifyTabResumed();
                    }
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
        ],
      ),
    );
  }
}
