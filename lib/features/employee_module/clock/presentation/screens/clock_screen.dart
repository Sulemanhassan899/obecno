// import 'package:Obecno/features/employee_module/clock/domain/controllers/clock_controller.dart';
// import 'package:Obecno/core/animations/app_animations.dart';
// import 'package:Obecno/core/constants/all_colors.dart';
// import 'package:Obecno/core/constants/app_enums.dart'
//     hide AttendanceActionResult;
// import 'package:Obecno/core/constants/app_sizes.dart';
// import 'package:Obecno/core/constants/text_styles.dart';
// import 'package:Obecno/core/helpers/snackbar_helper.dart';
// import 'package:Obecno/core/utils/demo_list.dart';
// import 'package:Obecno/features/employee_module/clock/domain/controllers/synced_clock_screen_controller.dart';
// import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
// import 'package:Obecno/generated/assets.dart';
// import 'package:Obecno/main.dart';
// import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
// import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendence_card.dart';

// import 'package:Obecno/shared/bottom_sheets/company_detail_sheet.dart';
// import 'package:Obecno/shared/bottom_sheets/location_detail_sheet.dart';

// import 'package:Obecno/shared/widgets/check_in_button.dart';
// import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';

// class ClockScreen extends StatefulWidget {
//   const ClockScreen({super.key});

//   @override
//   State<ClockScreen> createState() => _ClockScreenState();
// }

// class _ClockScreenState extends State<ClockScreen> with RouteAware {
//   late final ClockScreenController _controller;
//   final ClockTicker _ticker = ClockTicker();
//   bool _isActive = true;

//   @override
//   void initState() {
//     super.initState();

//     _controller = SyncedClockScreenController(
//       repository: bindings.clockAttendanceRepository,
//     );
//     _ticker.start();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     final route = ModalRoute.of(context);
//     if (route is PageRoute) {
//       routeObserver.subscribe(this, route);
//     }
//   }

//   @override
//   void didPushNext() {
//     setState(() => _isActive = false);
//     _ticker.stop();
//   }

//   @override
//   void didPopNext() {
//     setState(() => _isActive = true);
//     _ticker.start();
//   }

//   @override
//   void dispose() {
//     routeObserver.unsubscribe(this);
//     _ticker.dispose();
//     _controller.dispose();
//     super.dispose();
//   }

//   String _formattedTime(DateTime now) {
//     final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
//     final minute = now.minute.toString().padLeft(2, '0');
//     return "$hour:$minute";
//   }

//   void _openLocationSheet() async {
//     final result = await showModalBottomSheet<LocationModel>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => LocationBottomSheet(
//         locations: ClockScreenDemoData.locations,
//         selected: _controller.selectedLocationName,
//       ),
//     );
//     if (result != null) {
//       _controller.selectLocation(
//         result.name,
//         inRange: result.address != "No Location",
//       );
//     }
//   }

//   void _openCompanySheet() async {
//     final result = await showModalBottomSheet<CompanyModel>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => CompanyBottomSheet(
//         companys: ClockScreenDemoData.companys,
//         selected: _controller.selectedCompanyName,
//       ),
//     );
//     if (result != null) {
//       _controller.selectCompany(
//         result.name,
//         isCompany: result.address != "No Location",
//       );
//     }
//   }

//   Future<void> _onMainTap() async {
//     final result = await _controller.handleMainTap();

//     final syncedController = _controller as SyncedClockScreenController;

//     // 🔥 PRIORITY: Show server error first
//     if (syncedController.lastServerMessage != null) {
//       SnackbarHelper.showTopToast(
//         context,
//         message: syncedController.lastServerMessage!,
//         backgroundColor: kredColor,
//       );

//       // clear after showing
//       syncedController.lastServerMessage = null;
//       return;
//     }

//     _showResultToast(result);
//   }

//   Future<void> _onBreakTap() async {
//     final result = await _controller.handleBreakTap();
//     _showResultToast(result);
//   }

