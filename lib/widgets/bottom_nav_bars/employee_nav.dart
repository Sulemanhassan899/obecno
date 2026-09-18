import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:obecno/features/alerts/providers/alerts_provider.dart';
import 'package:obecno/features/employee_module/attendance/presentation/screens/attendence_screen.dart';
import 'package:obecno/features/clock/presentation/screens/clock_screen.dart';
import 'package:obecno/features/join/presentation/widgets/unverified_account_banner.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/join/services/join_device_auto_approve.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/presentation/screens/profile_settings_screen.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/widgets/bottom_nav_bars/alerts_nav_icon.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class EmployeeBottomNavBar extends StatefulWidget {
  const EmployeeBottomNavBar({super.key});

  static final ValueNotifier<int> _alertsTick = ValueNotifier(0);
  static bool openAlertsOnBuild = false;

  static void goToAlerts() {
    openAlertsOnBuild = true;
    _alertsTick.value++;
  }

  @override
  State<EmployeeBottomNavBar> createState() => _EmployeeBottomNavBarState();
}

class _EmployeeBottomNavBarState extends State<EmployeeBottomNavBar> {
  int selectedIndex = 0;
  JoinInviteProvider? _join;

  final GlobalKey<ClockScreenState> _clockKey = GlobalKey<ClockScreenState>();
  final GlobalKey<EmployeeAttendanceScreenState> _attendanceKey =
      GlobalKey<EmployeeAttendanceScreenState>();

  late final List<Widget> screens = [
    ClockScreen(key: _clockKey),
    EmployeeAttendanceScreen(key: _attendanceKey),
    const AlertsScreen(),
    ProfileSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (EmployeeBottomNavBar.openAlertsOnBuild) {
      selectedIndex = 2;
      EmployeeBottomNavBar.openAlertsOnBuild = false;
    }
    EmployeeBottomNavBar._alertsTick.addListener(_openAlerts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _join = context.read<JoinInviteProvider>();
      _join!.addListener(_syncJoinDeviceApproval);
      unawaited(_join!.ensureLoaded().then((_) {
        if (!mounted) return;
        _syncJoinDeviceApproval();
      }));
    });
  }

  void _syncJoinDeviceApproval() {
    if (!mounted) return;
    JoinDeviceAutoApprove.sync(
      auth: context.read<AuthProvider>(),
      join: context.read<JoinInviteProvider>(),
      devices: context.read<DeviceProvider>(),
    );
  }

  void _openAlerts() {
    if (!mounted) return;
    setState(() {
      selectedIndex = 2;
      EmployeeBottomNavBar.openAlertsOnBuild = false;
    });
    context.read<AlertsProvider>().markAlertsSeen();
  }

  @override
  void dispose() {
    _join?.removeListener(_syncJoinDeviceApproval);
    EmployeeBottomNavBar._alertsTick.removeListener(_openAlerts);
    super.dispose();
  }

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
    final showAlertsBadge = context.watch<AlertsProvider>().showNavBadge;
    final showUnverified =
        context.watch<JoinInviteProvider>().showUnverifiedBanner;
    return Scaffold(
      body: Column(
        children: [
          if (showUnverified)
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: UnverifiedAccountBanner(),
              ),
            ),
          Expanded(
            child: IndexedStack(index: selectedIndex, children: screens),
          ),
        ],
      ),
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
                    if (index == 2) {
                      context.read<AlertsProvider>().markAlertsSeen();
                    }
                    if (index == 0 && previousIndex != 0) {
                      _clockKey.currentState?.notifyTabResumed();
                    }
                    if (index == 1 && previousIndex != 1) {
                      _attendanceKey.currentState?.notifyTabResumed();
                    }
                  },
                  child: GestureDetector(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        index == 2
                            ? AlertsNavIcon(
                                selected: isSelected,
                                showBadge: showAlertsBadge,
                              )
                            : CommonImageView(
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
