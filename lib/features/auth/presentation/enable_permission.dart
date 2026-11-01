import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/monitors/app_guard.dart';
import 'package:obecno/core/services/permission_helper.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Enable OS permissions for first login.
///
/// Strategy (fixes "must restart app for next dialogs"):
/// 1. Ask Location / Notifications / Motion in **one batch** `.request()` so
///    the plugin sequences OS dialogs — sequential awaits after location were
///    swallowed until process restart on many Android OEMs.
/// 2. Ask "Allow all the time" only after When-In-Use is granted.
/// 3. On return from Settings, re-read statuses and batch-request whatever is
///    still missing (post-frame + delay so the activity is fully resumed).
class EnablePermissionsScreen extends StatefulWidget {
  const EnablePermissionsScreen({super.key});

  @override
  State<EnablePermissionsScreen> createState() =>
      _EnablePermissionsScreenState();
}

class _EnablePermissionsScreenState extends State<EnablePermissionsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _navigatingAway = false;

  /// We sent the user to Settings — next real resume continues the chain.
  bool _waitingOnSettings = false;
  bool _sawBackground = false;

  /// Prevents overlapping resume handlers.
  bool _resumeScheduled = false;

  /// Resume arrived while a request was still in flight.
  bool _runAgainWhenIdle = false;

  /// Some OEMs skip lifecycle `resumed` after Settings — poll as backup.
  Timer? _settingsPoll;

  /// User finished the Always location UI (dialog or Settings). Status from
  /// permission_handler often lags until process restart even when granted.
  bool _alwaysPromptCompleted = false;

  Permission get _motionPermission =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? Permission.sensors
      : Permission.activityRecognition;

  /// Dialog order matches the screen tiles: Location → Notifications → Motion.
  List<Permission> get _coreBatch => [
    Permission.locationWhenInUse,
    Permission.notification,
    _motionPermission,
  ];

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
    _settingsPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_navigatingAway) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_waitingOnSettings) _sawBackground = true;
        return;
      case AppLifecycleState.resumed:
        if (!_waitingOnSettings || !_sawBackground) return;
        _sawBackground = false;
        _scheduleResumeContinue();
        return;
      case AppLifecycleState.detached:
        return;
    }
  }

  void _scheduleResumeContinue() {
    if (_resumeScheduled || _navigatingAway) return;
    _resumeScheduled = true;
    _settingsPoll?.cancel();

    // Never call permission.request() directly inside the lifecycle
    // callback — the activity is not ready and OEMs swallow the dialog
    // until a cold start.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || _navigatingAway) {
        _resumeScheduled = false;
        return;
      }
      _waitingOnSettings = false;
      _resumeScheduled = false;
      debugPrint('[EnablePermissionsScreen] resume → continue permissions');
      await _runPermissionPass(fromResume: true);
    });
  }

  Future<void> _handleContinue() async {
    if (_busy || _navigatingAway) return;
    unawaited(_runPermissionPass(fromResume: false));
  }

  Future<void> _runPermissionPass({required bool fromResume}) async {
    if (_navigatingAway) return;
    if (_busy) {
      _runAgainWhenIdle = true;
      return;
    }
    _busy = true;

    try {
      if (await _everythingAllowed()) {
        _goHome();
        return;
      }

      // ---- Core batch: Location → Notifications → Motion (one native call)
      final toRequest = <Permission>[];
      for (final p in _coreBatch) {
        final status = await p.status;
        debugPrint('[EnablePermissionsScreen] core $p -> $status');
        if (_isAllowed(p, status)) continue;
        // Permanently denied cannot show an in-app dialog — Settings only.
        if (status.isPermanentlyDenied || status.isRestricted) continue;
        toRequest.add(p);
      }

      if (toRequest.isNotEmpty) {
        debugPrint(
          '[EnablePermissionsScreen] batch request → $toRequest '
          '(fromResume=$fromResume)',
        );
        final results = await toRequest.request();
        results.forEach((p, s) {
          debugPrint('[EnablePermissionsScreen] batch $p -> $s');
        });
      }

      if (!mounted || _navigatingAway) return;

      // If Location was granted but Notifications / Motion never appeared
      // (OEM swallowed follow-up dialogs), force another batch for whatever
      // is still requestable — this is the restart workaround, in-session.
      await _requestRemainingCore(label: 'post-location');

      if (!mounted || _navigatingAway) return;

      // ---- Background location ONLY after core dialogs are done.
      // Requesting Always earlier opens a system page that aborts / hides
      // Notifications & Motion until a cold start.
      if (await _coreAllowed()) {
        await _promptLocationAlwaysIfNeeded();
      }

      if (!mounted || _navigatingAway) return;

      // Leave onboarding as soon as core is done and Always was handled.
      // Do not trap on stale locationAlways status (common until cold start).
      if (await _shouldGoHome()) {
        _goHome();
        return;
      }

      // Still missing core permissions that need Settings.
      if (!await _coreAllowed()) {
        final needsSettings = await _needsSettings();
        if (needsSettings) {
          await _openSettingsAndWait(
            'Turn on Location, Notifications, and Motion for this app, '
            'then return here.',
          );
          return;
        }
        await _requestRemainingCore(label: 'final');
        if (await _shouldGoHome()) {
          _goHome();
        }
        return;
      }

      // Core ok but Always still missing after prompt — open location Settings.
      // Mark Always UI complete so the next resume navigates even if status lags.
      if (!_alwaysPromptCompleted || !await _isAlwaysAllowedSettled()) {
        _alwaysPromptCompleted = true;
        await _openSettingsAndWait(
          'Set Location to “Allow all the time”, then return here.',
        );
      }
    } catch (e, st) {
      debugPrint('[EnablePermissionsScreen] flow error: $e\n$st');
      if (!mounted || _navigatingAway) return;
      ToastHelper.permissionRequestError(context);
    } finally {
      _busy = false;
      if (_runAgainWhenIdle && mounted && !_navigatingAway) {
        _runAgainWhenIdle = false;
        unawaited(_runPermissionPass(fromResume: true));
      }
    }
  }

  Future<bool> _coreAllowed() async {
    for (final p in _coreBatch) {
      final status = await p.status;
      if (!_isAllowed(p, status)) return false;
    }
    return true;
  }

  Future<void> _promptLocationAlwaysIfNeeded() async {
    if (await _isAlwaysAllowedSettled()) {
      _alwaysPromptCompleted = true;
      return;
    }

    final always = await Permission.locationAlways.status;
    debugPrint('[EnablePermissionsScreen] locationAlways -> $always');
    if (always.isPermanentlyDenied || always.isRestricted) {
      _alwaysPromptCompleted = true;
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _navigatingAway) return;

    _waitingOnSettings = true;
    _sawBackground = false;
    final alwaysResult = await Permission.locationAlways.request();
    _alwaysPromptCompleted = true;
    debugPrint(
      '[EnablePermissionsScreen] locationAlways request -> $alwaysResult',
    );
    if (SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _waitingOnSettings = false;
    }
  }

  /// True when we should leave Enable Permissions for the dashboard.
  Future<bool> _shouldGoHome() async {
    if (!await _coreAllowed()) return false;
    if (await _isAlwaysAllowedSettled()) return true;
    // permission_handler often still reports Always as denied right after
    // the user granted it. If we already showed the Always UI, enter the app
    // — AppGuard will re-check on the home screens if it is truly missing.
    if (_alwaysPromptCompleted) {
      debugPrint(
        '[EnablePermissionsScreen] core ok + Always UI done '
        '(status may lag) → go home',
      );
      return true;
    }
    return false;
  }

  Future<bool> _isAlwaysAllowedSettled() async {
    for (var i = 0; i < 6; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted || _navigatingAway) return false;

      final always = await Permission.locationAlways.status;
      if (_isAllowed(Permission.locationAlways, always)) return true;

      final location = await Permission.location.status;
      if (_isAllowed(Permission.location, location)) return true;

      try {
        final geo = await Geolocator.checkPermission();
        if (geo == LocationPermission.always) return true;
      } catch (e) {
        debugPrint('[EnablePermissionsScreen] Geolocator check failed: $e');
      }

      debugPrint(
        '[EnablePermissionsScreen] Always settle poll=$i '
        'always=$always location=$location',
      );
    }
    return false;
  }

  Future<bool> _everythingAllowed() async {
    if (await PermissionService.areAllPermissionsAllowed()) return true;
    return _shouldGoHome();
  }

  /// Re-request any core permission that is still denied but can show a dialog.
  Future<void> _requestRemainingCore({required String label}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _navigatingAway) return;

    final retry = <Permission>[];
    for (final p in _coreBatch) {
      final status = await p.status;
      if (_isAllowed(p, status)) continue;
      if (status.isPermanentlyDenied || status.isRestricted) continue;
      retry.add(p);
    }
    if (retry.isEmpty) return;

    debugPrint('[EnablePermissionsScreen] $label retry → $retry');
    final results = await retry.request();
    results.forEach((p, s) {
      debugPrint('[EnablePermissionsScreen] $label $p -> $s');
    });
  }

  Future<bool> _needsSettings() async {
    for (final p in [
      ..._coreBatch,
      Permission.locationAlways,
    ]) {
      final status = await p.status;
      if (_isAllowed(p, status)) continue;
      if (status.isPermanentlyDenied || status.isRestricted) return true;
    }
    // When-In-Use still missing after dialogs → Settings (Android won't
    // re-prompt When-In-Use in the same session once denied).
    final whenInUse = await Permission.locationWhenInUse.status;
    if (!_isAllowed(Permission.locationWhenInUse, whenInUse)) return true;
    return false;
  }

  Future<void> _openSettingsAndWait(String hint) async {
    if (!mounted || _navigatingAway) return;
    _waitingOnSettings = true;
    _sawBackground = false;
    ToastHelper.show(context, message: hint, backgroundColor: kWhite);
    _startSettingsPoll();
    await PermissionService.openSettings();
  }

  void _startSettingsPoll() {
    _settingsPoll?.cancel();
    var ticks = 0;
    _settingsPoll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      ticks++;
      if (!mounted || _navigatingAway || !_waitingOnSettings) {
        timer.cancel();
        return;
      }
      // Cap at ~45s so we don't poll forever in background.
      if (ticks > 45) {
        timer.cancel();
        return;
      }
      // Only continue once the app is back and something changed / core can
      // be requested again.
      if (SchedulerBinding.instance.lifecycleState !=
          AppLifecycleState.resumed) {
        return;
      }
      debugPrint(
        '[EnablePermissionsScreen] settings poll tick=$ticks → continue',
      );
      timer.cancel();
      _sawBackground = false;
      _scheduleResumeContinue();
    });
  }

  bool _isAllowed(Permission permission, PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return true;
    }
    if (permission == _motionPermission &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        status.isRestricted) {
      return true;
    }
    return false;
  }

  void _goHome() {
    if (!mounted || _navigatingAway) return;
    _navigatingAway = true;
    _waitingOnSettings = false;
    ToastHelper.allPermissionsGranted(context);
    AppGuard.permissionOnboardingPending = false;
    unawaited(TokenService().markPermissionsSetupCompleted());

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