//   void _showResultToast(AttendanceActionResult result) {
//     if (!mounted) return;
//     switch (result) {
//       case AttendanceActionResult.checkedIn:
//         SnackbarHelper.showTopToast(
//           context,
//           message: "Checked In Successfully",
//           backgroundColor: kBlack,
//           textColor: kWhite,
//           imagePath: Assets.imagesCircleCheckDown,
//         );
//         break;
//       case AttendanceActionResult.checkedOut:
//         SnackbarHelper.showTopToast(
//           context,
//           message: "Checked Out Successfully",
//           backgroundColor: kBlack,
//           textColor: kWhite,
//           imagePath: Assets.imagesCircleCheckUp,
//         );
//         break;
//       case AttendanceActionResult.breakStarted:
//         SnackbarHelper.showTopToast(
//           context,
//           message: "Break Started Successfully",
//           backgroundColor: kBlack,
//           textColor: kWhite,
//           imagePath: Assets.imagesMugHotWhite,
//         );
//         break;
//       case AttendanceActionResult.breakEnded:
//         SnackbarHelper.showTopToast(
//           context,
//           message: "Break End Successfully",
//           backgroundColor: kBlack,
//           textColor: kWhite,
//           imagePath: Assets.imagesCircleCheckTick,
//         );
//         break;
//       case AttendanceActionResult.outOfRange:
//         SnackbarHelper.showTopToast(
//           context,
//           message: "You are out of range",
//           backgroundColor: kredColor,
//         );
//         break;
//       case AttendanceActionResult.none:
//         break;
//     }
//   }

//   ({Color color, String text, bool showBreakBadge}) _configFor(
//     AttendanceDayStatus status,
//   ) {
//     switch (status) {
//       case AttendanceDayStatus.checkedOut:
//         return (color: kPrimaryColor, text: "Check In", showBreakBadge: false);
//       case AttendanceDayStatus.checkedIn:
//       case AttendanceDayStatus.endedBreak:
//         return (color: kredColor, text: "Check Out", showBreakBadge: true);
//       case AttendanceDayStatus.onBreak:
//         return (color: kYellowColor, text: "End Break", showBreakBadge: false);
//       case AttendanceDayStatus.outofRange:
//         return (
//           color: kGreyContainerGreyColor2,
//           text: "Out of Range",
//           showBreakBadge: false,
//         );
//       default:
//         return (
//           color: kGreyContainerGreyColor2,
//           text: "Unavailable",
//           showBreakBadge: false,
//         );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Padding(
//         padding: AppSizes.DEFAULT2,
//         child: ListenableBuilder(
//           listenable: _controller,
//           builder: (context, _) {
//             final status = _controller.effectiveStatus;
//             final config = _configFor(status);
//             final isOnBreak = _controller.isOnBreak;

//             return ListView(
//               children: [
//                 ButtonAnimations.press(
//                   onTap: _openCompanySheet,
//                   child: Row(
//                     spacing: 5,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       AppText.p3(
//                         _controller.selectedCompanyName,
//                         color: isOnBreak ? kGreyContainerGreyColor2 : kBlack,
//                         weight: FontWeight.w600,
//                       ),
//                       const SizedBox(height: 6),
//                       Icon(
//                         size: 20,
//                         weight: 3,
//                         CupertinoIcons.chevron_down,
//                         color: isOnBreak ? kGreyContainerGreyColor2 : kBlack,
//                       ),
//                     ],
//                   ),
//                 ),

//                 if (isOnBreak) ...[
//                   const SizedBox(height: 40),
//                   // Only this label rebuilds every second.
//                   ValueListenableBuilder<DateTime>(
//                     valueListenable: _ticker,
//                     builder: (context, now, _) => AppText.p1(
//                       "Break started at ${_formattedTime(now)}",
//                       color: kYellowColorLight,
//                       weight: FontWeight.w400,
//                     ),
//                   ),
//                 ],

//                 const SizedBox(height: 40),
//                 ValueListenableBuilder<DateTime>(
//                   valueListenable: _ticker,
//                   builder: (context, now, _) => AppText.bigNumber3(
//                     _formattedTime(now),
//                     weight: FontWeight.w400,
//                   ),
//                 ),

//                 if (!isOnBreak) ...[
//                   const SizedBox(height: 8),
//                   ValueListenableBuilder<DateTime>(
//                     valueListenable: _ticker,
//                     builder: (context, now, _) => AppText.p3(
//                       AttendanceFormat.weekdayDate(now),
//                       color: kGreyColor,
//                       weight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                 ],

