import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/policy.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/terms.dart';
import 'package:Obecno/features/launch/book_demo/request_demo.dart';

import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:Obecno/shared/widgets/custom_dropdown.dart';
import 'package:Obecno/shared/widgets/phone_feild.dart';
import 'package:Obecno/shared/widgets/term_text.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/validators/validators.dart';
import 'package:Obecno/shared/widgets/custom_textfield.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';

class BookDemoScreen extends StatefulWidget {
  const BookDemoScreen({super.key});

  @override
  State<BookDemoScreen> createState() => _BookDemoScreenState();
}

class _BookDemoScreenState extends State<BookDemoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  /// State
  String selectedCode = "+92";
  String? selectedIndustry;

  final List<String> countryCodes = ["+92", "+1", "+44", "+61", "+971", "+91"];

  final List<String> industries = [
    "Tech",
    "Finance",
    "Healthcare",
    "Education",
  ];

  void _submit() {
    if (_formKey.currentState!.validate()) {
      debugPrint("Name: ${nameController.text}");
      debugPrint("Email: ${emailController.text}");
      debugPrint("Phone: $selectedCode ${phoneController.text}");
      debugPrint("Industry: $selectedIndustry");
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DemoRequestScreen()),
        (route) => true,
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// BACK
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: BackButtonBg(),
            ),

            const SizedBox(height: 20),

            /// TITLE
            AppText.h4("Book a Demo"),
            const SizedBox(height: 10),

            /// SUBTITLE
            AppText.p2(
              "Fill in the details below and our team will reach out to schedule your demo.",
              color: kGreyColor,
              weight: FontWeight.w400,
            ),
            const SizedBox(height: 16),

            /// ===============================
            /// FORM
            /// ===============================
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// NAME
                      CustomTextField(
                        controller: nameController,
                        labelText: "Your Name ",
                        hasStar: true,
                        hintText: "Enter your name",
                        isExpanded: true,
                        validator: (value) =>
                            Validators.required(value, label: "Name"),
                      ),
                      const SizedBox(height: 10),

                      /// EMAIL
                      CustomTextField(
                        controller: emailController,
                        labelText: "Email ",

                        hasStar: true,
                        hintText: "Enter your email",
                        isExpanded: true,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 10),
                      PhoneField(
                        controller: phoneController,
                        selectedCode: '',
                        onCodeChanged: (String p1) {},
                      ),

                      const SizedBox(height: 16),

                      /// INDUSTRY
                      CustomDropDown(
                        labelText: "Industry or Sector",
                        items: industries,
                        onChanged: (val) {
                          setState(() => selectedIndustry = val);
                        },
                        hint: "Select ",
                        selectedValue: selectedIndustry ?? '',
                      ),

                      const SizedBox(height: 20),

                      /// TERMS
                      CustomRichText(
                        prefixText:
                            "By submitting this form, you are agreeing to our ",
                        linkText1: "Terms of Service",
                        middleText: " and ",
                        linkText2: "Privacy Policy",
                        suffixText: ".",

                        onTap1: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsScreen(),
                            ),
                          );
                        },
                        onTap2: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(),
                            ),
                          );
                        },

                        textType: AppTextType.p2, // ✅ uses 14 from system
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// ===============================
            /// SUBMIT BUTTON
            /// ===============================
            MyButton(
              mTop: 8,
              mBottom: 16,
              buttonText: 'Send request',
              onTap: () async {
                _submit();
              },
            ),
          ],
        ),
      ),
    );
  }
}
