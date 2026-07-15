import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/presentation/screens/enable_permission.dart';
import 'package:Obecno/features/auth/presentation/screens/forgot_password.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/shared/bottom_nav_bars/employee_nav.dart';
import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:Obecno/shared/widgets/custom_checkbox_widget.dart';
import 'package:Obecno/shared/widgets/custom_textfield.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:flutter/material.dart';

class LoginPasswordScreen extends StatefulWidget {
  const LoginPasswordScreen({super.key, required this.email});

  /// Email confirmed to exist by [LoginEmailScreen]'s checkEmail call.
  final String email;

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final TextEditingController _passController = TextEditingController(
    text: "",
  );
  final FocusNode _passFocus = FocusNode();

  String? _errorText;
  bool _isObscure = true;
  bool _rememberMe = true;
  bool _isSubmitting = false;

  /// ✅ BUTTON STATE
  bool get _isButtonActive {
    final password = _passController.text.trim();
    return password.isNotEmpty && password.length >= 6;
  }

  @override
  void initState() {
    super.initState();

    /// AUTO FOCUS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passFocus.requestFocus();
    });

    /// LISTENER FOR REAL-TIME BUTTON UPDATE
    _passController.addListener(() {
      setState(() {});
    });
  }

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

  Future<void> _onContinue() async {
    if (_isSubmitting) return;
    if (!_isButtonActive) return;
    if (!_validate()) return;

    setState(() => _isSubmitting = true);

    // STEP 2: email (carried from screen 1) + password against the same
    // POST /api/auth/login endpoint, this time as a real sign-in.
    final ok = await context.read<AuthProvider>().loginWithPassword(
      _passController.text.trim(),
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isSubmitting = false;
        _errorText =
            context.read<AuthProvider>().errorMessage ?? "Invalid password";
      });
      return;
    }

    final permissionsAllowed =
        await PermissionService.areAllPermissionsAllowed();
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (permissionsAllowed) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EmployeeBottomNavBar()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EnablePermissionsScreen()),
        (route) => false,
      );
    }
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

            /// EMAIL (now the real, confirmed email from step 1)
            Center(child: AppText.h6(widget.email)),

            const SizedBox(height: 40),

            /// PASSWORD FIELD
            CustomTextField(
              controller: _passController,
              focusNode: _passFocus,
              labelText: "Password",
              hintText: "Enter your password",
              haveLebelText: true,
              radius: 14,

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
                  _isObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kBlack300,
                  size: 20,
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

            /// ERROR
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: AppText.p2(_errorText!, color: kredColor),
              ),

            const SizedBox(height: 12),

            /// REMEMBER + FORGOT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomCheckbox(
                  text: "Remember",
                  text2: "me",
                  initialValue: _rememberMe,
                  onChanged: (val) {
                    setState(() => _rememberMe = val);
                  },
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          email: widget.email, // ✅ PASS EMAIL
                        ),
                      ),
                    );
                  },
                  child: AppText.p2("Forgot your Password?", color: kBlue),
                ),
              ],
            ),

            const Spacer(),

            /// ✅ BUTTON
            SafeArea(
              top: false,
              child: MyButton(
                buttonText: "Continue",
                backgroundColor: kBlack,
                fontColor: kWhite,
                isactive: _isButtonActive,
                onTap: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
