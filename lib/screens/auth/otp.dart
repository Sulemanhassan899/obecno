// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
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
  /// 🔐 ORIGINAL OTP (DO NOT CHANGE)
  final String _originalOtp = "123456";

  /// CURRENT USER INPUT
  String _otp = "123456";

  String? _errorText;

  /// TIMER
  int _seconds = 60;
  Timer? _timer;
  bool _canResend = false;

  final TextEditingController _otpController = TextEditingController(
    text: "123456",
  );

  @override
  void initState() {
    super.initState();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otp = _otpController.text;
    });
  }

  void _startTimer() {
    _seconds = 60;
    _canResend = false;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        setState(() => _canResend = true);
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  /// ✅ STRICT VALIDATION
  bool _validate() {
    final value = _otp.trim();

    /// ❌ EMPTY
    if (value.isEmpty) {
      setState(() => _errorText = "OTP cannot be empty");
      return false;
    }

    /// ❌ LENGTH
    if (value.length != 6) {
      setState(() => _errorText = "OTP must be 6 digits");
      return false;
    }

    /// ❌ NON-NUMERIC
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      setState(() => _errorText = "OTP must contain only digits");
      return false;
    }

    /// ❌ CHANGED / WRONG OTP
    if (value != _originalOtp) {
      setState(() => _errorText = "Invalid OTP ");
      return false;
    }

    /// ✅ SUCCESS
    setState(() => _errorText = null);
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  String get _timeText {
    String sec = _seconds.toString().padLeft(2, '0');
    return "00:$sec";
  }

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
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
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: BackButtonBg(),
              ),

              const SizedBox(height: 60),

              Center(child: AppText.h4("Verify OTP")),

              const SizedBox(height: 12),

              Center(
                child: AppText.p2(
                  "Enter code we've sent to your\ntest@example.com",
                  color: kGreyColor,
                ),
              ),

              const SizedBox(height: 30),

              /// OTP FIELD
              Pinput(
                controller: _otpController,
                length: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                keyboardType: TextInputType.number,
                forceErrorState: _errorText != null,

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
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimaryColor),
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
                    color: kredColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kredColor),
                  ),
                  margin: const EdgeInsets.only(left: 10),
                ),

                onChanged: (value) {
                  _otp = value;

                  /// 🔥 REAL-TIME VALIDATION (KEY FEATURE)
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },

                onCompleted: (pin) {
                  _otp = pin;

                  if (_validate()) {
                    ForgotPasswordSheet.show(context);
                  }
                },
              ),

              const SizedBox(height: 20),

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
                      onTap: _canResend ? _startTimer : null,
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
                          _canResend ? "Resend it" : "Resend in $_timeText",
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              /// VERIFY BUTTON
              SafeArea(
                top: false,
                child: MyButton(
                  buttonText: "Verify",
                  backgroundColor: kBlack,
                  fontColor: kWhite,
                  onTap: () async {
                    // if (!_validate()) return;

                    // await Future.delayed(const Duration(milliseconds: 400));

                    // if (!context.mounted) return;

                    // ForgotPasswordSheet.show(context);
                    if (!_validate()) return;
                    final ok = await context.read<AuthProvider>().verifyOtp(
                      _otp,
                    );
                    if (!ok || !context.mounted) return;
                    ForgotPasswordSheet.show(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
