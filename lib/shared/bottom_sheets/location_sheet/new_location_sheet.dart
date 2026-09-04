import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/location_overview_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/add_members_sheet.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> _openCreatedLocationFlow(
  BuildContext context,
  ManagerLocationModel location,
) async {
  await AddMembersSheet.show(
    context,
    location: location,
    openSetupOnAdd: false,
  );
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LocationOverviewScreen(location: location),
    ),
  );
}

class NewLocationSheet {
  NewLocationSheet._();

  static Future<void> show(BuildContext context) {
    debugPrint('[AddLocation] sheet opened');
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
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    debugPrint('[AddLocation] Create tapped name="$name"');
    if (name.isEmpty) {
      debugPrint('[AddLocation] blocked: empty name');
      ToastHelper.error(context, message: 'Enter an office / location name.');
      return;
    }

    setState(() => _saving = true);
    final result = await bindings.managerLocationsService.createLocation(
      name: name,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    debugPrint(
      '[AddLocation] create result success=${result.success} '
      'status=${result.statusCode} message=${result.message} '
      'field=${result.firstFieldMessage} '
      'id=${result.data?.id} name=${result.data?.name}',
    );

    if (!result.success || result.data == null) {
      ToastHelper.error(
        context,
        message:
            result.firstFieldMessage ??
            result.message ??
            'Failed to create location.',
      );
      return;
    }

    final location = result.data!;
    context.read<ManagerLocationsProvider>().refresh();

    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      _openCreatedLocationFlow(navigator.context, location);
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
                        size: MyButtonSize.normal,
                        buttonText: 'Clear',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        isactive: !_saving,
                        onTap: () async => _nameController.clear(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: MyButton(
                        buttonText: 'Create',
                        backgroundColor: kPrimaryButtonColor,
                        isactive: !_saving,
                        isLoadingExternally: _saving,
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
