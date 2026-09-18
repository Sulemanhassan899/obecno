import 'dart:async';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/monitors/app_guard.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/core/services/permission_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';

import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key, required this.email});

  /// Email confirmed to exist by [LoginEmailScreen]'s checkEmail call.
  final String email;

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BackButtonBg(),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Center(child: AppText.h4("Verify your account")),
                    const SizedBox(height: 8),
                    Center(child: AppText.h6(widget.email)),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _otpController,
                      focusNode: _otpFocus,
                      labelText: "OTP",
                      hintText: "Enter 6-digit OTP",
                      haveLebelText: true,
                      radius: 14,
                      keyboardType: TextInputType.number,
                      // inputFormatters: [
                      //   FilteringTextInputFormatter.digitsOnly,
                      //   LengthLimitingTextInputFormatter(6),
                      // ],
                      // maxLength: 6,
                      errorBorderColor: _errorText == null
                          ? kBorderColor
                          : Colors.red,
                      focusedBorderColor: _errorText == null
                          ? kPrimaryColor
                          : Colors.red,
                      backgroundColor: kWhite,
                      txtColor: kBlack,
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                    ),
                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: AppText.p2(_errorText!, color: kredColor),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: MyButton(
                buttonText: _isSubmitting ? "Please wait..." : "Continue",
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap:  () async {} 
              ),
            ),
          ],
        ),
      ),
    );
  }
}
