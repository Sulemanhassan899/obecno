import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/core/validators/validators.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';

import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;

  String? _currentError;
  String? _newError;
  String? _confirmError;

  bool _validate() {
    final current = _currentController.text.trim();
    final newPass = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    String? currentError;
    String? newError;
    String? confirmError;

    if (current.isEmpty) {
      currentError = 'Current password is required';
    }

    final passwordError = Validators.password(newPass);
    if (passwordError != null) {
      newError = passwordError;
    }

    final confirmPasswordError = Validators.confirmPassword(confirm, newPass);
    if (confirmPasswordError != null) {
      confirmError = confirmPasswordError;
    }

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
    });

    return currentError == null && newError == null && confirmError == null;
  }

  bool get hasMinLength => _newController.text.length >= 8;
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(_newController.text);
  bool get hasLower => RegExp(r'[a-z]').hasMatch(_newController.text);
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(_newController.text);
  bool get hasSymbol =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=]').hasMatch(_newController.text);

  Future<void> _submit() async {
    if (!_validate()) return;

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.changePassword(
      currentPassword: _currentController.text.trim(),
      newPassword: _newController.text.trim(),
      newPasswordConfirmation: _confirmController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ToastHelper.passwordChanged(
        context,
        message:
            authProvider.changePasswordMessage ??
            'Password changed successfully.',
      );
      authProvider.clearChangePasswordMessage();
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentError =
          authProvider.changePasswordMessage ?? 'Failed to change password.';
      _newError = null;
      _confirmError = null;
    });
    authProvider.clearChangePasswordMessage();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return ListenableBuilder(
      listenable: authProvider,
      builder: (context, _) =>
          _buildScaffold(context, authProvider.isChangePasswordLoading),
    );
  }

  Widget _buildScaffold(BuildContext context, bool isLoading) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSizes.defaultOf(context),
              child: MyButton(
                buttonText: isLoading ? "Saving..." : "Save New Password",
                backgroundColor: kBlack,
                fontColor: kWhite,

                onTap: () async {
                  if (_validate()) {
                    isLoading ? () {} : _submit();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      backgroundColor: kbackground1,

      body: Padding(
        padding: AppSizes.horizontalOnly(context),
        child: ListView(
          children: [
            const SizedBox(height: 20),

            /// HEADER
            BackButtonBg(title: "Change Password"),

            const SizedBox(height: 20),

            CustomTextField(
              controller: _currentController,
              labelText: "Current Password",
              haveLebelText: true,
              hintText: "Current Password",
              radius: 14,
              backgroundColor: kWhite,
              txtColor: kBlack,
              errorText: _currentError,
              errorBorderColor:
                  _currentError == null ? kBorderColor : Colors.red,
              focusedBorderColor:
                  _currentError == null ? kPrimaryColor : Colors.red,

              obscureText: _currentObscure,
              haveSuffixIcon: true,
              suffixWidget: IconButton(
                icon: Icon(
                  _currentObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kBlack300,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _currentObscure = !_currentObscure);
                },
              ),
              onChanged: (_) {
                if (_currentError != null) {
                  setState(() => _currentError = null);
                }
              },
            ),

            /// NEW PASSWORD
            CustomTextField(
              controller: _newController,
              labelText: "New Password",
              haveLebelText: true,
              hintText: "New Password",
              radius: 14,
              backgroundColor: kWhite,
              txtColor: kBlack,
              errorText: _newError,
              errorBorderColor: _newError == null ? kBorderColor : Colors.red,
              focusedBorderColor:
                  _newError == null ? kPrimaryColor : Colors.red,

              obscureText: _newObscure,
              haveSuffixIcon: true,
              suffixWidget: IconButton(
                icon: Icon(
                  _newObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kBlack300,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _newObscure = !_newObscure);
                },
              ),

              onChanged: (_) {
                setState(() {
                  if (_newError != null) _newError = null;
                });
              },
            ),

            /// CONFIRM PASSWORD
            CustomTextField(
              controller: _confirmController,
              labelText: "Confirm New Password",
              haveLebelText: true,
              radius: 14,
              hintText: "Confirm New Password",
              backgroundColor: kWhite,
              txtColor: kBlack,
              errorText: _confirmError,
              errorBorderColor:
                  _confirmError == null ? kBorderColor : Colors.red,
              focusedBorderColor:
                  _confirmError == null ? kPrimaryColor : Colors.red,

              obscureText: _confirmObscure,
              haveSuffixIcon: true,
              suffixWidget: IconButton(
                icon: Icon(
                  _confirmObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kBlack300,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _confirmObscure = !_confirmObscure);
                },
              ),
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
            ),

            const SizedBox(height: 10),

            /// PASSWORD RULES
            Row(
              children: [
                AppText.p1(
                  "Your Password must have the following:",
                  color: kBlack,
                ),
              ],
            ),

            const SizedBox(height: 10),

            _buildRule("At least 8 characters", hasMinLength),
            _buildRule("1 uppercase", hasUpper),
            _buildRule("1 lowercase", hasLower),
            _buildRule("1 number", hasNumber),
            _buildRule("1 symbol", hasSymbol),
          ],
        ),
      ),
    );
  }

  /// RULE ITEM
  Widget _buildRule(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            height: 16,
            width: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isValid ? kPrimaryColor : kGreyColor),
            ),
            child: Icon(
              Icons.check,
              size: 10,
              color: isValid ? kPrimaryColor : kGreyColor,
            ),
          ),
          const SizedBox(width: 10),
          AppText.p2(text, color: isValid ? Colors.green : kGreyColor),
        ],
      ),
    );
  }
}
