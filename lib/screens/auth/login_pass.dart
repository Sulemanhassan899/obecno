// import 'package:Obecno/core/constants/app_sizes.dart';
// import 'package:Obecno/core/constants/text_styles.dart';
// import 'package:Obecno/core/state/change_notifier_provider.dart';
// import 'package:Obecno/features/auth/providers/auth_provider.dart';
// import 'package:Obecno/screens/auth/enable_permission.dart';
// import 'package:Obecno/screens/auth/forgot_password.dart';
// import 'package:Obecno/widgets/back_button.dart';
// import 'package:Obecno/widgets/custom_checkbox_widget.dart';
// import 'package:flutter/material.dart';
// import '../../core/constants/all_colors.dart';
// import '../../widgets/custom_textfield.dart';
// import '../../widgets/my_button.dart';
// import '../../widgets/text_widget.dart';

// class LoginPasswordScreen extends StatefulWidget {
//   const LoginPasswordScreen({super.key});

//   @override
//   State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
// }

// class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
//   final TextEditingController _passController = TextEditingController(
//     text: "12345678",
//   );
//   final FocusNode _passFocus = FocusNode();

//   String? _errorText;
//   bool _isObscure = true;
//   bool _rememberMe = true;

//   /// ✅ BUTTON STATE
//   bool get _isButtonActive {
//     final password = _passController.text.trim();
//     return password.isNotEmpty && password.length >= 6;
//   }

//   @override
//   void initState() {
//     super.initState();

//     /// AUTO FOCUS
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _passFocus.requestFocus();
//     });

//     /// LISTENER FOR REAL-TIME BUTTON UPDATE
//     _passController.addListener(() {
//       setState(() {});
//     });
//   }

//   bool _validate() {
//     String password = _passController.text.trim();

//     if (password.isEmpty) {
//       setState(() => _errorText = "Password is required");
//       return false;
//     }

//     if (password.length < 6) {
//       setState(() => _errorText = "Minimum 6 characters required");
//       return false;
//     }

//     setState(() => _errorText = null);
//     return true;
//   }

//   @override
//   void dispose() {
//     _passController.dispose();
//     _passFocus.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       backgroundColor: kWhite,
//       body: Padding(
//         padding: AppSizes.DEFAULT,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 10),

//             /// BACK BUTTON
//             Padding(
//               padding: const EdgeInsets.only(top: 40),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: BackButtonBg(),
//               ),
//             ),

//             const SizedBox(height: 60),

//             /// TITLE
//             Center(child: AppText.h4("Sign in to your account")),

//             const SizedBox(height: 8),

//             /// EMAIL
//             Center(child: AppText.h6("theacocunt@email.com")),

//             const SizedBox(height: 40),

//             /// PASSWORD FIELD
//             CustomTextField(
//               controller: _passController,
//               focusNode: _passFocus,
//               labelText: "Password",
//               hintText: "Enter your password",
//               haveLebelText: true,
//               radius: 14,

//               errorBorderColor: _errorText == null ? kBorderColor : Colors.red,
//               focusedBorderColor: _errorText == null
//                   ? kPrimaryColor
//                   : Colors.red,

//               backgroundColor: kWhite,
//               txtColor: kBlack,

//               obscureText: _isObscure,
//               haveSuffixIcon: true,
//               suffixWidget: IconButton(
//                 icon: Icon(
//                   _isObscure
//                       ? Icons.visibility_outlined
//                       : Icons.visibility_off_outlined,
//                   color: kBlack300,
//                   size: 20,
//                 ),
//                 onPressed: () {
//                   setState(() => _isObscure = !_isObscure);
//                 },
//               ),

//               onChanged: (_) {
//                 if (_errorText != null) {
//                   setState(() => _errorText = null);
//                 }
//               },
//             ),

//             /// ERROR
//             if (_errorText != null)
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 12, left: 4),
//                 child: AppText.p2(_errorText!, color: kredColor),
//               ),

//             const SizedBox(height: 12),

//             /// REMEMBER + FORGOT
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 CustomCheckbox(
//                   text: "Remember",
//                   text2: "me",
//                   onChanged: (val) {
//                     setState(() => _rememberMe = val);
//                   },
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     Navigator.pushAndRemoveUntil(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => const ForgotPasswordScreen(),
//                       ),
//                       (route) => true,
//                     );
//                   },
//                   child: AppText.p2("Forgot your Password?", color: kBlue),
//                 ),
//               ],
//             ),

//             const Spacer(),

//             /// ✅ BUTTON (FIXED)
//             SafeArea(
//               top: false,
//               child: MyButton(
//                 buttonText: "Continue",
//                 backgroundColor: kBlack,
//                 fontColor: kWhite,
//                 isactive: _isButtonActive,
//                 onTap: () async {
//                   // if (!_isButtonActive) return;
//                   // if (!_validate()) return;

//                   // /// simulate API / logic
//                   // await Future.delayed(const Duration(milliseconds: 500));

//                   // if (!context.mounted) return;

//                   // Navigator.pushAndRemoveUntil(
//                   //   context,
//                   //   MaterialPageRoute(
//                   //     builder: (_) => const EnablePermissionsScreen(),
//                   //   ),
//                   //   (route) => true,
//                   // );
//                   if (!_isButtonActive) return;
//                   if (!_validate()) return;
//                   final ok = await context
//                       .read<AuthProvider>()
//                       .loginWithPassword(_passController.text.trim());
//                   if (!ok || !context.mounted) return;
//                   Navigator.pushAndRemoveUntil(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => const EnablePermissionsScreen(),
//                     ),
//                     (route) => true,
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
