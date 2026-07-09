// ignore_for_file: non_constant_identifier_names

import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';

class OfficeLocation extends StatefulWidget {
  const OfficeLocation({super.key});

  @override
  State<OfficeLocation> createState() => _OfficeLocationState();
}

class _OfficeLocationState extends State<OfficeLocation> {
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
            BackButtonBg(title: "Offices & Locations"),

            const SizedBox(height: 20),

            _officeCard(
              title: "Head Office",
              address: "100 Stour St, Birmingham B3 1DG, UK",
              image: Assets.imagesLocation1, // your asset
              isDefault: true,
            ),

            const SizedBox(height: 16),

            _officeCard(
              title: "North Office",
              address: "Bailey St, Stafford ST17 4BG, United Kingdom",
              image: Assets.imagesLocation1, // your asset
            ),

            const SizedBox(height: 16),

            _officeCard(
              title: "South Office",
              address: "14 - 20 Elizabeth St, London SW1W 9RB, United Kingdom",
              image: Assets.imagesLocation1, // your asset
            ),
            const SizedBox(height: 16),

            _officeCard(
              title: "North Office",
              address: "Bailey St, Stafford ST17 4BG, United Kingdom",
              image: Assets.imagesLocation1, // your asset
            ),

            const SizedBox(height: 16),

            _officeCard(
              title: "South Office",
              address: "14 - 20 Elizabeth St, London SW1W 9RB, United Kingdom",
              image: Assets.imagesLocation1, // your asset
            ),
            const SizedBox(height: 16),

            _officeCard(
              title: "North Office",
              address: "Bailey St, Stafford ST17 4BG, United Kingdom",
              image: Assets.imagesLocation1, // your asset
            ),

            const SizedBox(height: 16),

            _officeCard(
              title: "South Office",
              address: "14 - 20 Elizabeth St, London SW1W 9RB, United Kingdom",
              image: Assets.imagesLocation1, // your asset
            ),
          ],
        ),
      ),
    );
  }

  Widget _officeCard({
    required String title,
    required String address,
    required String image,
    bool isDefault = false,
  }) {
    return ButtonAnimations.press(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// IMAGE
            Stack(
              children: [
                CommonImageView(
                  imagePath: image,
                  height: 160,
                  width: double.infinity,
                  topLeftRadius: 16,
                  topRightRadius: 16,
                ),

                if (isDefault)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AppText.small("Default", color: kPrimaryColor),
                    ),
                  ),
              ],
            ),

            /// TEXT
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.h6(title, weight: FontWeight.w600),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CommonImageView(
                        imagePath: Assets.imagesLocationDot2,
                        height: 12,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AppText.small(address, align: TextAlign.left),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
