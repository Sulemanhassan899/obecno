import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

enum AccountEditField { email, phone, companyId, address }

extension AccountEditFieldX on AccountEditField {
  String get label {
    switch (this) {
      case AccountEditField.email:
        return 'Email';
      case AccountEditField.phone:
        return 'Phone';
      case AccountEditField.companyId:
        return 'Company ID';
      case AccountEditField.address:
        return 'Address';
    }
  }

  String get helpText {
    switch (this) {
      case AccountEditField.email:
        return 'Changing your primary email will update your login and notification email. Verification may be required.';
      case AccountEditField.phone:
        return 'Changing your primary phone will update your login and notification phone. Verification may be required.';
      case AccountEditField.companyId:
        return 'Changing your primary company ID will update your login and notification company ID. Verification may be required.';
      case AccountEditField.address:
        return '';
    }
  }

  TextInputType get keyboardType {
    switch (this) {
      case AccountEditField.email:
        return TextInputType.emailAddress;
      case AccountEditField.phone:
        return TextInputType.phone;
      case AccountEditField.companyId:
        return TextInputType.number;
      case AccountEditField.address:
        return TextInputType.streetAddress;
    }
  }
}

class EditAccountFieldSheet {
  EditAccountFieldSheet._();

  static Future<String?> show({
    required BuildContext context,
    required String employeeName,
    required AccountEditField field,
    required String initialValue,
    Future<String?> Function(String value)? persist,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAccountFieldSheetBody(
        employeeName: employeeName,
        field: field,
        initialValue: initialValue,
        persist: persist,
      ),
    );
  }
}

class _EditAccountFieldSheetBody extends StatefulWidget {
  const _EditAccountFieldSheetBody({
    required this.employeeName,
    required this.field,
    required this.initialValue,
    this.persist,
  });

  final String employeeName;
  final AccountEditField field;
  final String initialValue;
  final Future<String?> Function(String value)? persist;

  @override
  State<_EditAccountFieldSheetBody> createState() =>
      _EditAccountFieldSheetBodyState();
}

class _EditAccountFieldSheetBodyState
    extends State<_EditAccountFieldSheetBody> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _saving) return;
    final persist = widget.persist;
    if (persist == null) {
      Navigator.pop(context, value);
      return;
    }
    setState(() => _saving = true);
    final error = await persist(value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ToastHelper.error(context, message: error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final help = widget.field.helpText;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.9,
        decoration: const BoxDecoration(
          color: kbackground2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: const BoxDecoration(
                          color: kGreyContainerColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, size: 16),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          AppText.h5('Edit', weight: FontWeight.w700),
                          const SizedBox(height: 2),
                          AppText.caption(
                            widget.employeeName,
                            color: kGreyColor,
                            weight: FontWeight.w400,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              const Divider(height: 1, color: kDividerColor),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  children: [
                    CustomTextField(
                      controller: _controller,
                      hintText: '',
                      labelText: widget.field.label,
                      haveLebelText: true,
                      hasStar: true,
                      backgroundColor: kWhite,
                      enabledBorderColor: kBorderColor,
                      focusedBorderColor: kBorderColor,
                      radius: 14,
                      keyboardType: widget.field.keyboardType,
                    ),
                    if (help.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AppText.caption(
                        help,
                        color: kGreyColor,
                        weight: FontWeight.w400,
                        align: TextAlign.left,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: kDividerColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: MyButton(
                        size: MyButtonSize.normal,
                        buttonText: 'Cancel',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        isactive: !_saving,
                        onTap: () async => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: MyButton(
                        buttonText: 'Save',
                        backgroundColor: kPrimaryButtonColor,
                        isactive: !_saving,
                        isLoadingExternally: _saving,
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
