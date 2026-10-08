import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/monitors/app_guard.dart';
import 'package:obecno/core/services/permission_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Which Settings screen we opened (resume continues the chain).
enum _Awaiting {
  none,
  /// In-app prompt was blocked → generic app settings for that permission.
  blockedInApp,
  /// After all in-app grants → exact Location “Allow all the time” page.
  locationAlways,
}

class EnablePermissionsScreen extends StatefulWidget {
  const EnablePermissionsScreen({super.key});

  @override
  State<EnablePermissionsScreen> createState() =>
      _EnablePermissionsScreenState();
}

class _EnablePermissionsScreenState extends State<EnablePermissionsScreen>
    with WidgetsBindingObserver {
  bool _flowRunning = false;
  bool _navigatingAway = false;
  _Awaiting _awaiting = _Awaiting.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppGuard.permissionOnboardingPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppGuard.dismissOpenPromptIfAny();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_awaiting == _Awaiting.none || _navigatingAway) return;
    unawaited(_handleResume());
  }

  Future<void> _handleResume() async {
    if (_navigatingAway || !mounted) return;

    if (_awaiting == _Awaiting.locationAlways) {
      final always = await Permission.locationAlways.status;
      debugPrint('[EnablePermissionsScreen] resume always -> $always');
      if (PermissionService.isAllowed(always)) {
        _goHome();
      }
      return;
    }

    if (_awaiting == _Awaiting.blockedInApp) {
      unawaited(_runFlow());
    }
  }

  /// Must NOT await the flow — MyButton keeps its spinner until onTap's
  /// Future completes, which made Continue feel stuck for the whole chain.
  Future<void> _handleContinue() async {
    if (_flowRunning || _navigatingAway) return;
    unawaited(_runFlow());
  }

  /// Order: Notifications → Motion → Location while using → Allow all the time.
  /// No button loader during OS dialogs — prompts are the feedback.
  Future<void> _runFlow() async {
    if (_flowRunning || _navigatingAway) return;
    _flowRunning = true;
    _awaiting = _Awaiting.none;

    try {
      // Fast path: everything already granted → leave immediately.
      if (await PermissionService.areAllPermissionsAllowed()) {
        _goHome();
        return;
      }
      if (!mounted || _navigatingAway) return;

      // 1) Notifications
      if (!await _requestInApp(
        Permission.notification,
        appPermission: AppPermission.notification,
        blockedHint: 'Turn on Notifications for this app, then return here.',
      )) {
        return;
      }
      if (!mounted || _navigatingAway) return;

      // 2) Motion & Fitness
      final motion = defaultTargetPlatform == TargetPlatform.iOS
          ? Permission.sensors
          : Permission.activityRecognition;
      if (!await _requestInApp(
        motion,
        appPermission: AppPermission.motion,
        blockedHint:
            'Allow Motion & Fitness / Physical activity, then return here.',
      )) {
        return;
      }
      if (!mounted || _navigatingAway) return;

      // 3) Location — while using the app
      if (!await _requestInApp(
        Permission.locationWhenInUse,
        appPermission: null,
        blockedHint: 'Allow Location “While using the app”, then return here.',
      )) {
        return;
      }
      if (!mounted || _navigatingAway) return;

      // 4) Allow all the time — never await; completion + resume finish.
      final always = await Permission.locationAlways.status;
      if (PermissionService.isAllowed(always)) {
        _goHome();
        return;
      }

      _awaiting = _Awaiting.locationAlways;
      unawaited(_promptLocationAlways());
    } catch (e, st) {
      debugPrint('[EnablePermissionsScreen] flow error: $e\n$st');
      if (!mounted || _navigatingAway) return;
      ToastHelper.permissionRequestError(context);
    } finally {
      _flowRunning = false;
    }
  }

  Future<void> _promptLocationAlways() async {
    try {
      final result = await Permission.locationAlways.request();
      debugPrint(
        '[EnablePermissionsScreen] locationAlways request -> $result',
      );
      if (!mounted || _navigatingAway) return;
      if (PermissionService.isAllowed(result)) {
        _goHome();
        return;
      }
      final status = await Permission.locationAlways.status;
      if (PermissionService.isAllowed(status)) {
        _goHome();
      }
    } catch (e) {
      debugPrint('[EnablePermissionsScreen] locationAlways error: $e');
    }
  }

  Future<bool> _requestInApp(
    Permission permission, {
    required AppPermission? appPermission,
    required String blockedHint,
  }) async {
    var status = await permission.status;
    debugPrint('[EnablePermissionsScreen] in-app $permission -> $status');
    if (_allowed(status, appPermission)) return true;

    if (!status.isPermanentlyDenied && !status.isRestricted) {
      try {
        status = await permission.request();
      } catch (_) {
        status = PermissionStatus.denied;
      }
      debugPrint(
        '[EnablePermissionsScreen] in-app $permission after request -> $status',
      );
      if (_allowed(status, appPermission)) return true;
    }

    if (!mounted || _navigatingAway) return false;
    _awaiting = _Awaiting.blockedInApp;
    ToastHelper.show(
      context,
      message: blockedHint,
      backgroundColor: kWhite,
    );
    unawaited(PermissionService.openSettings());
    return false;
  }

  bool _allowed(PermissionStatus status, AppPermission? appPermission) {
    if (appPermission != null) {
      return PermissionService.isAllowed(status, appPermission);
    }
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  void _goHome() {
    if (!mounted || _navigatingAway) return;
    _navigatingAway = true;
    _awaiting = _Awaiting.none;
    ToastHelper.allPermissionsGranted(context);
    AppGuard.permissionOnboardingPending = false;

    final authProvider = context.read<AuthProvider>();
    final homeTarget = authProvider.homeTarget;
    final userId = authProvider.user?.id;
    context.go(
      homeTarget == AuthHomeTarget.manager ? '/manager_nav' : '/employee_nav',
    );

    try {
      final deviceProvider = context.read<DeviceProvider>();
      unawaited(
        deviceProvider.registerOnLogin().then((_) async {
          await deviceProvider.checkDeviceStatus(
            null,
            loginMessage: true,
            source: 'LOGIN',
            userId: userId,
            isFirstLogin: true,
          );
        }),
      );
    } catch (e) {
      debugPrint('[EnablePermissionsScreen] DeviceProvider unavailable: $e');
    }
  }

  Widget _permissionTile({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CommonImageView(imagePath: icon, height: 16),
              const SizedBox(width: 5),
              Flexible(child: AppText.p2(title)),
            ],
          ),
          const SizedBox(height: 8),
          AppText.p2(subtitle, align: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.defaultOf(context),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CommonImageView(
                              imagePath: Assets.imagesEnablePermission,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            AppText.h4(
                              "Enable App Permissions",
                              align: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            AppText.p2(
                              "We need a few permissions to make attendance work smoothly",
                              align: TextAlign.center,
                            ),
                            const SizedBox(height: 48),
                            _permissionTile(
                              icon: Assets.imagesLocationPin,
                              title: "Location Access",
                              subtitle:
                                  "Used for office-based check-ins and reminders",
                            ),
                            _permissionTile(
                              icon: Assets.imagesBell,
                              title: "Notifications",
                              subtitle: "Never miss a check-in or check-out",
                            ),
                            _permissionTile(
                              icon: Assets.imagesLocation,
                              title: "Motion & Fitness",
                              subtitle:
                                  "You detect movement to improve location accuracy\nOr auto-check-out after inactivity",
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: MyButton(
                buttonText: "Continue",
                radius: 30,
                backgroundColor: kBlack,
                fontColor: kWhite,
                // MyButton spins until onTap completes; we fire-and-forget
                // the permission chain so this must stay false.
                showLoadingSpinner: false,
                onTap: _handleContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
