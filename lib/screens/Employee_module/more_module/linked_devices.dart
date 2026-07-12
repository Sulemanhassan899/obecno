// ignore_for_file: non_constant_identifier_names

import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';

class LinkedDevices extends StatefulWidget {
  const LinkedDevices({super.key});

  @override
  State<LinkedDevices> createState() => _LinkedDevicesState();
}

class _LinkedDevicesState extends State<LinkedDevices> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: Padding(
        padding: AppSizes.HORIZONTAL,
        child: ListView(
          children: [
            const SizedBox(height: 20),

            /// HEADER
            BackButtonBg(title: "Linked Devices"),

            const SizedBox(height: 20),

            /// INFO
            AppText.p1(
              "Attendance actions are allowed only from the devices listed below.",
              align: TextAlign.left,
              color: kGreyColor,
            ),

            const SizedBox(height: 20),

            _deviceCard(
              DeviceIcon: Assets.imagesApple,
              name: "iPhone 16pro max",
              subtitle: "Last used: Today at 9:12 AM",
              status: "Active",
              isCurrent: true,
            ),

            const SizedBox(height: 12),

            _deviceCard(
              DeviceIcon: Assets.imagesAndroid,
              name: "iPhone 16pro max",
              subtitle: "Requested: Jan 12, 2026",
              status: "Pending",
              showDelete: true,
            ),

            const SizedBox(height: 12),

            _deviceCard(
              DeviceIcon: Assets.imagesAndroid,
              name: "iPhone 13pro max",
              subtitle: "Last used: Oct 10, 2025",
              status: "Blocked",
            ),

            const SizedBox(height: 12),

            _deviceCard(
              DeviceIcon: Assets.imagesDesktop,
              name: "Macbook 2016",
              subtitle: "Last used: Oct 10, 2025",
              status: "Blocked",
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard({
    required String name,
    required String subtitle,
    required String status,
    required String DeviceIcon,
    bool isCurrent = false,
    bool showDelete = false,
  }) {
    Color statusColor;
    Color bgColor;

    switch (status) {
      case "Active":
        statusColor = kPrimaryColor;
        bgColor = kPrimaryColor.withOpacity(0.2);
        break;
      case "Pending":
        statusColor = kYellowColorLight;
        bgColor = kYellowColor.withOpacity(0.2);
        break;
      case "Blocked":
        statusColor = kredColor;
        bgColor = kredColorLight..withOpacity(0.1);
        break;
      default:
        statusColor = kGreyColor;
        bgColor = kGreyColor.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP ROW
          Row(
            children: [
              CommonImageView(imagePath: DeviceIcon, height: 20),
              const SizedBox(width: 10),

              Expanded(
                child: AppText.h6(
                  name,
                  align: TextAlign.left,
                  weight: FontWeight.w500,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText.small(status, color: statusColor),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// SUBTITLE
          AppText.p2(subtitle, align: TextAlign.left, color: kGreyColor),

          if (isCurrent) ...[
            const SizedBox(height: 6),
            Row(
              spacing: 5,
              children: [
                Icon(Icons.circle, size: 8, color: kBlue2),
                AppText.caption(
                  "Current Device",
                  color: kBlue2,
                  align: TextAlign.left,
                ),
              ],
            ),
          ],

          if (showDelete) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                MyButton(
                  width: 140,
                  height: 40,
                  buttonText: "Delete Request",
                  onTap: () async{},
                  fontSize: 12,
                  backgroundColor: kWhite,
                  fontColor: Colors.red,
                  outlineColor: Colors.red,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
