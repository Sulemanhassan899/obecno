import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/policy.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/terms.dart';
import 'package:Obecno/features/launch/book_demo/presentation/request_demo.dart';
import 'package:Obecno/features/launch/book_demo/providers/book_demo_provider.dart';
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
import 'package:Obecno/core/helpers/snackbar_helper.dart';
import 'package:go_router/go_router.dart';

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
  bool _isSubmitting = false;

  final List<String> countryCodes = ["+92", "+1", "+44", "+61", "+971", "+91"];

  final List<String> industries = [
    "Tech",
    "Finance",
    "Healthcare",
    "Education",
  ];

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // Only Name + Email are required to book a demo. Phone and Industry
    // are optional -- they're folded into the ticket's free-text
    // `content` message (see BookDemoEntity.buildContentMessage()) and
    // are never enforced by the backend, so the form must not block
    // submission on them either. validate() below only runs the
    // validators actually attached to Name/Email in this form -- Phone
    // and Industry intentionally have none.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final ok = await context.read<BookDemoProvider>().submitDemoRequest(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      phoneCode: selectedCode,
      phone: phoneController.text.trim(),
      industry: selectedIndustry ?? '',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      final message =
          context.read<BookDemoProvider>().errorMessage ??
          'Failed to submit your demo request. Please try again.';
      SnackbarHelper.showTopToast(context, message: message);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DemoRequestScreen()),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  /// Onboarding is where "Book a Demo" is always entered from, so both
  /// the tapped back arrow and the hardware/gesture back go there --
  /// there's nothing below this screen in the stack to pop to when it
  /// was reached via `context.go('/bookdemo')`.
  ///
  /// NOTE: double-check '/onboarding' is the exact route name registered
  /// in your GoRouter config -- if it's spelled differently there,
  /// `context.go` fails silently with no visible error, which looks
  /// exactly like "the back button does nothing".
  void _backToOnboarding(BuildContext context) {
    if (!context.mounted) return;
    try {
      context.go('/onboarding');
    } catch (_) {
      // If '/onboarding' isn't a registered GoRouter path (typo, renamed
      // route, etc.) context.go throws instead of silently doing
      // nothing -- fall back to a plain pop so the button still does
      // *something* visible instead of appearing dead.
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // onPopInvoked is deprecated as of newer Flutter SDKs in favor of
      // onPopInvokedWithResult. Using the deprecated callback can be a
      // no-op (silently ignored) depending on your Flutter version --
      // this was very likely why hardware/gesture back appeared dead.
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToOnboarding(context);
      },
      child: Scaffold(
        body: Padding(
          padding: AppSizes.DEFAULT,
          child: Column(
            children: [
              const SizedBox(height: 10),

              /// BACK
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: BackButtonBg(
                ),
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
                        /// NAME (required)
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

                        /// EMAIL (required)
                        CustomTextField(
                          controller: emailController,
                          labelText: "Email ",
                          hasStar: true,
                          hintText: "Enter your email",
                          isExpanded: true,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 10),

                        /// PHONE (optional -- no validator passed on
                        /// purpose). If phone still blocks submission,
                        /// the enforcement is hard-coded inside
                        /// PhoneField itself (shared/widgets/phone_feild.dart)
                        /// and needs to be made optional there too --
                        /// that file wasn't in this bundle.
                        PhoneField(
                          controller: phoneController,
                          selectedCode: selectedCode,
                          onCodeChanged: (String p1) {
                            setState(() => selectedCode = p1);
                          },
                        ),

                        const SizedBox(height: 16),

                        /// INDUSTRY (optional -- no validator passed on
                        /// purpose). If it still blocks submission, same
                        /// note as above but for
                        /// shared/widgets/custom_dropdown.dart.
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
                buttonText: _isSubmitting ? 'Sending...' : 'Send request',
                isactive: !_isSubmitting,
                onTap: () async {
                  await _submit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}