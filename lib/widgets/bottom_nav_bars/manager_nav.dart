import 'dart:async';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:obecno/features/alerts/providers/alerts_provider.dart';
import 'package:obecno/features/alerts/services/alert_navigation.dart';
import 'package:obecno/features/clock/presentation/screens/clock_screen.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/screens/manager_attendence_screen.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/presentation/screens/overview_screen.dart';
import 'package:obecno/features/more/presentation/screens/profile_settings_screen.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/bottom_nav_bars/bottom_nav_item.dart';
import 'package:obecno/widgets/bottom_nav_bars/bottom_nav_metrics.dart';
import 'package:flutter/material.dart';

class ManagerBottomNavBar extends StatefulWidget {
  const ManagerBottomNavBar({super.key});

  static final ValueNotifier<int> _alertsTick = ValueNotifier(0);
  static bool openAlertsOnBuild = false;

  /// Optional Alerts chip: `leaves`, `device`, `reminder`, `check_in`, …
  static String? pendingAlertsFilter;

  /// Optional leave alert key to scroll/highlight on Alerts (Leaves filter).
  static String? pendingAlertsLeaveKey;

  static void goToAlerts({String? filter, String? leaveKey}) {
    pendingAlertsFilter = filter;
    pendingAlertsLeaveKey = leaveKey;
    openAlertsOnBuild = true;
    _alertsTick.value++;
  }

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
  final GlobalKey<OverviewScreenState> _overviewKey =
      GlobalKey<OverviewScreenState>();
  final GlobalKey<ClockScreenState> _clockKey = GlobalKey<ClockScreenState>();
  final GlobalKey<ManagerAttendanceScreenState> _attendanceKey =
      GlobalKey<ManagerAttendanceScreenState>();
  final GlobalKey<AlertsScreenState> _alertsKey =
      GlobalKey<AlertsScreenState>();
  final GlobalKey<ProfileSettingsScreenState> _moreKey =
      GlobalKey<ProfileSettingsScreenState>();

  late final List<Widget> screens = [
    OverviewScreen(key: _overviewKey),
    ClockScreen(key: _clockKey),
    ManagerAttendanceScreen(key: _attendanceKey),
    AlertsScreen(key: _alertsKey),
    ProfileSettingsScreen(key: _moreKey),
  ];

  @override
  void initState() {
    super.initState();
    final openAlerts =
        ManagerBottomNavBar.openAlertsOnBuild || AlertNavigation.pendingOpen;
    final pendingFilter = ManagerBottomNavBar.pendingAlertsFilter;
    final pendingLeaveKey = ManagerBottomNavBar.pendingAlertsLeaveKey;
    if (openAlerts) {
      selectedIndex = 3;
      ManagerBottomNavBar.openAlertsOnBuild = false;
      ManagerBottomNavBar.pendingAlertsFilter = null;
      ManagerBottomNavBar.pendingAlertsLeaveKey = null;
      AlertNavigation.pendingOpen = false;
    }
    ManagerBottomNavBar._alertsTick.addListener(_openAlerts);
    // Employees land on Clock, which arms reminders. Managers land on
    // Overview, so arm the same reminder schedule here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Cold-start openAlertsOnBuild only sets the tab index; clear the red
      // dot once the nav (and AlertsProvider) are actually mounted.
      if (openAlerts || selectedIndex == 3) {
        context.read<AlertsProvider>().setAlertsTabVisible(true);
      }
      if (openAlerts && (pendingFilter != null || pendingLeaveKey != null)) {
        _alertsKey.currentState?.applyFilter(
          pendingFilter ?? 'leaves',
          leaveKey: pendingLeaveKey,
        );
      }
      unawaited(context.read<ReminderSettingsProvider>().activateFromClock());
      unawaited(context.read<JoinInviteProvider>().ensureLoaded());
      if (context.read<AlertsProvider>().isManagerView) {
        unawaited(context.read<AlertsProvider>().syncLeaveAlerts());
      }
    });
  }

  void _openAlerts() {
    if (!mounted) return;
    final filter = ManagerBottomNavBar.pendingAlertsFilter;
    final leaveKey = ManagerBottomNavBar.pendingAlertsLeaveKey;
    ManagerBottomNavBar.pendingAlertsFilter = null;
    ManagerBottomNavBar.pendingAlertsLeaveKey = null;
    setState(() {
      selectedIndex = 3;
      ManagerBottomNavBar.openAlertsOnBuild = false;
    });
    context.read<AlertsProvider>().setAlertsTabVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _alertsKey.currentState?.applyFilter(
        filter ?? (leaveKey != null ? 'leaves' : null),
        leaveKey: leaveKey,
      );
    });
  }

  @override
  void dispose() {
    ManagerBottomNavBar._alertsTick.removeListener(_openAlerts);
    super.dispose();
  }

  void openAttendance({String? statusFilter}) {
    final leftAlerts = selectedIndex == 3;
    setState(() {
      selectedIndex = 2;
      _attendanceStatusFilter = statusFilter;
    });
    if (leftAlerts) {
      context.read<AlertsProvider>().setAlertsTabVisible(false);
    }
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
    final alerts = context.read<AlertsProvider>();
    if (index == 3) {
      alerts.setAlertsTabVisible(true);
    } else if (previousIndex == 3) {
      alerts.setAlertsTabVisible(false);
    }
    if (index == previousIndex) return;
    if (index == 2) {
      unawaited(context.read<ManagerAttendanceProvider>().load());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (index) {
        case 0:
          _overviewKey.currentState?.playEntranceAnimation();
        case 1:
          _clockKey.currentState?.notifyTabResumed();
        case 2:
          _attendanceKey.currentState?.playEntranceAnimation();
        case 3:
          _alertsKey.currentState?.playEntranceAnimation();
        case 4:
          _moreKey.currentState?.playEntranceAnimation();
      }
    });
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
    final alerts = context.watch<AlertsProvider>();
    final joinPending = context.watch<JoinInviteProvider>().managerAlerts().any(
      (e) => e.status == JoinInviteStatus.pendingApproval,
    );
    // Red dot: pending leaves stay until approve/reject; join/unseen can
    // hide while Alerts is open, then return after leaving.
    final showAlertsBadge =
        alerts.hasPendingLeaveAlerts ||
        alerts.hasUnseenAlert ||
        (selectedIndex != 3 && joinPending);
    final metrics = BottomNavMetrics.of(context);
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.paddingH,
          vertical: metrics.paddingV,
        ),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
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
              isAlerts: index == 3,
              showAlertsBadge: showAlertsBadge,
              onTap: () => _selectTab(index),
            );
          }),
        ),
      ),
    );
  }
}
