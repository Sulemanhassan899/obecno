// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';

class AccountSetting extends StatefulWidget {
  const AccountSetting({super.key});

  @override
  State<AccountSetting> createState() => _AccountSettingState();
}

class _AccountSettingState extends State<AccountSetting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppSizes.HORIZONTAL,
        child: ListView(
          children: [
            const SizedBox(height: 20),

            /// HEADER
            BackButtonBg(title: "Account Information"),

            const SizedBox(height: 40),

            /// INFO BOX
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kbackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CommonImageView(imagePath: Assets.imagesInfo, height: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText.p2(
                      "Managed by your company administrator.",
                      color: kSubText,
                      align: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            /// EMAIL TILE
            _tile(
              title: "Email",
              status: "Primary",
              email: "theaddress@email.com",
            ),

            const SizedBox(height: 20),

            /// GROUP CARD
            _groupCard([
              _settingTile("Phone Number", "(555) 123-4567"),
              _divider(),
              _settingTile("Company ID", "1234567890"),
              _divider(),
              _settingTile("Address", "Al Wasl Road, Dubai"),
            ]),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// ================= TILE =================
  Widget _tile({
    required String title,
    required String status,
    required String email,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: AppText.caption(title, align: TextAlign.left),

        /// RIGHT SIDE CONTENT
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AppText.caption(status, color: kPurple),
            ),
            const SizedBox(width: 8),
            AppText.caption(email),
          ],
        ),
      ),
    );
  }

  /// ================= GROUP CARD =================
  Widget _groupCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  /// ================= SETTING TILE =================
  Widget _settingTile(String title, String subtitle) {
    return ListTile(
      title: AppText.caption(title, align: TextAlign.left),
      trailing: AppText.caption(subtitle),
    );
  }

  /// ================= DIVIDER =================
  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(height: 1, color: kDividerColor),
    );
  }
}
