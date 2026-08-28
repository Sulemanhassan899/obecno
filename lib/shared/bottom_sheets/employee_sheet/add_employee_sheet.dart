import 'dart:async';

import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/invite_sent_dialog.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _InviteRow {
  _InviteRow({this.locationId = LocationFilterOption.allId});

  final TextEditingController emailController = TextEditingController();

  String locationId;
  final errors = <String, String?>{};

  String? error(String key) => errors[key];

  void dispose() {
    emailController.dispose();
  }

  void clearErrors() => errors.clear();
}

class AddEmployeeSheet {
  AddEmployeeSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddEmployeeSheetBody(),
    );
  }
}

class _AddEmployeeSheetBody extends StatefulWidget {
  const _AddEmployeeSheetBody();

  @override
  State<_AddEmployeeSheetBody> createState() => _AddEmployeeSheetBodyState();
}

class _AddEmployeeSheetBodyState extends State<_AddEmployeeSheetBody> {
  final _rows = <_InviteRow>[_InviteRow()];
  static const _inviteLink = 'https://www.obecno.com/EmployeeRegister...';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ManagerLocationsProvider>().load());
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _locationLabel(String id) {
    if (!AddEmployeePayload.hasLocation(id)) return 'All Location';
    return context.read<ManagerLocationsProvider>().byId(id)?.name ??
        'All Location';
  }

  Future<void> _pickLocation(_InviteRow row) async {
    final locationsProvider = context.read<ManagerLocationsProvider>();
    await locationsProvider.load();
    if (!mounted) return;
    final selected = await LocationsFilterSheet.show(
      context,
      locations: locationsProvider.filterOptions,
      selectedId: row.locationId,
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.locationId = selected;
      row.errors.remove('location_id');
      row.errors.remove('default_location_id');
    });
  }

  void _clear() {
    for (final row in _rows) {
      row.dispose();
    }
    setState(() {
      _rows
        ..clear()
        ..add(_InviteRow());
    });
  }

  bool _validate(_InviteRow row) {
    row.clearErrors();
    final email = row.emailController.text.trim();
    if (email.isEmpty) {
      row.errors['email'] = 'Email is required.';
    } else if (!AddEmployeePayload.isValidEmail(email)) {
      row.errors['email'] = 'Enter a valid email address.';
    }
    return row.errors.isEmpty;
  }

  Future<void> _sendInvites() async {
    if (_sending) return;
    debugPrint('[AddEmployee] Send Invites tapped');

    var hasFieldError = false;
    final invites = <AddEmployeePayload>[];
    for (final row in _rows) {
      if (!_validate(row)) {
        hasFieldError = true;
        continue;
      }
      invites.add(
        AddEmployeePayload.fromInvite(
          email: row.emailController.text.trim(),
          locationId: row.locationId,
        ),
      );
    }

    if (hasFieldError) {
      debugPrint('[AddEmployee] blocked by local validation');
      setState(() {});
      ToastHelper.error(
        context,
        message: 'Fill the required fields before sending invites.',
      );
      return;
    }

    if (invites.isEmpty) {
      setState(() => _rows.first.errors['email'] = 'Email is required.');
      return;
    }

    setState(() => _sending = true);
    debugPrint('[AddEmployee] calling API for ${invites.length} invite(s)');
    try {
      final result = await context.read<ManagerEmployeesProvider>().addEmployees(
        invites,
      );
      debugPrint(
        '[AddEmployee] UI result success=${result.success} '
        'code=${result.statusCode} message=${result.message} '
        'fields=${result.fieldErrors}',
      );
      if (!mounted) return;
      setState(() => _sending = false);

      if (!result.success) {
        _applyApiErrors(result);
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to send invites.',
        );
        return;
      }

      unawaited(context.read<ManagerEmployeesProvider>().refresh());
      unawaited(context.read<ManagerOverviewProvider>().refresh());

      final navigator = Navigator.of(context, rootNavigator: true);
      debugPrint('[AddEmployee] invite succeeded, showing dialog');
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          '[AddEmployee] dialog frame navigator.mounted=${navigator.mounted}',
        );
        if (!navigator.mounted) return;
        InviteSentDialog.show(navigator.context);
      });
    } catch (error, stack) {
      debugPrint('[AddEmployee] Send Invites failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() => _sending = false);
      ToastHelper.error(context, message: error.toString());
    }
  }

  void _applyApiErrors(ApiResponse<dynamic> result) {
    const keys = [
      'email',
      'location_id',
      'location_ids',
      'default_location_id',
    ];
    setState(() {
      var applied = false;
      for (final row in _rows) {
        if (row.emailController.text.trim().isEmpty) continue;
        for (final key in keys) {
          row.errors[key] = result.messageForFields([key]);
        }
        applied = true;
      }
      final target = applied ? null : _rows.first;
      if (target != null) {
        for (final key in keys) {
          target.errors[key] = result.messageForFields([key]);
        }
      }
      final hasField = keys.any(
        (key) => result.messageForFields([key]) != null,
      );
      if (!hasField) {
        (_rows.first).errors['email'] =
            result.firstFieldMessage ?? result.message;
      }
    });
  }

  Future<void> _shareLink() async {
    await Clipboard.setData(const ClipboardData(text: _inviteLink));
  }

  Widget _addViaLinkCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          CommonImageView(imagePath: Assets.linkIcon, height: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p2(
                  'Add via link',
                  color: kBlack,
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 4),
                AppText.caption(
                  _inviteLink,
                  color: kGreyColor,
                  weight: FontWeight.w400,
                  align: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ButtonAnimations.press(
            onTap: _shareLink,
            child: CommonImageView(imagePath: Assets.ShareButton, height: 40),
          ),
        ],
      ),
    );
  }

  Widget _inviteFormCard(_InviteRow row) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: row.emailController,
            hintText: '',
            labelText: 'Email',
            haveLebelText: true,
            hasStar: true,
            backgroundColor: kWhite,
            enabledBorderColor: kBorderColor,
            focusedBorderColor: kBorderColor,
            radius: 12,
            keyboardType: TextInputType.emailAddress,
            errorText: row.error('email'),
            onChanged: (_) {
              if (row.error('email') == null) return;
              setState(() => row.errors.remove('email'));
            },
          ),
          _selectField(
            label: 'Location',
            value: _locationLabel(row.locationId),
            error: row.error('location_id') ?? row.error('default_location_id'),
            onTap: () => _pickLocation(row),
          ),
        ],
      ),
    );
  }

  Widget _selectField({
    required String label,
    required String value,
    required VoidCallback onTap,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.caption(
          label,
          color: error != null ? kRed : kBlack,
          weight: FontWeight.w500,
          align: TextAlign.left,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: error != null ? kRed : kBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppText.p2(
                    value,
                    color: kBlack,
                    weight: FontWeight.w500,
                    align: TextAlign.left,
                  ),
                ),
                const Icon(Icons.unfold_more, size: 18, color: kGreyColor),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          AppText.caption(
            error,
            color: kRed,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ManagerLocationsProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText.h5(
                        'Add Employee',
                        weight: FontWeight.w600,
                        align: TextAlign.left,
                      ),
                    ),
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kDividerColor),
              Flexible(
                child: Container(
                  color: kbackground2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _addViaLinkCard(),
                        const SizedBox(height: 22),
                        AppText.p2(
                          'Add Employees',
                          color: kBlack,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 10),
                        ..._rows.asMap().entries.map((entry) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key == _rows.length - 1 ? 0 : 12,
                            ),
                            child: _inviteFormCard(entry.value),
                          );
                        }),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ButtonAnimations.press(
                            onTap: () => setState(() => _rows.add(_InviteRow())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: AppText.caption(
                                '+ Add Another',
                                color: kGreyColor,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        buttonText: 'Clear',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        isactive: !_sending,
                        onTap: () async => _clear(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: MyButton(
                        buttonText: 'Send Invites',
                        backgroundColor: kPrimaryColor,
                        isactive: !_sending,
                        isLoadingExternally: _sending,
                        onTap: _sendInvites,
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
