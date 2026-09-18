import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/join/services/join_device_auto_approve.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

class YouveJoinedScreen extends StatelessWidget {
  const YouveJoinedScreen({
    super.key,
    this.companyName = 'Acme Corporation',
  });

  final String companyName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.HORIZONTAL,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: BackCircleButton(
                  onTap: () => context.go('/employee_nav'),
                ),
              ),
              const Spacer(flex: 2),
              CommonImageView(
                imagePath: Assets.imagesObecnoLogoMain,
                height: 88,
                width: 88,
              ),
              const SizedBox(height: 28),
              AppText.h3("You've Joined", weight: FontWeight.w700),
              const SizedBox(height: 6),
              AppText.h4(
                companyName.isEmpty ? 'Acme Corporation' : companyName,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: 10),
              AppText.p2(
                'Your manager will confirm your account soon.',
                color: kGreyColor,
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _FeatureIcon(
                    imagePath: Assets.imagesJoinAttendance,
                    label: 'Attendance',
                  ),
                  _FeatureIcon(
                    imagePath: Assets.imagesJoinBreaks,
                    label: 'Breaks',
                  ),
                  _FeatureIcon(
                    imagePath: Assets.imagesJoinLeaves,
                    label: 'Leaves',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AppText.p2(
                'You can still check in, check out and use the app as normal',
                color: kGreyColor,
              ),
              const Spacer(flex: 3),
              MyButton(
                buttonText: 'Continue',
                backgroundColor: kPrimaryButtonColor,
                onTap: () async {
                  JoinDeviceAutoApprove.sync(
                    auth: context.read<AuthProvider>(),
                    join: context.read<JoinInviteProvider>(),
                    devices: context.read<DeviceProvider>(),
                  );
                  if (context.mounted) context.go('/employee_nav');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.imagePath, required this.label});

  final String imagePath;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommonImageView(imagePath: imagePath, height: 64, width: 64),
        const SizedBox(height: 10),
        AppText.caption(label, color: kBlack, weight: FontWeight.w500),
      ],
    );
  }
}
