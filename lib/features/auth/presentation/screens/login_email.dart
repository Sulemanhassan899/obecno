import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/custom_textfield.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:Obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginEmailScreen extends StatefulWidget {
  const LoginEmailScreen({super.key});

  @override
  State<LoginEmailScreen> createState() => _LoginEmailScreenState();
}

class _LoginEmailScreenState extends State<LoginEmailScreen> {
  /// ✅ PREFILLED VALUE
  final TextEditingController _emailController = TextEditingController(
    text: "",
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

    context.push('/login/password', extra: email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _backToOnboarding() {
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToOnboarding();
      },
      child: Scaffold(
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
                        child: BackButtonBg(onTap: _backToOnboarding),
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
                        hintText: "Enter Email Address",
                        radius: 14,
                        keyboardType: TextInputType.emailAddress,
                        errorBorderColor: _errorText == null
                            ? kBorderColor
                            : Colors.red,
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
                    ],
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: MyButton(
                  mBottom: 0,
                  buttonText: "Continue",
                  backgroundColor: kBlack,
                  fontColor: kWhite,
                  onTap: _onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
