import 'dart:async';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/responsive/responsive.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:obecno/features/alerts/providers/alerts_provider.dart';
import 'package:obecno/features/alerts/services/alert_navigation.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/clock/presentation/screens/clock_screen.dart';
import 'package:obecno/features/employee_module/attendance/presentation/screens/attendence_screen.dart';
import 'package:obecno/features/join/presentation/widgets/unverified_account_banner.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/join/services/join_device_auto_approve.dart';
import 'package:obecno/features/more/presentation/screens/profile_settings_screen.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/widgets/bottom_nav_bars/bottom_nav_item.dart';
import 'package:obecno/widgets/bottom_nav_bars/bottom_nav_metrics.dart';
import 'package:flutter/material.dart';

class EmployeeBottomNavBar extends StatefulWidget {
  const EmployeeBottomNavBar({super.key});

  static final ValueNotifier<int> _alertsTick = ValueNotifier(0);
  static bool openAlertsOnBuild = false;

  /// Optional Alerts chip: `reminder`, `device`, `check_in`, …
  static String? pendingAlertsFilter;

  /// Optional leave alert key to scroll/highlight on Alerts (Leaves filter).
  static String? pendingAlertsLeaveKey;

  static void goToAlerts({String? filter, String? leaveKey}) {
    pendingAlertsFilter = filter;
    pendingAlertsLeaveKey = leaveKey;
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
  final GlobalKey<AlertsScreenState> _alertsKey = GlobalKey<AlertsScreenState>();
  final GlobalKey<ProfileSettingsScreenState> _moreKey =
      GlobalKey<ProfileSettingsScreenState>();

  late final List<Widget> screens = [
    ClockScreen(key: _clockKey),
    EmployeeAttendanceScreen(key: _attendanceKey),
    AlertsScreen(key: _alertsKey),
    ProfileSettingsScreen(key: _moreKey),
  ];

  @override
  void initState() {
    super.initState();
    final openAlerts =
        EmployeeBottomNavBar.openAlertsOnBuild || AlertNavigation.pendingOpen;
    final pendingFilter = EmployeeBottomNavBar.pendingAlertsFilter;
    final pendingLeaveKey = EmployeeBottomNavBar.pendingAlertsLeaveKey;
    if (openAlerts) {
      selectedIndex = 2;
      EmployeeBottomNavBar.openAlertsOnBuild = false;
      EmployeeBottomNavBar.pendingAlertsFilter = null;
      EmployeeBottomNavBar.pendingAlertsLeaveKey = null;
      AlertNavigation.pendingOpen = false;
    }
    EmployeeBottomNavBar._alertsTick.addListener(_openAlerts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Cold-start openAlertsOnBuild only sets the tab index; clear the red
      // dot once the nav (and AlertsProvider) are actually mounted.
      if (openAlerts || selectedIndex == 2) {
        context.read<AlertsProvider>().setAlertsTabVisible(true);
      }
      if (openAlerts && (pendingFilter != null || pendingLeaveKey != null)) {
        _alertsKey.currentState?.applyFilter(
          pendingFilter ?? 'leaves',
          leaveKey: pendingLeaveKey,
        );
      }
      unawaited(context.read<AlertsProvider>().syncLeaveAlerts());
      _join = context.read<JoinInviteProvider>();
      _join!.addListener(_syncJoinDeviceApproval);
      unawaited(
        _join!.ensureLoaded().then((_) {
          if (!mounted) return;
          _syncJoinDeviceApproval();
        }),
      );
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
    final filter = EmployeeBottomNavBar.pendingAlertsFilter;
    final leaveKey = EmployeeBottomNavBar.pendingAlertsLeaveKey;
    EmployeeBottomNavBar.pendingAlertsFilter = null;
    EmployeeBottomNavBar.pendingAlertsLeaveKey = null;
    setState(() {
      selectedIndex = 2;
      EmployeeBottomNavBar.openAlertsOnBuild = false;
    });
    context.read<AlertsProvider>().setAlertsTabVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (filter != null || leaveKey != null) {
        _alertsKey.currentState?.applyFilter(
          filter ?? (leaveKey != null ? 'leaves' : null),
          leaveKey: leaveKey,
        );
      } else {
        _alertsKey.currentState?.playEntranceAnimation();
      }
    });
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
    final showUnverified = context
        .watch<JoinInviteProvider>()
        .showUnverifiedBanner;
    final metrics = BottomNavMetrics.of(context);
    return Scaffold(
      body: Column(
        children: [
          if (showUnverified)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.pagePadding(context),
                  8,
                  Responsive.pagePadding(context),
                  0,
                ),
                child: const UnverifiedAccountBanner(),
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
            padding: EdgeInsets.symmetric(
              horizontal: metrics.paddingH,
              vertical: metrics.paddingV,
            ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(items.length, (index) {
                return BottomNavItem(
                  metrics: metrics,
                  label: items[index]["label"] as String,
                  activeIcon: items[index]["activeIcon"] as String,
                  inactiveIcon: items[index]["inactiveIcon"] as String,
                  selected: selectedIndex == index,
                  isAlerts: index == 2,
                  showAlertsBadge: showAlertsBadge,
                  onTap: () {
                    final previousIndex = selectedIndex;
                    setState(() {
                      selectedIndex = index;
                    });
                    final alerts = context.read<AlertsProvider>();
                    if (index == 2) {
                      alerts.setAlertsTabVisible(true);
                    } else if (previousIndex == 2) {
                      alerts.setAlertsTabVisible(false);
                    }
                    if (index == previousIndex) return;
                    switch (index) {
                      case 0:
                        _clockKey.currentState?.notifyTabResumed();
                      case 1:
                        _attendanceKey.currentState?.notifyTabResumed();
                      case 2:
                        _alertsKey.currentState?.playEntranceAnimation();
                      case 3:
                        _moreKey.currentState?.playEntranceAnimation();
                    }
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
