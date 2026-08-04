import 'dart:async';

import 'package:Obecno/core/constants/app_strings.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/features/employee_module/clock/domain/controllers/clock_controller.dart';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:Obecno/widgets/dialog.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Obecno/core/constants/app_enums.dart'
    hide AttendanceActionResult;
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/snackbar_helper.dart';
import 'package:Obecno/features/employee_module/clock/domain/controllers/synced_clock_screen_controller.dart';
import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/main.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendence_card.dart';

import 'package:Obecno/shared/bottom_sheets/company_detail_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/location_detail_sheet.dart';
import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';

import 'package:Obecno/widgets/check_in_button.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => ClockScreenState();
}

class ClockScreenState extends State<ClockScreen>
    with RouteAware, TickerProviderStateMixin {
  late final ClockScreenController _controller;
  final ClockTicker _ticker = ClockTicker();
  bool _isActive = true;
  late final AuthService authService;

  StreamSubscription<bool>? _connectivitySub;
  bool _isOffline = false;
  Timer? _permissionPollTimer;
  bool _permissionDialogShowing = false;
  bool _notificationNudgeShown = false;

  VoidCallback? _authPolicyListener;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();

    final currentUserId = bindings.authProvider.user?.id;
    assert(
      currentUserId != null && currentUserId.isNotEmpty,
      'ClockScreen requires an authenticated user',
    );

    _controller = SyncedClockScreenController(
      repository: bindings.clockAttendanceRepository,
      companyPolicyService: bindings.companyPolicyService,
      syncService: bindings.clockSyncService,
      userId: currentUserId ?? '',
    );

    _controller.addListener(_maybeShowLocationAlert);
    _controller.hydrateFromAuth(
      companyName: bindings.authProvider.companyName,
      locationName: bindings.authProvider.selectedLocationName,
    );

    unawaited(_controller.loadPolicyFrom(bindings.companyPolicyService));

    _authPolicyListener = () {
      if (!mounted) return;
      _controller.hydrateFromAuth(
        companyName: bindings.authProvider.companyName,
        locationName: bindings.authProvider.selectedLocationName,
      );
    };
    bindings.authProvider.addListener(_authPolicyListener!);

    _ticker.start();

    _startMonitoring();
    _entranceController.forward();
  }

  void _maybeShowLocationAlert() {
    if (!mounted) return;
    final controller = _controller;
    if (controller is! SyncedClockScreenController) return;
    final message = controller.lastLocationAlertMessage;
    if (message == null) return;
    controller.lastLocationAlertMessage = null;
    SnackbarHelper.showTopToast(
      context,
      message: message,
      backgroundColor: message == AppStrings.synced ? kBlack : kredColor,
      textColor: message == AppStrings.synced ? kWhite : kWhite,
    );
  }

  void _startMonitoring() {
    ConnectivityService.start();
    _connectivitySub = ConnectivityService.stream.listen((online) {
      if (!mounted || !_isActive) return;
      if (!online) {
        _isOffline = true;
        SnackbarHelper.showTopToast(
          context,
          message: "No internet connection.",
          backgroundColor: kredColor,
        );
      } else if (_isOffline) {
        _isOffline = false;
        SnackbarHelper.showTopToast(
          context,
          message: AppStrings.syncing,
          backgroundColor: kBlack,
          textColor: kWhite,
        );
      }
    });
    _checkPermissions();
    _permissionPollTimer?.cancel();
    _permissionPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _checkPermissions();
    });
  }

  void notifyTabResumed() {
    if (!mounted) return;
    _checkPermissions();
    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      unawaited(controller.refreshGeofenceStatus());
    }
  }

  Future<void> _checkPermissions() async {
    final criticalAllowed =
        await PermissionService.areCriticalPermissionsAllowed();
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final blocked = !criticalAllowed || !gpsEnabled;
    if (!mounted || !_isActive) return;

    if (blocked) {
      if (!_permissionDialogShowing) {
        final missing = await PermissionService.missingPermissions();
        if (!mounted || !_isActive) return;

        final missingCritical = missing
            .where((p) => p != AppPermission.notification)
            .map(PermissionService.label)
            .toList();

        final message = !gpsEnabled
            ? AppStrings.turnOnLocationServices
            : "${missingCritical.join(' and ')} permission${missingCritical.length > 1 ? 's are' : ' is'} required to record attendance.";

        SnackbarHelper.showTopToast(
          context,
          message: message,
          backgroundColor: kredColor,
        );
        _showPermissionDialog(message);
      }
      return;
    }

    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      unawaited(controller.refreshGeofenceStatus());
    }

    if (!_notificationNudgeShown) {
      final notifStatus = await PermissionService.status(
        AppPermission.notification,
      );
      if (!mounted || !_isActive) return;
      if (!PermissionService.isAllowed(notifStatus)) {
        _notificationNudgeShown = true;
        SnackbarHelper.showTopToast(
          context,
          message: "Turn on notifications to get check-in/check-out reminders.",
          backgroundColor: kOrangeColor,
        );
      }
    }
  }

  Future<void> _showPermissionDialog(String message) async {
    if (!mounted || _permissionDialogShowing) return;

    _permissionDialogShowing = true;

    DialogHelper.show(
      context: context,
      heightImage: 100,
      imagePath: Assets.imagesRedBgTriangleExclamation,

      title: "Permissions required",
      subtitle: message,

      cancelButtonText: "Later",
      onCancelTap: () {
        _permissionDialogShowing = false;
      },
      width: 90,
      height: 50,
      buttonText: "Open Settings",
      ButtonBg: kredColor,

      onButtonTap: () {
        PermissionService.openSettings();
      },

      barrierDismissible: true,
    );

    if (mounted) {
      _permissionDialogShowing = false;
    }
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
    _notificationNudgeShown = false;
    _checkPermissions();

    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      unawaited(controller.reconcileWithServer());
      unawaited(controller.refreshGeofenceStatus());
    }

    _entranceController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    if (_authPolicyListener != null) {
      bindings.authProvider.removeListener(_authPolicyListener!);
      _authPolicyListener = null;
    }
    _controller.removeListener(_maybeShowLocationAlert);
    _ticker.dispose();
    _controller.dispose();
    _connectivitySub?.cancel();
    _permissionPollTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  String _formattedTime(DateTime now) {
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  void _openLocationSheet() async {
    // 1. Permission Gate (Check & Request Permissions)
    final permissionService = const AttendancePermissionService();
    final hasPermission = await permissionService.checkAndRequestPermissions();
    if (!hasPermission) {
      if (mounted) {
        SnackbarHelper.showTopToast(
          context,
          message:
              "Location permissions and GPS are required to view office locations.",
          backgroundColor: kredColor,
        );
      }
      return;
    }

    // 2. Offline Restore & Network Data Refresh
    if (bindings.authProvider.locations.isEmpty) {
      await bindings.authProvider.restoreCompanyAndLocationsFromCache();
    }

    await bindings.companyPolicyService.refreshFromNetwork().timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
    await _controller.loadPolicyFrom(bindings.companyPolicyService);
    try {
      await bindings.authProvider.refreshCurrentUser().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {}

    if (!mounted) return;

    // 3. UI Rendering (Get fresh locations & open bottom sheet)
    final authLocations = bindings.authProvider.locations;
    final locations = authLocations.map((l) {
      final point = GeoPoint.tryParse(l.latLon);
      return LocationModel(
        name: l.name,
        address: l.displayAddress,
        image: l.image ?? '',
        latitude: point?.lat,
        longitude: point?.lon,
      );
    }).toList();

    final result = await showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationBottomSheet(
        locations: locations,
        selected: _controller.selectedLocationName,
      ),
    );
    if (result == null || !mounted) return;

    // Local controller selection
    _controller.selectLocation(result.name, inRange: true);

    for (final loc in authLocations) {
      if (loc.name == result.name) {
        await bindings.authProvider.selectLocation(loc);
        break;
      }
    }

    // Refresh geofence status
    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      await controller.refreshGeofenceStatus();
    }
  }

  bool _isCheckInTap() {
    return _controller.effectiveStatus == AttendanceDayStatus.checkedOut;
  }

  bool _isCheckoutTap() {
    final status = _controller.effectiveStatus;
    return status == AttendanceDayStatus.checkedIn ||
        status == AttendanceDayStatus.endedBreak;
  }

  void _showResultToast(AttendanceActionResult result) {
    if (!mounted) return;

    switch (result) {
      case AttendanceActionResult.checkedIn:
        SnackbarHelper.showTopToast(
          context,
          message: AppStrings.checkedIn,
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesCircleCheckDown,
        );
        break;
      case AttendanceActionResult.checkedOut:
        SnackbarHelper.showTopToast(
          context,
          message: AppStrings.checkedOut,
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesCircleCheckUp,
        );
        break;
      case AttendanceActionResult.breakStarted:
        SnackbarHelper.showTopToast(
          context,
          message: AppStrings.breakStarted,
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesMugHotWhite,
        );
        break;
      case AttendanceActionResult.breakEnded:
        SnackbarHelper.showTopToast(
          context,
          message: AppStrings.breakEnded,
          backgroundColor: kBlack,
          textColor: kWhite,
          imagePath: Assets.imagesCircleCheckTick,
        );
        break;

      case AttendanceActionResult.nonWorkingDay:
        SnackbarHelper.showTopToast(
          context,
          message: AppStrings.nonWorkingDay,
          backgroundColor: kredColor,
        );
        break;
      case AttendanceActionResult.breakLimitReached:
        SnackbarHelper.showTopToast(
          context,
          message: "Break limit reached",
          backgroundColor: kredColor,
        );
        break;
      case AttendanceActionResult.outOfRange:
      case AttendanceActionResult.none:
        break;
    }
  }

  Future<void> _onMainTap() async {
    final result = await _controller.handleMainTap();
    _showResultToast(result);

    final syncedController = _controller as SyncedClockScreenController;
    if (syncedController.lastServerMessage != null) {
      final msg = syncedController.lastServerMessage!;
      syncedController.lastServerMessage = null;
      if (msg == AppStrings.locationPermissionRequired ||
          msg == AppStrings.turnOnLocationServices ||
          msg == AppStrings.permissionsRequired ||
          msg.contains('Unable to get your location')) {
        SnackbarHelper.showTopToast(
          context,
          message: msg,
          backgroundColor: kredColor,
        );
      }
    }
  }

  Future<void> _onBreakTap() async {
    final result = await _controller.handleBreakTap();
    _showResultToast(result);

    final syncedController = _controller as SyncedClockScreenController;
    if (syncedController.lastServerMessage != null) {
      final msg = syncedController.lastServerMessage!;
      syncedController.lastServerMessage = null;
      if (msg == AppStrings.locationPermissionRequired ||
          msg == AppStrings.turnOnLocationServices ||
          msg == AppStrings.permissionsRequired ||
          msg.contains('Unable to get your location')) {
        SnackbarHelper.showTopToast(
          context,
          message: msg,
          backgroundColor: kredColor,
        );
      }
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
      default:
        return (color: kPrimaryColor, text: "Check In", showBreakBadge: false);
    }
  }

  Widget _staggered(int index, int total, Widget child) {
    final safeTotal = total <= 1 ? 1 : total;
    final start = (index / safeTotal) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * -18),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBreakDurationInfo(SyncedClockScreenController syncedController) {
    final hasPolicy = syncedController.hasPolicyBreakDuration;
    final isOnBreak = syncedController.isOnBreak;

    // ✅ Backend policy duration
    final durationLabel = hasPolicy
        ? AttendanceFormat.duration(syncedController.policyBreakDuration)
        : "--";

    // ✅ Backend-derived break end time
    final endsAtLabel = isOnBreak
        ? (syncedController.breakEndsAtLabel ?? "--")
        : "--";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppText.p2(
          "Break duration: $durationLabel",
          color: kYellowColorLight,
          weight: FontWeight.w400,
        ),
        const SizedBox(height: 4),
        AppText.p2(
          "Break ends at: $endsAtLabel",
          color: kYellowColorLight,
          weight: FontWeight.w400,
        ),
      ],
    );
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
            final syncedController = _controller as SyncedClockScreenController;

            final List<Widget> items = [
              if (isOnBreak) ...[
                const SizedBox(height: 40),
                AppText.p1(
                  "Break started at ${_formattedTime(syncedController.breakStartedAt ?? _ticker.value)}",
                  color: kYellowColorLight,
                  weight: FontWeight.w400,
                ),
                const SizedBox(height: 4),
              ],

              ButtonAnimations.press(
                onTap: () {},
                child: Row(
                  spacing: 5,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText.p3(
                      _controller.selectedCompanyName,
                      color: isOnBreak ? kWhite : kBlack,
                      weight: FontWeight.w600,
                    ),
                  ],
                ),
              ),

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
                isActive: _isActive,
                isLoading: _controller.isProcessing,
              ),
              const SizedBox(height: 30),

              if (isOnBreak) _buildBreakDurationInfo(syncedController),
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
                            : _controller.selectedLocationName.isNotEmpty
                            ? "Not in [${_controller.selectedLocationName}] range"
                            : "Not in range",
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
                      apiClient: bindings.apiClient,
                      userEmail: bindings.userEmail,
                      onEditAttendance: () {},
                    )
                  : const SizedBox.shrink(),
              const SizedBox(height: 30),
            ];

            return ListView(
              children: [
                for (int i = 0; i < items.length; i++)
                  _staggered(i, items.length, items[i]),
              ],
            );
          },
        ),
      ),
    );
  }
}
