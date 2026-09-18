import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/invite_sent_dialog.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/select_default_location_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:obecno/widgets/phone_feild.dart';
import 'package:share_plus/share_plus.dart';

enum _InviteMode { email, phone }

class _InviteRow {
  _InviteRow();

  _InviteMode mode = _InviteMode.email;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String dialCode = '+92';
  String? locationId;
  final errors = <String, String?>{};

  String? error(String key) => errors[key];

  void dispose() {
    emailController.dispose();
    phoneController.dispose();
  }

  void clearErrors() => errors.clear();

  String get contact {
    if (mode == _InviteMode.email) return emailController.text.trim();
    final phone = phoneController.text.replaceAll(RegExp(r'\s+'), '').trim();
    if (phone.isEmpty) return '';
    return '$dialCode$phone';
  }
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
  bool _sending = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ManagerLocationsProvider>().load());
      unawaited(context.read<JoinInviteProvider>().ensureLoaded());
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String get _companyName {
    final name = context.read<AuthProvider>().companyName.trim();
    return name.isEmpty ? 'TheDemo' : name;
  }

  String _locationLabel(String? id) {
    if (id == null || id.isEmpty || !AddEmployeePayload.hasLocation(id)) {
      return 'Select Location';
    }
    return context.read<ManagerLocationsProvider>().byId(id)?.name ??
        'Select Location';
  }

  Future<void> _pickLocation(_InviteRow row) async {
    final locationsProvider = context.read<ManagerLocationsProvider>();
    await locationsProvider.load();
    if (!mounted) return;
    final selected = await SelectDefaultLocationSheet.show(
      context,
      selectedId: row.locationId,
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.locationId = selected.id;
      row.errors.remove('location');
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

  void _removeRowAt(int index) {
    if (_rows.length <= 1 || index < 0 || index >= _rows.length) return;
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  bool _validate(_InviteRow row) {
    row.clearErrors();
    final contact = row.contact;
    if (row.mode == _InviteMode.email) {
      if (contact.isEmpty) {
        row.errors['contact'] = 'Email is required.';
      } else if (!AddEmployeePayload.isValidEmail(contact)) {
        row.errors['contact'] = 'Enter a valid email address.';
      }
    } else {
      final digits = row.phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        row.errors['contact'] = 'Phone is required.';
      } else if (digits.length < 9) {
        row.errors['contact'] = 'Enter a valid phone number.';
      }
    }
    if (row.locationId == null ||
        !AddEmployeePayload.hasLocation(row.locationId)) {
      row.errors['location'] = 'Location is required.';
    }
    return row.errors.isEmpty;
  }

  Future<void> _shareLink() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final join = context.read<JoinInviteProvider>();
      final companyName = _companyName;
      final record = await join.prepareLinkShare(companyName: companyName);
      final message = JoinShareLinks.shareMessage(
        email: record.contact,
        password: record.password,
        companyName: companyName,
      );
      debugPrint(
        '[AddEmployee] link share email=${record.contact} '
        'password=${record.password}',
      );
      await Share.share(message, subject: 'Join $companyName on Obecno');
    } catch (e) {
      if (!mounted) return;
      ToastHelper.error(context, message: 'Unable to open share sheet.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sendInvites() async {
    if (_sending) return;

    var hasFieldError = false;
    for (final row in _rows) {
      if (!_validate(row)) hasFieldError = true;
    }
    if (hasFieldError) {
      setState(() {});
      ToastHelper.error(
        context,
        message: 'Fill the required fields before sending invites.',
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final join = context.read<JoinInviteProvider>();
      final companyName = _companyName;
      final locations = context.read<ManagerLocationsProvider>();
      final rows = _rows
          .map((row) {
            final locationId = row.locationId!;
            // Always store a valid login email. Phone invites get a temp email.
            final loginEmail = row.mode == _InviteMode.email
                ? row.contact
                : JoinShareLinks.generateTempEmail();
            return (
              contact: loginEmail,
              channel: JoinInviteChannel.email,
              locationId: locationId,
              locationName: locations.byId(locationId)?.name ?? 'Location',
            );
          })
          .toList(growable: false);

      final created = await join.sendManualInvites(
        rows: rows,
        companyName: companyName,
      );
      for (final invite in created) {
        debugPrint(
          '[AddEmployee] invite email=${invite.contact} '
          'password=${invite.password}',
        );
      }
      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navigator.mounted) return;
        InviteSentDialog.show(navigator.context);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ToastHelper.error(context, message: e.toString());
    }
  }

  Widget _shareButton() {
    return ButtonAnimations.press(
      onTap: _sharing ? null : _shareLink,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CommonImageView(
              imagePath: Assets.imagesShareIconSheet,
              height: 16,
            ),
            const SizedBox(width: 10),
            AppText.caption(
              'Share',
              color: kBlack,
              weight: FontWeight.w600,
            ),
          ],
        ),
      ),
    );
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
                  '${JoinShareLinks.displayInviteLink}...',
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
          _shareButton(),
        ],
      ),
    );
  }

  Widget _modeToggle(_InviteRow row) {
    Widget chip(String label, _InviteMode mode) {
      final selected = row.mode == mode;
      return Expanded(
        child: ButtonAnimations.press(
          onTap: () {
            setState(() {
              row.mode = mode;
              row.errors.remove('contact');
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kPrimaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: AppText.p2(
              label,
              color: selected ? kWhite : kGreyColor,
              weight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          chip('Email', _InviteMode.email),
          chip('Phone', _InviteMode.phone),
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
          _modeToggle(row),
          const SizedBox(height: 14),
          if (row.mode == _InviteMode.email)
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
              bottom: 0,
              reserveHelperSpace: false,
              keyboardType: TextInputType.emailAddress,
              errorText: row.error('contact'),
              onChanged: (_) {
                if (row.error('contact') == null) return;
                setState(() => row.errors.remove('contact'));
              },
            )
          else ...[
            PhoneField(
              controller: row.phoneController,
              selectedCode: row.dialCode,
              onCodeChanged: (code) {
                setState(() {
                  row.dialCode = code;
                  row.errors.remove('contact');
                });
              },
            ),
            if (row.error('contact') != null) ...[
              const SizedBox(height: 6),
              AppText.caption(
                row.error('contact')!,
                color: kRed,
                weight: FontWeight.w400,
                align: TextAlign.left,
              ),
            ],
          ],
          const SizedBox(height: 16),
          _selectField(
            label: 'Location',
            value: _locationLabel(row.locationId),
            error: row.error('location'),
            onTap: () => _pickLocation(row),
          ),
        ],
      ),
    );
  }

  Widget _removeBetweenButton(int removeIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,

        children: [
          ButtonAnimations.press(
            onTap: () => _removeRowAt(removeIndex),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kredColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline, size: 16, color: kredColor),
                  const SizedBox(width: 4),
                  AppText.caption(
                    'Remove',
                    color: kredColor,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
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
    final isPlaceholder = value == 'Select Location';
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
                    color: isPlaceholder ? kGreyColor : kBlack,
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

  List<Widget> _inviteRows() {
    final widgets = <Widget>[];
    for (var i = 0; i < _rows.length; i++) {
      widgets.add(_inviteFormCard(_rows[i]));
      // Remove sits between cards (removes the card below the button).
      if (i < _rows.length - 1) {
        widgets.add(_removeBetweenButton(i + 1));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ManagerLocationsProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: AppSheetSize.constraintsOf(context),
        child: Container(
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
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                        ..._inviteRows(),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ButtonAnimations.press(
                            onTap: () =>
                                setState(() => _rows.add(_InviteRow())),
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
      ),
    );
  }
}
