import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/screens/auth/enable_permission.dart';
import 'package:Obecno/screens/auth/forgot_password.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/custom_checkbox_widget.dart';
import 'package:flutter/material.dart';
import '../../core/constants/all_colors.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/my_button.dart';
import '../../widgets/text_widget.dart';

class LoginPasswordScreen extends StatefulWidget {
  const LoginPasswordScreen({super.key});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final FocusNode _passFocus = FocusNode();

  String? _errorText;
  bool _isObscure = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();

    /// ✅ AUTO OPEN KEYBOARD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passFocus.requestFocus();
    });
  }

  /// ✅ PASSWORD VALIDATION
  bool _validate() {
    String password = _passController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorText = "Password is required");
      return false;
    }

    if (password.length < 6) {
      setState(() => _errorText = "Minimum 6 characters required");
      return false;
    }

    setState(() => _errorText = null);
    return true;
  }

  @override
  void dispose() {
    _passController.dispose();
    _passFocus.dispose();
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

            /// BACK BUTTON
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BackButtonBg(),
              ),
            ),

            const SizedBox(height: 60),

            /// TITLE
            Center(child: AppText.h4("Sign in to your account")),

            const SizedBox(height: 8),

            /// EMAIL DISPLAY
            Center(child: AppText.h6("“theacocunt@email.com”")),

            const SizedBox(height: 40),

            /// PASSWORD FIELD
            CustomTextField(
              controller: _passController,
              focusNode: _passFocus,
              labelText: "Password",
              haveLebelText: true,
              radius: 14,

              /// BORDER
              errorBorderColor: _errorText == null ? kBorderColor : Colors.red,
              focusedBorderColor: _errorText == null
                  ? kPrimaryColor
                  : Colors.red,

              backgroundColor: kWhite,
              txtColor: kBlack,

              obscureText: _isObscure,
              haveSuffixIcon: true,
              suffixWidget: IconButton(
                icon: Icon(
                  color: kBlack300,
                  size: 20,
                  _isObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _isObscure = !_isObscure);
                },
              ),

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
            const SizedBox(height: 12),

            /// ✅ REMEMBER ME + FORGOT PASSWORD ROW (directly under the field)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CustomCheckbox(
                  text: "Remember",
                  text2: "me",
                  onChanged: (val) {
                    setState(() => _rememberMe = val);
                  },
                ),

                GestureDetector(
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                      (route) => true,
                    );
                  },
                  child: AppText.p2("Forgot your Password?", color: kBlue),
                ),
              ],
            ),

            /// ERROR TEXT
            const Spacer(),

            /// BUTTON
            SafeArea(
              top: false,
              child: MyButton(
                buttonText: "Continue",

                backgroundColor: kBlack,
                fontColor: kWhite,

                onTap: () {
                  if (_validate()) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EnablePermissionsScreen(),
                      ),
                      (route) => true,
                    );
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
