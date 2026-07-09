import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/screens/auth/login_pass.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:flutter/material.dart';
import '../../core/constants/all_colors.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/my_button.dart';
import '../../widgets/text_widget.dart';

class LoginEmailScreen extends StatefulWidget {
  const LoginEmailScreen({super.key});

  @override
  State<LoginEmailScreen> createState() => _LoginEmailScreenState();
}

class _LoginEmailScreenState extends State<LoginEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  String? _errorText;

  @override
  void initState() {
    super.initState();

    /// ✅ AUTO OPEN KEYBOARD
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

            /// BACK BUTTON
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: BackButtonBg(),
            ),

            const SizedBox(height: 60),

            /// TITLE
            Center(child: AppText.h4("Enter account details")),

            const SizedBox(height: 40),

            /// EMAIL FIELD
            CustomTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              labelText: "Email",
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

            /// ✅ THIS IS THE KEY
            const Spacer(),

            /// BUTTON (NATURAL POSITION)
            SafeArea(
              top: false,
              child: MyButton(
                mTop: 8,
                mBottom: 16,
                buttonText: "Continue",
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap: () {
                  if (_validate()) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPasswordScreen(),
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