//                 CheckInButton(
//                   size: 250,
//                   color: config.color,
//                   text: config.text,
//                   enabled: _controller.isButtonEnabled,
//                   showBreakBadge: config.showBreakBadge,
//                   breakBadgeText: "Break",
//                   breakBadgeColor: kYellowColor,
//                   onTap: _onMainTap,
//                   onBreakTap: _onBreakTap,
//                   isOnBreak: status == AttendanceDayStatus.onBreak,
//                   isActive:
//                       _isActive && status != AttendanceDayStatus.outofRange,
//                   isLoading: _controller.isProcessing,
//                 ),

//                 const SizedBox(height: 30),
//                 if (isOnBreak) ...[
//                   AppText.p1(
//                     "Break time end’s at - 02:00 PM",
//                     weight: FontWeight.w400,
//                   ),
//                   const SizedBox(height: 20),
//                 ],

//                 if (!isOnBreak) ...[
//                   ButtonAnimations.press(
//                     onTap: _openLocationSheet,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         CommonImageView(
//                           imagePath: Assets.imagesLocationDot,
//                           height: 12,
//                         ),
//                         const SizedBox(width: 6),
//                         AppText.p2("Location:", color: kGreyColor),
//                         const SizedBox(width: 6),
//                         AppText.p2(
//                           _controller.isInRange
//                               ? _controller.selectedLocationName
//                               : "Not in office range",
//                           color: _controller.isInRange
//                               ? kPrimaryColor
//                               : kredColor,
//                           weight: FontWeight.w600,
//                         ),
//                         const SizedBox(width: 6),
//                         Icon(
//                           size: 20,
//                           weight: 3,
//                           CupertinoIcons.chevron_down,
//                           color: isOnBreak ? kGreyContainerGreyColor2 : kBlack,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],

//                 const SizedBox(height: 30),

//                 (!isOnBreak && _controller.hasAnyEventToday)
//                     ? AttendanceCard(
//                         day: _ticker.value,
//                         events: _controller.events,
//                         onEditAttendance: () {},
//                       )
//                     : const SizedBox.shrink(),
//                 const SizedBox(height: 30),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';

import 'package:Obecno/features/employee_module/clock/domain/controllers/clock_controller.dart';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Obecno/core/constants/app_enums.dart'
    hide AttendanceActionResult;
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/snackbar_helper.dart';
import 'package:Obecno/core/utils/demo_list.dart';
import 'package:Obecno/features/employee_module/clock/domain/controllers/synced_clock_screen_controller.dart';
import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/main.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendence_card.dart';

import 'package:Obecno/shared/bottom_sheets/company_detail_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/location_detail_sheet.dart';

