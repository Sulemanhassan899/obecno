import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/data/domain/help_feedback_entity.dart';
import 'package:obecno/features/more/presentation/screens/help_feedback_sent_screen.dart';
import 'package:obecno/features/more/providers/help_feedback_provider.dart';
import 'package:obecno/features/more/providers/profile_provider.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/phone_feild.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/validators/validators.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:obecno/core/helpers/toast_helper.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController issueController = TextEditingController();

  String selectedCode = '+92';
  bool _isSubmitting = false;
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HelpFeedbackProvider>().reset();
      _prefillFromLoggedInUser();
    });
  }

  Future<void> _prefillFromLoggedInUser() async {
    if (!mounted) return;

    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.profile == null) {
      await profileProvider.loadProfile();
      if (!mounted) return;
    }

    final auth = context.read<AuthProvider>();
    final profile = profileProvider.profile;
    final user = auth.user;

    final name = (profile?.name.trim().isNotEmpty == true)
        ? profile!.name.trim()
        : (user?.name ?? '').trim();
    final email = (profile?.email.trim().isNotEmpty == true)
        ? profile!.email.trim()
        : (user?.email ?? '').trim();
    final department = (profile?.departmentName?.trim().isNotEmpty == true)
        ? profile!.departmentName!.trim()
        : (user?.department ?? '').trim();
    final phoneParts = HelpFeedbackPhone.split(profile?.phone);

    setState(() {
      nameController.text = name;
      emailController.text = email;
      departmentController.text = department;
      selectedCode = phoneParts.code;
      phoneController.text = phoneParts.number;
      _didPrefill = true;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    if (phoneController.text.trim().isEmpty) {
      ToastHelper.show(context, message: 'Phone is required.');
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>().profile;
    final user = auth.user;

    final ok = await context.read<HelpFeedbackProvider>().submitFeedback(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      phoneCode: selectedCode,
      phone: phoneController.text.trim(),
      department: departmentController.text.trim(),
      issue: issueController.text.trim(),
      employeeId: (profile?.id.isNotEmpty == true)
          ? profile!.id
          : (user?.id ?? ''),
      company: auth.companyName,
      role: auth.homeTarget == AuthHomeTarget.manager ? 'Manager' : 'Employee',
      designation: profile?.designation ?? '',
      employeeCode: profile?.employeeCode ?? '',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      final message =
          context.read<HelpFeedbackProvider>().errorMessage ??
          'Failed to submit your request. Please try again.';
      ToastHelper.show(context, message: message);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HelpFeedbackSentScreen()),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    departmentController.dispose();
    issueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          children: [
            /// HEADER
            const SizedBox(height: 20),

            BackButtonBg(title: "Help & Feedback"),

            const SizedBox(height: 20),

            AppText.p2(
              'Fill in the details below and our team will get back to you.',
              color: kGreyColor,
              weight: FontWeight.w400,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      CustomTextField(
                        controller: nameController,
                        labelText: 'Your Name ',
                        hasStar: true,
                        hintText: 'Enter your name',
                        isExpanded: true,
                        validator: (value) =>
                            Validators.required(value, label: 'Name'),
                      ),
                      CustomTextField(
                        controller: emailController,
                        labelText: 'Email ',
                        hasStar: true,
                        hintText: 'Enter your email',
                        isExpanded: true,
                        keyboardType: TextInputType.emailAddress,
                        havePrefixIcon: true,
                        preffixWidget: CommonImageView(
                          imagePath: Assets.imagesEmail,
                          height: 12,
                        ),
                        validator: Validators.email,
                      ),
                      PhoneField(
                        key: ValueKey(_didPrefill),
                        controller: phoneController,
                        selectedCode: selectedCode,
                        onCodeChanged: (String code) {
                          setState(() => selectedCode = code);
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: departmentController,
                        labelText: 'Department',
                        hintText: 'Department',
                        isExpanded: true,
                        readOnly: true,
                      ),
                      CustomTextField(
                        controller: issueController,
                        labelText: 'Describe the issue ',
                        hasStar: true,
                        hintText: 'Tell us what happened',
                        isExpanded: true,
                        maxlines: 5,
                        minHeight: 120,
                        keyboardType: TextInputType.multiline,
                        validator: (value) =>
                            Validators.required(value, label: 'Issue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    );
  }
}
