import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/demo/manager_location_model.dart';
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

  void dispose() => emailController.dispose();
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

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _locationLabel(String id) {
    if (id == LocationFilterOption.allId) return 'All Location';
    final match = dummyManagerLocations.where((e) => e.id == id);
    if (match.isEmpty) return 'All Location';
    return match.first.name;
  }

  Future<void> _pickLocation(_InviteRow row) async {
    final locations = LocationFilterOption.demoMulti();
    final selected = await LocationsFilterSheet.show(
      context,
      locations: locations,
      selectedId: row.locationId,
    );
    if (selected == null || !mounted) return;
    setState(() => row.locationId = selected);
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

  Future<void> _sendInvites() async {
    final hasEmail = _rows.any((r) => r.emailController.text.trim().isNotEmpty);
    if (!hasEmail) return;

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      InviteSentDialog.show(rootContext);
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
            child: CommonImageView(
              imagePath: Assets.ShareButton,
              height: 40,
            ),
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
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppText.caption(
              'Location',
              color: kBlack,
              weight: FontWeight.w500,
              align: TextAlign.left,
            ),
          ),
          const SizedBox(height: 8),
          ButtonAnimations.press(
            onTap: () => _pickLocation(row),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.p2(
                      _locationLabel(row.locationId),
                      color: kBlack,
                      weight: FontWeight.w500,
                      align: TextAlign.left,
                    ),
                  ),
                  const Icon(
                    Icons.unfold_more,
                    size: 18,
                    color: kGreyColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        onTap: () async => _clear(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: MyButton(
                        buttonText: 'Send Invites',
                        backgroundColor: kPrimaryColor,
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
