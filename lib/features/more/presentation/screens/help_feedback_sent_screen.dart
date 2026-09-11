import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class HelpFeedbackSentScreen extends StatelessWidget {
  const HelpFeedbackSentScreen({super.key});

  void _backToMore(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToMore(context);
      },
      child: Scaffold(
        body: Padding(
          padding: AppSizes.DEFAULT,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    BackButtonBg(onTap: () => _backToMore(context)),

                    const SizedBox(height: 100),

                    CommonImageView(
                      imagePath: Assets.imagesDemoReq,
                      height: 200,
                      width: 400,
                    ),
                    AppText.h4('Request Sent'),
                    const SizedBox(height: 20),
                    AppText.p2(
                      'Thanks for reaching out!',
                      color: kGreyColor,
                      weight: FontWeight.w400,
                    ),
                    const SizedBox(height: 8),
                    AppText.p2(
                      'Our team has received your request and will contact you shortly.',
                      color: kGreyColor,
                      weight: FontWeight.w400,
                    ),
                  ],
                ),
                MyButton(
                  mTop: 8,
                  mBottom: 16,
                  buttonText: 'Close',
                  backgroundColor: kWhite,
                  fontColor: kBlack,
                  onTap: () async {
                    _backToMore(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
