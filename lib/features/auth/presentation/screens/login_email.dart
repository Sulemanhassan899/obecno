import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/presentation/screens/forgot_password.dart';
import 'package:Obecno/features/auth/presentation/screens/login_pass.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:Obecno/shared/widgets/custom_checkbox_widget.dart';
import 'package:Obecno/shared/widgets/custom_textfield.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:flutter/material.dart';

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

  bool _isEdited = false;
  bool _isSubmitting = false;
  String? _errorText;
  final FocusNode _emailFocus = FocusNode();

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

  Future<void> _onContinue() async {
    if (_isSubmitting) return;
    if (!_validate()) return;

    final email = _emailController.text.trim();

    setState(() => _isSubmitting = true);

    // STEP 1: email-only check against POST /api/auth/login
    final exists = await context.read<AuthProvider>().checkEmail(email);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!exists) {
      setState(() {
        _errorText =
            context.read<AuthProvider>().errorMessage ?? "Account not found";
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginPasswordScreen(email: email)),
    );
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
              bottom: 0,
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
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: TextWidget(
                  text: _errorText!,
                  size: 12,
                  color: Colors.red,
                ),
              ),

            const SizedBox(height: 12),

            const Spacer(),

            SafeArea(
              top: false,
              child: MyButton(
                buttonText: "Continue",
                backgroundColor: kBlack,
                fontColor: kWhite,
                onTap: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
