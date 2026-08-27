import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/edit_account_field_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class AccountInformationSheet {
  AccountInformationSheet._();

  static Future<void> show({
    required BuildContext context,
    required String employeeName,
    int? userId,
    String email = '',
    String phone = '',
    String companyId = '',
    String address = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountInformationSheetBody(
        employeeName: employeeName,
        userId: userId,
        email: email,
        phone: phone,
        companyId: companyId,
        address: address,
      ),
    );
  }
}

class _AccountInformationSheetBody extends StatefulWidget {
  const _AccountInformationSheetBody({
    required this.employeeName,
    this.userId,
    required this.email,
    required this.phone,
    required this.companyId,
    required this.address,
  });

  final String employeeName;
  final int? userId;
  final String email;
  final String phone;
  final String companyId;
  final String address;

  @override
  State<_AccountInformationSheetBody> createState() =>
      _AccountInformationSheetBodyState();
}

class _AccountInformationSheetBodyState
    extends State<_AccountInformationSheetBody> {
  late String _email;
  late String _phone;
  late String _companyId;
  late String _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    _phone = widget.phone;
    _companyId = widget.companyId;
    _address = widget.address;
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    final userId = widget.userId;
    if (userId == null) return;
    if (showSpinner) setState(() => _loading = true);
    final result = await bindings.managerEmployeesService.loadEmployeeProfile(
      userId: userId,
    );
    if (!mounted) return;
    if (showSpinner) setState(() => _loading = false);
    if (!result.success || result.data == null) return;
    final profile = result.data!;
    setState(() {
      _email = profile.email ?? _email;
      _phone = profile.phone ?? _phone;
      final companyId = profile.employeeCode?.trim();
      final address = profile.address?.trim();
      if (companyId != null && companyId.isNotEmpty) _companyId = companyId;
      if (address != null && address.isNotEmpty) _address = address;
      _loading = false;
    });
  }

  Future<void> _edit(AccountEditField field, String current) async {
    final userId = widget.userId;
    if (userId == null) {
      ToastHelper.error(context, message: 'Missing employee.');
      return;
    }

    final updated = await EditAccountFieldSheet.show(
      context: context,
      employeeName: widget.employeeName,
      field: field,
      initialValue: current,
      userId: userId,
      persist: (value) async {
        final result = await bindings.managerEmployeesService.updateEmployee(
          userId: userId,
          payload: field.payload(value),
        );
        if (result.success) return null;
        return field.saveFailureMessage(result);
      },
    );
    if (updated == null || !mounted) return;

    setState(() => _applyField(field, updated));
    await _load(showSpinner: false);
    if (!mounted) return;
    ToastHelper.changesSaved(context);
  }

  void _applyField(AccountEditField field, String value) {
    switch (field) {
      case AccountEditField.email:
        _email = value;
      case AccountEditField.phone:
        _phone = value;
      case AccountEditField.companyId:
        _companyId = value;
      case AccountEditField.address:
        _address = value;
    }
  }

  Widget _editPen(VoidCallback onTap) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CommonImageView(imagePath: Assets.imagesPen, height: 16),
      ),
    );
  }

  /// Matches AccountSetting email tile + design: bordered card with Primary badge.
  Widget _emailCard() {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText.caption('Email', align: TextAlign.left),
            const SizedBox(width: 6),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppText.caption(
                    'Primary',
                    color: kBlue,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                AppText.caption(
                  _email,
                  align: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(width: 6),
                _editPen(() => _edit(AccountEditField.email, _email)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kbackgroundBlueContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CommonImageView(imagePath: Assets.imagesInfo, height: 20),
          const SizedBox(width: 10),
          Expanded(
            child: AppText.caption(
              'Managed by your company administrator.',
              align: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Divider(height: 1, color: kDividerColor),
    );
  }

  Widget _settingTile({
    required String title,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AppText.caption(title, align: TextAlign.left),
          ),

          Row(
            children: [
              AppText.caption(
                value,
                align: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(width: 8),
              _editPen(onEdit),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        AppText.h5(
                          'Account Information',
                          weight: FontWeight.w700,
                        ),
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _emailCard(),
                        const SizedBox(height: 12),
                        _infoBanner(),
                        const SizedBox(height: 18),
                        _groupCard(
                          children: [
                            _settingTile(
                              title: 'Phone Number',
                              value: _phone,
                              onEdit: () =>
                                  _edit(AccountEditField.phone, _phone),
                            ),
                            _divider(),
                            _settingTile(
                              title: 'Company ID',
                              value: _companyId,
                              onEdit: () =>
                                  _edit(AccountEditField.companyId, _companyId),
                            ),
                            _divider(),
                            _settingTile(
                              title: 'Address',
                              value: _address,
                              onEdit: () =>
                                  _edit(AccountEditField.address, _address),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
