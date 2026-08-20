import 'dart:async';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/toast_helper.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/core/monitors/app_guard.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class EnablePermissionsScreen extends StatefulWidget {
  const EnablePermissionsScreen({super.key});

  @override
  State<EnablePermissionsScreen> createState() =>
      _EnablePermissionsScreenState();
}

class _EnablePermissionsScreenState extends State<EnablePermissionsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Own the permission requests on this screen. Login can flip
    // isAuthenticated a moment before navigating here, which used to let
    // AppGuard overlay "Permission Required" on first install.
    AppGuard.permissionOnboardingPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppGuard.dismissOpenPromptIfAny();
    });
  }

  Future<void> _handleContinue() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final location = await _ensurePermission(Permission.locationWhenInUse);
      final notification = await _ensurePermission(Permission.notification);
      final motion = await _ensurePermission(Permission.activityRecognition);

      if (!mounted) return;

      if (location && notification && motion) {
        /// ✅ 1. SHOW TOAST
        ToastHelper.allPermissionsGranted(context);

        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

        // Clear onboarding flag before leaving so AppGuard/device UI may run
        // after we land on the role-based home screen (Scenario 1).
        AppGuard.permissionOnboardingPending = false;

        final authProvider = context.read<AuthProvider>();
        final homeTarget = authProvider.homeTarget;
        final userId = authProvider.user?.id;
        context.go(
          homeTarget == AuthHomeTarget.manager
              ? '/manager_nav'
              : '/employee_nav',
        );

        // Device toast/dialog AFTER permission screen (Scenario 1).
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
      } else {
        ToastHelper.pleaseAllowPermissions(context);

        setState(() => _loading = false); // stop loading here
      }
    } catch (e) {
      if (!mounted) return;

      ToastHelper.permissionRequestError(context);

      setState(() => _loading = false);
    }
  }

  Future<bool> _ensurePermission(Permission permission) async {
    final status = await permission.status;
    debugPrint('[EnablePermissionsScreen] $permission current status: $status');
    if (status.isGranted) return true;

    final result = await permission.request();
    debugPrint('[EnablePermissionsScreen] $permission request result: $result');
    return result.isGranted;
  }

  /// =========================
  /// TOAST
  /// =========================
  void _showToast(String msg) {
    ToastHelper.show(context, message: msg, backgroundColor: kWhite);
  }

  /// =========================
  /// PERMISSION TILE
  /// =========================
  Widget _permissionTile({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Row(
          spacing: 5,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CommonImageView(imagePath: icon, height: 16),

            AppText.p2(title),
          ],
        ),
        const SizedBox(height: 8),
        AppText.p2(subtitle),

        const SizedBox(height: 26),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kbackground1,
      bottomNavigationBar: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MyButton(
              buttonText: _loading ? "Please wait..." : "Continue",
              radius: 30,
              backgroundColor: kBlack,
              fontColor: kWhite,
              onTap: _loading ? () async {} : _handleContinue,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 10),

            /// BACK BUTTON
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BackButtonBg(),
              ),
            ),

            const SizedBox(height: 20),

            CommonImageView(
              imagePath: Assets.imagesEnablePermission,
              height: 200,
            ),
            const SizedBox(height: 16),
            Center(child: AppText.h4("Enable App Permissions")),

            const SizedBox(height: 10),

            Center(
              child: AppText.p2(
                "We need a few permissions to make attendance work smoothly",
              ),
            ),

            const SizedBox(height: 48),
            _permissionTile(
              icon: Assets.imagesLocationPin,
              title: "Location Access",
              subtitle: "Used for office-based check-ins and reminders",
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
    );
  }
}
