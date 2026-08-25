import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/confirm_location_change_dialog.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class EmployeeDefaultLocationsSheet {
  EmployeeDefaultLocationsSheet._();

  static Future<void> show({
    required BuildContext context,
    required String employeeName,
    int? userId,
    String? initialDefaultId,
    Set<String>? initialSelectedIds,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeDefaultLocationsSheetBody(
        employeeName: employeeName,
        userId: userId,
        initialDefaultId: initialDefaultId,
        initialSelectedIds: initialSelectedIds,
      ),
    );
  }
}

class _EmployeeDefaultLocationsSheetBody extends StatefulWidget {
  const _EmployeeDefaultLocationsSheetBody({
    required this.employeeName,
    this.userId,
    this.initialDefaultId,
    this.initialSelectedIds,
  });

  final String employeeName;
  final int? userId;
  final String? initialDefaultId;
  final Set<String>? initialSelectedIds;

  @override
  State<_EmployeeDefaultLocationsSheetBody> createState() =>
      _EmployeeDefaultLocationsSheetBodyState();
}

class _EmployeeDefaultLocationsSheetBodyState
    extends State<_EmployeeDefaultLocationsSheetBody> {
  List<LocationFilterOption> _locations = const [];
  Set<String> _selectedIds = {};
  String _defaultId = '';
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final locationsProvider = context.read<ManagerLocationsProvider>();
      if (locationsProvider.locations.isEmpty) {
        await locationsProvider.load();
      }

      var defaultId = widget.initialDefaultId ?? '';
      var selected = Set<String>.from(widget.initialSelectedIds ?? const {});
      if (widget.userId != null) {
        final profile = await bindings.managerEmployeesService
            .loadEmployeeProfile(userId: widget.userId!);
        if (profile.success && profile.data != null) {
          defaultId = profile.data!.locationId ?? defaultId;
          if (profile.data!.locationIds.isNotEmpty) {
            selected = profile.data!.locationIds.toSet();
          } else if (defaultId.isNotEmpty) {
            selected = {defaultId};
          }
        }
      }

      final company = locationsProvider.filterOptions;
      var assigned = company
          .where((option) => selected.contains(option.id))
          .toList();
      if (assigned.isEmpty) assigned = company;
      if (defaultId.isEmpty && assigned.isNotEmpty) {
        defaultId = assigned.first.id;
      }
      if (selected.isEmpty) {
        selected = assigned.map((e) => e.id).toSet();
      }

      if (!mounted) return;
      setState(() {
        _locations = assigned;
        _selectedIds = selected;
        _defaultId = defaultId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load locations.';
      });
    }
  }

  void _setDefault(String id) {
    setState(() {
      _selectedIds.add(id);
      _defaultId = id;
    });
  }

  Future<void> _save() async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final confirmed = await ConfirmLocationChangeDialog.show(context);
    if (confirmed != true || !mounted) return;

    if (widget.userId != null) {
      setState(() => _saving = true);
      final result = await bindings.managerEmployeesService
          .updateEmployeeLocations(
            userId: widget.userId!,
            defaultLocationId: _defaultId,
            locationIds: _selectedIds.toList(),
          );
      if (!mounted) return;
      if (!result.success) {
        setState(() => _saving = false);
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to update locations.',
        );
        return;
      }

      final profile = await bindings.managerEmployeesService
          .loadEmployeeProfile(userId: widget.userId!);
      if (!mounted) return;
      setState(() => _saving = false);
      if (profile.success &&
          profile.data != null &&
          (profile.data!.locationId ?? '').trim().isNotEmpty &&
          (profile.data!.locationId ?? '').trim() != _defaultId.trim()) {
        ToastHelper.error(
          context,
          message: 'Location update did not persist. Please try again.',
        );
        return;
      }
    }

    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      ToastHelper.changesSaved(rootContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: kWhite,
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
                        AppText.h5('Default Locations'),
                        const SizedBox(height: 2),
                        AppText.p2(widget.employeeName, color: kGreyColor),
                      ],
                    ),
                  ),
                  ButtonAnimations.press(
                    onTap: () {},
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: const BoxDecoration(
                          color: kGreyContainerColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.more_horiz, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kDividerColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: AppText.p2(_error!, color: kGreyColor),
                    )
                  : _locations.isEmpty
                  ? Center(
                      child: AppText.p2(
                        'No locations assigned',
                        color: kGreyColor,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: _locations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final option = _locations[index];
                        final selected = _selectedIds.contains(option.id);
                        final isDefault = option.id == _defaultId;
                        return _LocationCard(
                          option: option,
                          selected: selected,
                          isDefault: isDefault,
                          onTap: () => _setDefault(option.id),
                          onLongPress: () => _setDefault(option.id),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: kDividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: MyButton(
                buttonText: 'Save',
                backgroundColor: kPrimaryButtonColor,
                isactive: !_saving && !_loading,
                isLoadingExternally: _saving,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.option,
    required this.selected,
    required this.isDefault,
    required this.onTap,
    required this.onLongPress,
  });

  final LocationFilterOption option;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return  GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDefault ? kPrimaryColor : kBorderColor,
            width: isDefault ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText.p2(
                          option.name,
                          color: kBlack,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: CommonImageView(
                                imagePath: Assets.imagesLocationDot,
                                height: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AppText.caption(
                                option.hasNoLocation
                                    ? 'No Location'
                                    : option.address!,
                                color: kGreyColor,
                                weight: FontWeight.w400,
                                align: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                        if (isDefault) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor2.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: AppText.caption(
                              'Default',
                              color: kPrimaryColor,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      color: selected ? kPrimaryColor : kWhite,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? kPrimaryColor : kGreyColor3,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 14, color: kWhite)
                        : null,
                  ),
                ],
              ),
            ),
            if (option.isNear)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                color: const Color(0xFFEAF4FF),
                child: Row(
                  children: [
                    CommonImageView(imagePath: Assets.GpsPin, height: 14),
                    const SizedBox(width: 8),
                    AppText.caption(
                      'Near this location',
                      color: kGreyColor,
                      weight: FontWeight.w500,
                      align: TextAlign.left,
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
