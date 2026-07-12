import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/screens/auth/enable_permission.dart';
import 'package:Obecno/screens/auth/login_pass.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:flutter/material.dart';
import '../../core/constants/all_colors.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/my_button.dart';
import '../../widgets/text_widget.dart';
import 'package:Obecno/widgets/custom_checkbox_widget.dart';
import 'package:Obecno/screens/auth/forgot_password.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:Obecno/screens/bottom_nav_bars/employee_nav.dart';

class LoginEmailScreen extends StatefulWidget {
  const LoginEmailScreen({super.key});

  @override
  State<LoginEmailScreen> createState() => _LoginEmailScreenState();
}

class _LoginEmailScreenState extends State<LoginEmailScreen> {
  /// ✅ PREFILLED VALUE
  final TextEditingController _emailController = TextEditingController(
    text: "suleman@naxovatetechnologies.com",
  );
  final TextEditingController _passController = TextEditingController(
    text: "38f29b82448e",
  );
  bool _isEdited = false;
  String? _errorText;
  bool _isObscure = true;
  bool _rememberMe = true;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocus.requestFocus();
    });
  }

  bool _validate() {
    String input = _emailController.text.trim();

    /// ✅ IF NOT EDITED → SKIP VALIDATION
    if (!_isEdited) return true;

    if (input.isEmpty) {
      setState(() => _errorText = "Field is required");
      return false;
    }

    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    final phoneRegex = RegExp(r"^\d{10,13}$");
    final idRegex = RegExp(r"^[a-zA-Z0-9]{4,}$");

    if (emailRegex.hasMatch(input) ||
        phoneRegex.hasMatch(input) ||
        idRegex.hasMatch(input)) {
      setState(() => _errorText = null);
      return true;
    } else {
      setState(() => _errorText = "Enter valid Email, Phone or ID");
      return false;
    }
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
              child: BackButtonBg(),
            ),

            const SizedBox(height: 60),

            Center(child: AppText.h4("Enter account details")),

            const SizedBox(height: 40),

            CustomTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              labelText: "Email / Phone / ID",
              haveLebelText: true,
              radius: 14,
              keyboardType: TextInputType.emailAddress,
              errorBorderColor: _errorText == null ? kBorderColor : Colors.red,
              focusedBorderColor: _errorText == null
                  ? kPrimaryColor
                  : Colors.red,
              backgroundColor: kWhite,
              txtColor: kBlack,
              onChanged: (_) {
                _isEdited = true; // ✅ TRACK EDIT
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
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: AppText.p2("Forgot your Password?", color: kBlue),
                ),
              ],
            ),

            const Spacer(),

            SafeArea(
              top: false,
              child: MyButton(
           
    
                buttonText: "Continue",
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap: () async {
     
                  if (!_validate()) return;
                  final ok = await context.read<AuthProvider>().login(
                    email: _emailController.text.trim(),
                    password: _passController.text.trim(),
                    rememberMe: _rememberMe,
                  );
                  if (!ok || !context.mounted) return;

                  final permissionsAllowed = await PermissionService.areAllPermissionsAllowed();
                  if (!context.mounted) return;

                  if (permissionsAllowed) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeBottomNavBar(),
                      ),
                      (route) => false,
                    );
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EnablePermissionsScreen(),
                      ),
                      (route) => false,
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