import 'package:Obecno/shared/widgets/check_in_button.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with RouteAware {
  late final ClockScreenController _controller;
  final ClockTicker _ticker = ClockTicker();
  bool _isActive = true;

  // ADDED: real-time monitoring (Clock tab only) -- internet, location and
  // notification permissions. Guarded by `_isActive` throughout so nothing
  // fires while another tab/screen is on top.
  StreamSubscription<bool>? _connectivitySub;
  bool _isOffline = false;
  Timer? _permissionPollTimer; // ADDED: continuous permission polling
  bool _permissionDialogShowing = false; // ADDED: avoid dialog/toast spam

  @override
  void initState() {
    super.initState();

    _controller = SyncedClockScreenController(
      repository: bindings.clockAttendanceRepository,
    );
    _ticker.start();
    _startMonitoring();
  }

  // ADDED: internet monitoring, scoped to the Clock tab.
  void _startMonitoring() {
    ConnectivityService.start();
    _connectivitySub = ConnectivityService.stream.listen((online) {
      if (!mounted || !_isActive) return;
      if (!online) {
        _isOffline = true;
        SnackbarHelper.showTopToast(
          context,
          message:
              "No internet connection. Your action will be saved and synced automatically once you're back online.",
          backgroundColor: kredColor,
        );
      } else if (_isOffline) {
        _isOffline = false;
        SnackbarHelper.showTopToast(
          context,
          message: "Back online. Syncing pending attendance...",
          backgroundColor: kBlack,
          textColor: kWhite,
        );
      }
    });
    _checkPermissions();
    // ADDED: keep checking continuously while this tab is active, not just
    // once -- every check still no-ops immediately if `_isActive` is false.
    _permissionPollTimer?.cancel();
    _permissionPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _checkPermissions();
    });
  }

  // ADDED: location + notification permission monitoring, Clock tab only.
  // Checks both the runtime permission grant AND whether location
  // services (GPS) are switched on at the OS level -- same two things
  // `AttendancePermissionService` checks before an actual clock action,
  // so the passive monitor can't say "fine" when a real check-in would
  // still fail.
  Future<void> _checkPermissions() async {
    final permissionsGranted = await PermissionService.areAllPermissionsAllowed();
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final allowed = permissionsGranted && gpsEnabled;
    if (!mounted || !_isActive) return;
    if (!allowed && !_permissionDialogShowing) {
      SnackbarHelper.showTopToast(
        context,
        message: !gpsEnabled
            ? "Please turn on location services to record attendance."
            : "Location and notification permissions are required.",
        backgroundColor: kredColor,
      );
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    if (!mounted || _permissionDialogShowing) return;
    _permissionDialogShowing = true;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permissions required"),
        content: const Text(
          "Location and notification permissions are needed to record your attendance accurately. Please enable them in settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Later"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              PermissionService.openSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    ).then((_) => _permissionDialogShowing = false); // ADDED: allow re-check
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    setState(() => _isActive = false);
    _ticker.stop();
  }

  @override
  void didPopNext() {
    setState(() => _isActive = true);
    _ticker.start();
    _checkPermissions();

    // ✅ ADD THIS: re-check server truth whenever the user comes back to
    // this tab, not just on the very first load. Cheap no-op if nothing
    // drifted; self-heals the button if something changed while the
    // user was elsewhere (another device, an admin edit, a queued
    // action finally syncing, etc).
    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      unawaited(controller.reconcileWithServer());
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _ticker.dispose();
    _controller.dispose();
    _connectivitySub?.cancel();
    _permissionPollTimer?.cancel();
    super.dispose();
  }

  String _formattedTime(DateTime now) {
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  void _openLocationSheet() async {
    final result = await showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationBottomSheet(
        locations: ClockScreenDemoData.locations,
        selected: _controller.selectedLocationName,
      ),
    );
    if (result != null) {
      _controller.selectLocation(
        result.name,
        inRange: result.address != "No Location",
      );
    }
  }

  void _openCompanySheet() async {
    final result = await showModalBottomSheet<CompanyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanyBottomSheet(
        companys: ClockScreenDemoData.companys,
        selected: _controller.selectedCompanyName,
      ),
    );
    if (result != null) {
      _controller.selectCompany(
        result.name,
        isCompany: result.address != "No Location",
      );
    }
  }

  Future<void> _onMainTap() async {
    final result = await _controller.handleMainTap();

    final syncedController = _controller as SyncedClockScreenController;

    // 🔥 PRIORITY: Show server error first
    if (syncedController.lastServerMessage != null) {
      SnackbarHelper.showTopToast(
        context,
        message: syncedController.lastServerMessage!,
        backgroundColor: kredColor,
      );

      // clear after showing
      syncedController.lastServerMessage = null;
      return;
    }

    _showResultToast(result);
  }

  Future<void> _onBreakTap() async {
    final result = await _controller.handleBreakTap();
    _showResultToast(result);
  }

  void _showResultToast(AttendanceActionResult result) {
    if (!mounted) return;
    switch (result) {
      case AttendanceActionResult.checkedIn:
        SnackbarHelper.showTopToast(
          context,
          message: "Checked In Successfully",
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesCircleCheckDown,
        );
        break;
      case AttendanceActionResult.checkedOut:
        SnackbarHelper.showTopToast(
          context,
          message: "Checked Out Successfully",
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesCircleCheckUp,
        );
        break;
      case AttendanceActionResult.breakStarted:
        SnackbarHelper.showTopToast(
          context,
          message: "Break Started Successfully",
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesMugHotWhite,
        );
        break;
      case AttendanceActionResult.breakEnded:
        SnackbarHelper.showTopToast(
          context,
          message: "Break End Successfully",
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesCircleCheckTick,
        );
        break;
      case AttendanceActionResult.outOfRange:
        SnackbarHelper.showTopToast(
          context,
          message: "You are out of range",
          backgroundColor: kredColor,
        );
        break;
      case AttendanceActionResult.none:
        break;
    }
  }

  ({Color color, String text, bool showBreakBadge}) _configFor(
    AttendanceDayStatus status,
  ) {
    switch (status) {
      case AttendanceDayStatus.checkedOut:
        return (color: kPrimaryColor, text: "Check In", showBreakBadge: false);
      case AttendanceDayStatus.checkedIn:
      case AttendanceDayStatus.endedBreak:
        return (color: kredColor, text: "Check Out", showBreakBadge: true);
      case AttendanceDayStatus.onBreak:
        return (color: kYellowColor, text: "End Break", showBreakBadge: false);
      case AttendanceDayStatus.outofRange:
        return (
          color: kGreyContainerGreyColor2,
          text: "Out of Range",
          showBreakBadge: false,
        );
      default:
        return (
          color: kGreyContainerGreyColor2,
          text: "Unavailable",
          showBreakBadge: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppSizes.DEFAULT2,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final status = _controller.effectiveStatus;
            final config = _configFor(status);
            final isOnBreak = _controller.isOnBreak;

            return ListView(
              children: [
                ButtonAnimations.press(
                  onTap: _openCompanySheet,
                  child: Row(
                    spacing: 5,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText.p3(
                        _controller.selectedCompanyName,
                        color: isOnBreak ? kGreyContainerGreyColor2 : kBlack,
                        weight: FontWeight.w600,
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        size: 20,
                        weight: 3,
                        CupertinoIcons.chevron_down,
                        color: isOnBreak ? kGreyContainerGreyColor2 : kBlack,
                      ),
                    ],
                  ),
                ),

                if (isOnBreak) ...[
                  const SizedBox(height: 40),
                  // Only this label rebuilds every second.
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _ticker,
                    builder: (context, now, _) => AppText.p1(
                      "Break started at ${_formattedTime(now)}",
                      color: kYellowColorLight,
                      weight: FontWeight.w400,
                    ),
                  ),
                ],

                const SizedBox(height: 40),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _ticker,
                  builder: (context, now, _) => AppText.bigNumber3(
                    _formattedTime(now),
                    weight: FontWeight.w400,
                  ),
                ),

                if (!isOnBreak) ...[
                  const SizedBox(height: 8),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _ticker,
                    builder: (context, now, _) => AppText.p3(
                      AttendanceFormat.weekdayDate(now),
                      color: kGreyColor,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                CheckInButton(
                  size: 250,
                  color: config.color,
                  text: config.text,
                  enabled: _controller.isButtonEnabled,
                  showBreakBadge: config.showBreakBadge,
                  breakBadgeText: "Break",
                  breakBadgeColor: kYellowColor,
                  onTap: _onMainTap,
                  onBreakTap: _onBreakTap,
                  isOnBreak: status == AttendanceDayStatus.onBreak,
                  isActive:
                      _isActive && status != AttendanceDayStatus.outofRange,
                  isLoading: _controller.isProcessing,
                ),

                const SizedBox(height: 30),
                if (isOnBreak) ...[
                  AppText.p1(
                    "Break time end’s at - 02:00 PM",
                    weight: FontWeight.w400,
                  ),
                  const SizedBox(height: 20),
                ],

                if (!isOnBreak) ...[
                  ButtonAnimations.press(
                    onTap: _openLocationSheet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CommonImageView(
                          imagePath: Assets.imagesLocationDot,
                          height: 12,
                        ),
                        const SizedBox(width: 6),
                        AppText.p2("Location:", color: kGreyColor),
                        const SizedBox(width: 6),
                        AppText.p2(
                          _controller.isInRange
                              ? _controller.selectedLocationName
                              : "Not in office range",
                          color: _controller.isInRange
                              ? kPrimaryColor
                              : kredColor,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          size: 20,
                          weight: 3,
                          CupertinoIcons.chevron_down,
                          color: isOnBreak ? kGreyContainerGreyColor2 : kBlack,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                (!isOnBreak && _controller.hasAnyEventToday)
                    ? AttendanceCard(
                        day: _ticker.value,
                        events: _controller.events,
                        onEditAttendance: () {},
                      )
                    : const SizedBox.shrink(),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }
}