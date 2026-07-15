

import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/shared/bottom_sheets/forgot_password_sheet.dart';

import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:Obecno/shared/widgets/custom_textfield.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _isEdited = false;
  final FocusNode _emailFocus = FocusNode();

  String? _errorText;

  @override
  void initState() {
    super.initState();

    /// ✅ PREFILL EMAIL FROM LOGIN
    _emailController = TextEditingController(text: widget.email);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocus.requestFocus();
    });
  }

  bool _validate() {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorText = "Email is required");
      return false;
    }

    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorText = "Enter valid email");
      return false;
    }

    setState(() => _errorText = null);
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kWhite,
      body: Padding(
        padding: AppSizes.DEFAULT,
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

            Center(child: AppText.h4("Forgot Password")),

            const SizedBox(height: 40),

            CustomTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              labelText: "Email",
              hintText: "Enter your email",
              haveLebelText: true,
              radius: 14,
              errorBorderColor: _errorText == null ? kBorderColor : Colors.red,
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
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: TextWidget(
                  text: _errorText!,
                  size: 12,
                  color: Colors.red,
                ),
              ),

            const Spacer(),

            SafeArea(
              top: false,
              child: MyButton(
                mTop: 8,
                mBottom: 16,
                buttonText: "Reset Password",
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap: () async {
                  if (!_validate()) return;

                  final email = _emailController.text.trim();

                  final ok = await context.read<AuthProvider>().forgotPassword(
                    email,
                  );

                  if (!ok || !context.mounted) return;

                  /// ✅ PASS EMAIL TO SHEET
                  ForgotPasswordSheet.show(context, email);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
