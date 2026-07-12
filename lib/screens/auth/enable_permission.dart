import 'dart:async';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/snackbar_helper.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/screens/auth/role_selection.dart';
import 'package:Obecno/screens/bottom_nav_bars/employee_nav.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/all_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../widgets/back_button.dart';
import '../../widgets/common_image_view_widget.dart';
import '../../widgets/my_button.dart';
import '../../widgets/text_widget.dart';

class EnablePermissionsScreen extends StatefulWidget {
  const EnablePermissionsScreen({super.key});

  @override
  State<EnablePermissionsScreen> createState() =>
      _EnablePermissionsScreenState();
}

class _EnablePermissionsScreenState extends State<EnablePermissionsScreen> {
  bool _loading = false;

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
        SnackbarHelper.showTopToast(
          context,
          message: "All permissions granted",
          backgroundColor: kgreenColor,
          duration: const Duration(seconds: 2),
        );

        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      } else {
        SnackbarHelper.showTopToast(
          context,
          message: "Please allow all permissions",
          backgroundColor: kOrangeColor,
          duration: const Duration(seconds: 3),
        );

        setState(() => _loading = false); // stop loading here
      }
    } catch (e) {
      if (!mounted) return;

      SnackbarHelper.showTopToast(
        context,
        message: "Error requesting permissions",
        backgroundColor: kredColor,
        duration: const Duration(seconds: 3),
      );

      setState(() => _loading = false);
    }
  }

  /// Checks current status first; only shows the OS dialog if not already granted
  Future<bool> _ensurePermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;

    final result = await permission.request();
    return result.isGranted;
  }

  /// =========================
  /// TOAST
  /// =========================
  void _showToast(String msg) {
    SnackbarHelper.showTopToast(context, message: msg, backgroundColor: kWhite);
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
      backgroundColor: kWhite,
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
