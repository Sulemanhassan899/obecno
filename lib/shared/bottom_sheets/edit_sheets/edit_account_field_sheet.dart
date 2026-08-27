import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/main.dart';
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
        return 'Phone Number';
      case AccountEditField.companyId:
        return 'Company ID';
      case AccountEditField.address:
        return 'Address';
    }
  }

  String get helpText {
    switch (this) {
      case AccountEditField.email:
        return 'Changing the primary email will update login and notification email. Verification may be required.';
      case AccountEditField.phone:
        return 'Changing the primary phone will update contact details used for notifications.';
      case AccountEditField.companyId:
        return 'This ID is used on reports and payroll.';
      case AccountEditField.address:
        return 'Used for employee records and company correspondence.';
    }
  }

  TextInputType get keyboardType {
    switch (this) {
      case AccountEditField.email:
        return TextInputType.emailAddress;
      case AccountEditField.phone:
        return TextInputType.phone;
      case AccountEditField.companyId:
        return TextInputType.text;
      case AccountEditField.address:
        return TextInputType.streetAddress;
    }
  }

  int get maxLines => this == AccountEditField.address ? 3 : 1;

  String? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '$label is required.';
    switch (this) {
      case AccountEditField.email:
        if (!AddEmployeePayload.isValidEmail(trimmed)) {
          return 'Enter a valid email address.';
        }
        return null;
      case AccountEditField.phone:
        final digits = trimmed.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 7) return 'Enter a valid phone number.';
        return null;
      case AccountEditField.companyId:
      case AccountEditField.address:
        return null;
    }
  }

  Map<String, dynamic> payload(String value) {
    final trimmed = value.trim();
    switch (this) {
      case AccountEditField.email:
        return {'email': trimmed};
      case AccountEditField.phone:
        return {'phone': trimmed, 'phone_number': trimmed};
      case AccountEditField.companyId:
        return {
          'employee_code': trimmed,
          'staff_id': trimmed,
          'employee_id_number': trimmed,
        };
      case AccountEditField.address:
        return {
          'address': trimmed,
          'home_address': trimmed,
          'present_address': trimmed,
          'permanent_address': trimmed,
          'employee': {'address': trimmed, 'home_address': trimmed},
          'profile': {'address': trimmed, 'home_address': trimmed},
        };
    }
  }

  List<String> get errorKeys {
    switch (this) {
      case AccountEditField.email:
        return const ['email', 'new_email', 'user_email'];
      case AccountEditField.phone:
        return const ['phone', 'phone_number'];
      case AccountEditField.companyId:
        return const [
          'employee_code',
          'staff_id',
          'employee_id_number',
          'company_id',
        ];
      case AccountEditField.address:
        return const ['address', 'home_address'];
    }
  }

  String saveFailureMessage(ApiResponse<dynamic> result) {
    final field = result.messageForFields(errorKeys);
    if (field != null) return field;
    final message = result.message?.trim() ?? '';
    if (message.isNotEmpty && !_isGenericValidationMessage(message)) {
      return message;
    }
    return 'Failed to update ${label.toLowerCase()}.';
  }
}

bool _isGenericValidationMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('highlighted') ||
      lower.contains('given data was invalid') ||
      lower.contains('fix the');
}

class EditAccountFieldSheet {
  EditAccountFieldSheet._();

  static Future<String?> show({
    required BuildContext context,
    required String employeeName,
    required AccountEditField field,
    required String initialValue,
    int? userId,
    Future<String?> Function(String value)? persist,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAccountFieldSheetBody(
        employeeName: employeeName,
        field: field,
        initialValue: initialValue,
        userId: userId,
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
    this.userId,
    this.persist,
  });

  final String employeeName;
  final AccountEditField field;
  final String initialValue;
  final int? userId;
  final Future<String?> Function(String value)? persist;

  @override
  State<_EditAccountFieldSheetBody> createState() =>
      _EditAccountFieldSheetBodyState();
}

class _EditAccountFieldSheetBodyState
    extends State<_EditAccountFieldSheetBody> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

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
    if (_saving) return;
    final value = _controller.text.trim();
    final validation = widget.field.validate(value);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    if (value == widget.initialValue.trim()) {
      Navigator.pop(context, value);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await _persist(value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      setState(() => _error = error);
      ToastHelper.error(context, message: error);
      return;
    }
    Navigator.pop(context, value);
  }

  Future<String?> _persist(String value) async {
    if (widget.persist != null) return widget.persist!(value);
    final userId = widget.userId;
    if (userId == null) return 'Missing employee.';

    final result = await bindings.managerEmployeesService.updateEmployee(
      userId: userId,
      payload: widget.field.payload(value),
    );
    if (result.success) return null;
    return widget.field.saveFailureMessage(result);
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
                      onTap: _saving ? null : () => Navigator.pop(context),
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
                      maxlines: widget.field.maxLines,
                      errorText: _error,
                      enabled: !_saving,
                      onChanged: (_) {
                        if (_error == null) return;
                        setState(() => _error = null);
                      },
                    ),
                    if (help.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
