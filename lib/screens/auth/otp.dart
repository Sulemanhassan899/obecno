// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/screens/bottom_sheets/forgot_password_sheet.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:Obecno/widgets/text_widget.dart';
import 'package:pinput/pinput.dart';
import '../../core/constants/all_colors.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  /// ✅ STORE OTP HERE (FIX)
  String _otp = "";

  String? _errorText;

  /// TIMER
  int _seconds = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _seconds = 60;
    _canResend = false;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _seconds--;
        });
      }
    });
  }

  /// VALIDATION (FIXED)
  bool _validate() {
    if (_otp.length < 6) {
      setState(() => _errorText = "Enter complete OTP");
      return false;
    }

    if (_otp != "123456") {
      setState(() => _errorText = "Invalid OTP");
      return false;
    }

    setState(() => _errorText = null);
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeText {
    String sec = _seconds.toString().padLeft(2, '0');
    return "00:$sec";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            /// BACK
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: BackButtonBg(),
            ),

            const SizedBox(height: 60),

            /// TITLE
            Center(child: AppText.h4("Verify OTP")),

            const SizedBox(height: 12),

            /// SUBTITLE
            Center(
              child: AppText.p2(
                "Enter code we've sent to your\n[Email]",
                color: kGreyColor,
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Pinput(
                    forceErrorState: _errorText != null,
                    length: 6,
                    defaultPinTheme: PinTheme(
                      width: 48,
                      height: 52,
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderColor),
                      ),
                      margin: const EdgeInsets.only(left: 10),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 48,
                      height: 52,
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimaryColor),
                      ),
                      margin: const EdgeInsets.only(left: 10),
                    ),
                    submittedPinTheme: PinTheme(
                      width: 48,
                      height: 52,
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderColor),
                      ),
                      margin: const EdgeInsets.only(left: 10),
                    ),

                    errorPinTheme: PinTheme(
                      width: 48,
                      height: 52,
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kredColor,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kredColor),
                      ),
                      margin: const EdgeInsets.only(left: 10),
                    ),

                    /// ✅ CAPTURE VALUE
                    onChanged: (value) {
                      _otp = value;

                      if (_errorText != null) {
                        setState(() {
                          _errorText = null;
                        });
                      }
                    },

                    onCompleted: (pin) {
                      _otp = pin;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// ERROR
            if (_errorText != null)
              Center(
                child: TextWidget(
                  text: _errorText!,
                  size: 12,
                  color: Colors.red,
                ),
              ),

            const SizedBox(height: 10),

            /// RESEND
            Center(
              child: Column(
                children: [
                  AppText.p2("Didn't get the code?"),
                  const SizedBox(height: 16),

                  ButtonAnimations.press(
                    onTap: _canResend
                        ? () {
                            _startTimer();
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite,
                        border: Border.all(
                          color: _canResend ? kBlack : kBorderColor,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AppText.p5(
                        _canResend ? "Resend it" : "Resend in - $_timeText sec",
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            /// BUTTON
            SafeArea(
              top: false,
              child: MyButton(
                buttonText: "Verify",
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap: () {
                  if (_validate()) {
                    ForgotPasswordSheet.show(context); // ✅ CALL HERE
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
