import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/features/employee_module/alerts/presentation/screens/alerts_screen.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/screens/attendence_screen.dart';
import 'package:Obecno/features/employee_module/clock/presentation/screens/clock_screen.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/profile_settings_screen.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class EmployeeBottomNavBar extends StatefulWidget {
  const EmployeeBottomNavBar({super.key});

  @override
  State<EmployeeBottomNavBar> createState() => _EmployeeBottomNavBarState();
}

class _EmployeeBottomNavBarState extends State<EmployeeBottomNavBar> {
  int selectedIndex = 0;

  // ✅ ADD SCREENS
  final List<Widget> screens = [
    ClockScreen(),
    MonthlyAttendanceScreen(),
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
      body: screens[selectedIndex],
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
                    setState(() {
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
        ],
      ),
    );
  }
}
