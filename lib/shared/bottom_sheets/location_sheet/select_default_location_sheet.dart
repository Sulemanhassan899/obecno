import 'package:flutter/material.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Single-select location picker shown after approving a via-link join.
class SelectDefaultLocationSheet {
  SelectDefaultLocationSheet._();

  static Future<LocationFilterOption?> show(
    BuildContext context, {
    String? selectedId,
  }) {
    return showModalBottomSheet<LocationFilterOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectDefaultLocationBody(selectedId: selectedId),
    );
  }
}

class _SelectDefaultLocationBody extends StatefulWidget {
  const _SelectDefaultLocationBody({this.selectedId});

  final String? selectedId;

  @override
  State<_SelectDefaultLocationBody> createState() =>
      _SelectDefaultLocationBodyState();
}

class _SelectDefaultLocationBodyState
    extends State<_SelectDefaultLocationBody> {
  String? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ManagerLocationsProvider>().load();
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<ManagerLocationsProvider>().filterOptions;

    return ConstrainedBox(
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
                        'Select the default office',
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
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : locations.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: AppText.p2(
                              'No locations available',
                              color: kGreyColor,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            itemCount: locations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final option = locations[index];
                              final selected = option.id == _selectedId;
                              return _LocationCard(
                                option: option,
                                selected: selected,
                                onTap: () =>
                                    setState(() => _selectedId = option.id),
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
                  isactive: _selectedId != null && !_loading,
                  onTap: () async {
                    final id = _selectedId;
                    if (id == null) return;
                    LocationFilterOption? match;
                    for (final option in locations) {
                      if (option.id == id) {
                        match = option;
                        break;
                      }
                    }
                    if (match == null) return;
                    Navigator.pop(context, match);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LocationFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kPrimaryColor : kBorderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CommonImageView(
                imagePath: Assets.imagesDummyMaps,
                height: 48,
                width: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
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
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kPrimaryColor : kGreyColor3,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
