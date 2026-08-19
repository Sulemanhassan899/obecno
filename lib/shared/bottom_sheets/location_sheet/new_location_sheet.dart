import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/demo/manager_location_model.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/add_members_sheet.dart';
import 'package:Obecno/widgets/custom_textfield.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class NewLocationSheet {
  NewLocationSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewLocationSheetBody(),
    );
  }
}

class _NewLocationSheetBody extends StatefulWidget {
  const _NewLocationSheetBody();

  @override
  State<_NewLocationSheetBody> createState() => _NewLocationSheetBodyState();
}

class _NewLocationSheetBodyState extends State<_NewLocationSheetBody> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);

    final location = ManagerLocationModel(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: 'Address pending setup',
      present: 0,
      total: 0,
      lateCheckIns: 0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      AddMembersSheet.show(
        rootContext,
        location: location,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText.h5(
                        'New Location',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: CustomTextField(
                  controller: _nameController,
                  hintText: '',
                  labelText: 'Office / Location Name',
                  haveLebelText: true,
                  hasStar: true,
                  backgroundColor: kWhite,
                  enabledBorderColor: kBorderColor,
                  focusedBorderColor: kBorderColor,
                  radius: 14,
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
                        buttonText: 'Clear',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        onTap: () async => _nameController.clear(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: MyButton(
                        buttonText: 'Create',
                        backgroundColor: kPrimaryButtonColor,
                        onTap: _onCreate,
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
