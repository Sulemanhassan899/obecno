import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/screens/bottom_sheets/hoilday_detail_sheet.dart';
import 'package:Obecno/widgets/bottom_sheet.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText.h1("Alert Screen", weight: FontWeight.w600),
            MyButton(
              mTop: 16,
              mBottom: 16,
              buttonText: "Show Message",
              onTap: () {
                CommonBottomSheet.show(
                  context: context,
                  height: 500, // adjust if needed
                  buttonText: "", // optional (since your UI already has button)
                  onButtonTap: () {},
                  children: [HolidayBottomSheet()],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
