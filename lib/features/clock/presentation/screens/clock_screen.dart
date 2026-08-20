import 'dart:async';

import 'package:Obecno/core/constants/app_strings.dart';
import 'package:Obecno/core/helpers/dialog.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/features/clock/domain/controllers/clock_controller.dart';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Obecno/core/constants/app_enums.dart'
    hide AttendanceActionResult;
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/toast_helper.dart';
import 'package:Obecno/features/clock/domain/controllers/synced_clock_screen_controller.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/main.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/clock/presentation/widgets/clock_attendence_card.dart';

import 'package:Obecno/shared/bottom_sheets/location_sheet/location_detail_sheet.dart';
import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';
import 'package:Obecno/core/monitors/app_guard.dart';
import 'package:Obecno/core/monitors/device_approval_guard.dart';
import 'package:Obecno/features/clock/services/sync_service.dart';

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
    with RouteAware, TickerProviderStateMixin, WidgetsBindingObserver {
  late ClockScreenController _controller;
  bool _clockStarted = false;
  final ClockTicker _ticker = ClockTicker();
  bool _isActive = true;
  late final AuthService authService;

  StreamSubscription<bool>? _connectivitySub;
  bool _isOffline = false;
  bool _offlineToastShown = false;
  Timer? _permissionPollTimer;
  Timer? _statusSyncTimer;
  bool _permissionDialogShowing = false;
  bool _notificationNudgeShown = false;
  SyncState? _lastHandledSyncState;
  void Function(SyncState)? _previousSyncStateHandler;

  /// How often the open Clock screen re-fetches today's attendance status
  /// so actions done on another device (web/PC) appear without a manual refresh.
  static const Duration _statusSyncInterval = Duration(seconds: 30);

  VoidCallback? _authPolicyListener;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Slow, continuous pulse driving the soft glow behind the company name --
  // purely decorative, no bearing on any attendance/device logic.
  late final AnimationController _companyGlowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authPolicyListener = () {
      if (!mounted) return;
      if (!_clockStarted) {
        _startClockIfPossible();
        return;
      }
      _controller.hydrateFromAuth(
        companyName: bindings.authProvider.companyName,
        locationName: bindings.authProvider.selectedLocationName,
      );
    };
    bindings.authProvider.addListener(_authPolicyListener!);
    _startClockIfPossible();
  }

  void _startClockIfPossible() {
    if (_clockStarted) return;
    final currentUserId = bindings.authProvider.user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint(
        '[ClockScreen] waiting for authenticated user before starting',
      );
      return;
    }

    _clockStarted = true;
    unawaited(DeviceApprovalGuard.logDeviceInfoToConsole());

    _controller = SyncedClockScreenController(
      repository: bindings.clockAttendanceRepository,
      companyPolicyService: bindings.companyPolicyService,
      syncService: bindings.clockSyncService,
      userId: currentUserId,
    );

    _controller.addListener(_maybeShowLocationAlert);
    _controller.hydrateFromAuth(
      companyName: bindings.authProvider.companyName,
      locationName: bindings.authProvider.selectedLocationName,
    );

    unawaited(_controller.loadPolicyFrom(bindings.companyPolicyService));

    _ticker.start();

    _previousSyncStateHandler = bindings.clockSyncService.onStateChanged;
    bindings.clockSyncService.onStateChanged = _onSyncStateChanged;

    _startMonitoring();
    _entranceController.forward();
    if (mounted) setState(() {});
  }

  void _onSyncStateChanged(SyncState state) {
    _previousSyncStateHandler?.call(state);
    if (!mounted || !_isActive) return;
    if (state == _lastHandledSyncState) return;

    if (state == SyncState.syncing) {
      _lastHandledSyncState = state;
      ToastHelper.syncing(context);
      return;
    }

    if (state == SyncState.success &&
        _lastHandledSyncState == SyncState.syncing) {
      _lastHandledSyncState = state;
      ToastHelper.synced(context, success: true);
      return;
    }

    if (state == SyncState.failure &&
        _lastHandledSyncState == SyncState.syncing) {
      _lastHandledSyncState = state;
      ToastHelper.synced(context, success: false);
      return;
    }

    _lastHandledSyncState = state;
  }

  void _maybeShowLocationAlert() {
    if (!mounted) return;
    final controller = _controller;
    if (controller is! SyncedClockScreenController) return;
    final message = controller.lastLocationAlertMessage;
    if (message == null) return;
    controller.lastLocationAlertMessage = null;
    if (message == AppStrings.synced) {
      // Syncing / synced toasts are driven by SyncService.onStateChanged.
      return;
    }
    ToastHelper.error(context, message: message);
  }

  void _startMonitoring() {
    ConnectivityService.start();
    unawaited(_hydrateConnectivity());
    _connectivitySub = ConnectivityService.stream.listen((online) {
      if (!mounted) return;
      _applyConnectivity(online);
    });
    _checkPermissions();
    _permissionPollTimer?.cancel();
    _permissionPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _checkPermissions();
    });

    _statusSyncTimer?.cancel();
    _statusSyncTimer = Timer.periodic(_statusSyncInterval, (_) {
      _syncAttendanceStatus();
    });
  }

  Future<void> _hydrateConnectivity() async {
    final online = await ConnectivityService.isConnected();
    if (!mounted) return;
    _applyConnectivity(online, announce: false);
  }

  void _applyConnectivity(bool online, {bool announce = true}) {
    if (!mounted) return;

    if (!online) {
      final becameOffline = !_isOffline;
      if (becameOffline) {
        _isOffline = true;
        setState(() {});
      }
      if (announce && becameOffline && !_offlineToastShown) {
        _offlineToastShown = true;
        ToastHelper.noInternet(context);
      }
      return;
    }

    final wasOffline = _isOffline;
    if (wasOffline) {
      _isOffline = false;
      _offlineToastShown = false;
      setState(() {});
    }
    // Syncing / synced toasts are driven by SyncService.onStateChanged.
  }

  /// Lightweight periodic / resume sync of today's attendance events.
  void _syncAttendanceStatus() {
    if (!_clockStarted || !mounted || !_isActive || _isOffline) return;
    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      unawaited(controller.reconcileWithServer());
    }
  }

  void notifyTabResumed() {
    if (!mounted || !_clockStarted) return;
    _isActive = true;
    _checkPermissions();
    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      if (!_isOffline) {
        unawaited(controller.reconcileWithServer(force: true));
      }
      unawaited(controller.refreshGeofenceStatus());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_clockStarted) return;
      _isActive = true;
      _ticker.start();
      if (!mounted) return;
      final controller = _controller;
      if (controller is SyncedClockScreenController) {
        if (!_isOffline) {
          unawaited(controller.reconcileWithServer(force: true));
        }
      }
      _checkPermissions();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Keep local UI quiet while backgrounded; polling resumes on resume.
      _isActive = false;
    }
  }

  Future<void> _checkPermissions() async {
    if (!_clockStarted) return;
    if (!mounted || !_isActive) return;
    if (AppGuard.permissionOnboardingPending) return;
    if (_permissionDialogShowing || AppGuard.isPrompting) return;

    final locationStatus = await PermissionService.status(
      AppPermission.location,
    );
    final motionStatus = await PermissionService.status(AppPermission.motion);
    final notificationStatus = await PermissionService.status(
      AppPermission.notification,
    );
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final online = await ConnectivityService.isConnected();

    if (!mounted || !_isActive) return;

    _applyConnectivity(online);

    final locationAllowed = PermissionService.isAllowed(locationStatus);
    final motionAllowed = PermissionService.isAllowed(motionStatus);
    final notificationAllowed = PermissionService.isAllowed(notificationStatus);

    if (!gpsEnabled) {
      if (!AppGuard.isPrompting) {
        await _showPermissionDialog(
          message: AppStrings.turnOnLocationServices,
          openSettings: true,
        );
      }
      return;
    }

    if (!locationAllowed) {
      if (!AppGuard.isPrompting) {
        await _showPermissionDialog(
          message:
              "${PermissionService.label(AppPermission.location)} permission is turned OFF",
          permission: AppPermission.location,
        );
      }
      return;
    }

    if (!motionAllowed) {
      if (!AppGuard.isPrompting) {
        await _showPermissionDialog(
          message:
              "${PermissionService.label(AppPermission.motion)} permission is turned OFF",
          permission: AppPermission.motion,
        );
      }
      return;
    }

    if (!notificationAllowed && !_notificationNudgeShown) {
      _notificationNudgeShown = true;
      ToastHelper.notificationReminder(context);
    }

    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      unawaited(controller.refreshGeofenceStatus());
    }
  }

  Future<void> _showPermissionDialog({
    required String message,
    AppPermission? permission,
    bool openSettings = false,
  }) async {
    if (!mounted || _permissionDialogShowing || AppGuard.isPrompting) return;

    _permissionDialogShowing = true;
    AppGuard.isPrompting = true;

    try {
      await DialogHelper.show(
        context: context,
        heightImage: 100,
        imagePath: Assets.imagesRedBgTriangleExclamation,
        title: "Permission Required",
        subtitle: message,
        cancelButtonText: "Later",
        onCancelTap: () {},
        width: 90,
        height: 50,
        buttonText: openSettings ? "Open Settings" : "Allow",
        ButtonBg: kPrimaryColor,
        onButtonTap: () {
          if (openSettings || permission == null) {
            PermissionService.openSettings();
          } else {
            PermissionService.request(permission);
          }
        },
        barrierDismissible: true,
      );
    } finally {
      _permissionDialogShowing = false;
      AppGuard.isPrompting = false;
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
    if (!_clockStarted) return;
    setState(() => _isActive = false);
    _ticker.stop();
  }

  @override
  void didPopNext() {
    if (!_clockStarted) return;
    setState(() => _isActive = true);
    _ticker.start();
    _notificationNudgeShown = false;
    _checkPermissions();

    final controller = _controller;
    if (controller is SyncedClockScreenController) {
      if (!_isOffline) {
        unawaited(controller.reconcileWithServer(force: true));
      }
      unawaited(controller.refreshGeofenceStatus());
    }

    _entranceController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    if (_authPolicyListener != null) {
      bindings.authProvider.removeListener(_authPolicyListener!);
      _authPolicyListener = null;
    }
    if (_clockStarted) {
      _controller.removeListener(_maybeShowLocationAlert);
      _controller.dispose();
    }
    _ticker.dispose();
    _connectivitySub?.cancel();
    _permissionPollTimer?.cancel();
    _statusSyncTimer?.cancel();
    if (identical(
      bindings.clockSyncService.onStateChanged,
      _onSyncStateChanged,
    )) {
      bindings.clockSyncService.onStateChanged = _previousSyncStateHandler;
    }
    _entranceController.dispose();
    _companyGlowController.dispose();
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
        ToastHelper.locationRequiredForOffice(context);
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
        ToastHelper.checkedIn(context);
        break;
      case AttendanceActionResult.checkedOut:
        ToastHelper.checkedOut(context);
        break;
      case AttendanceActionResult.breakStarted:
        ToastHelper.breakStarted(context);
        break;
      case AttendanceActionResult.breakEnded:
        ToastHelper.breakEnded(context);
        break;

      case AttendanceActionResult.nonWorkingDay:
        ToastHelper.nonWorkingDay(context);
        break;
      case AttendanceActionResult.breakLimitReached:
        ToastHelper.breakLimitReached(context);
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
        ToastHelper.error(context, message: msg);
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
        ToastHelper.error(context, message: msg);
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
    if (!_clockStarted) {
      return const Scaffold(backgroundColor: kbackground1, body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: kbackground1,
      body: Column(
        children: [
          if (_isOffline) ...[
            SizedBox(height: MediaQuery.paddingOf(context).top),
            _offlineBanner(),
          ],
          Expanded(
            child: Padding(
              padding: AppSizes.DEFAULT2,
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final status = _controller.effectiveStatus;
                  final config = _configFor(status);
                  final isOnBreak = _controller.isOnBreak;
                  final syncedController =
                      _controller as SyncedClockScreenController;
                  final companyLabel =
                      _controller.selectedCompanyName.isNotEmpty
                      ? _controller.selectedCompanyName
                      : bindings.authProvider.companyName;

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
                            companyLabel.isNotEmpty ? companyLabel : 'Company',
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
                              color: isOnBreak
                                  ? kGreyContainerGreyColor2
                                  : kBlack,
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
                            onTodayEventsLoaded: _controller.mergeTodayEvents,
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
          ),
        ],
      ),
    );
  }

  Widget _offlineBanner() {
    return ColoredBox(
      color: const Color(0xFFFFE6A1),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: AppText.p2(
            'No internet connection',
            color: kredColor,
            weight: FontWeight.w500,
            align: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
