import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class LocationFilterOption {
  const LocationFilterOption({
    required this.id,
    required this.name,
    this.address,
    this.isNear = false,
  });

  final String id;
  final String name;
  final String? address;
  final bool isNear;

  bool get hasNoLocation => address == null || address!.trim().isEmpty;

  static const allId = 'all';

  static const all = LocationFilterOption(id: allId, name: 'All Locations');

  /// Demo multi-location list. Prefer [ManagerLocationsProvider.filterOptions].
  static List<LocationFilterOption> demoMulti({String? nearestId}) {
    final items = [
      const LocationFilterOption(
        id: 'head',
        name: 'Head Office',
        address: 'Bailey St, Stafford ST17 4BG, United Kingdom',
      ),
      const LocationFilterOption(
        id: 'south',
        name: 'South Office',
        address: 'Bailey St, Stafford ST17 4BG, United Kingdom',
      ),
      const LocationFilterOption(
        id: 'north',
        name: 'North Office',
        address: 'Bailey St, Stafford ST17 4BG, United Kingdom',
      ),
      const LocationFilterOption(
        id: 'distribution',
        name: 'Distribution Center',
        address: 'Bailey St, Stafford ST17 4BG, United Kingdom',
      ),
      const LocationFilterOption(id: 'service', name: 'Service Works'),
    ];

    final nearId = nearestId ?? 'north';
    return items
        .map(
          (e) => LocationFilterOption(
            id: e.id,
            name: e.name,
            address: e.address,
            isNear: e.id == nearId,
          ),
        )
        .toList();
  }

  /// Demo single-location case → empty / create-location sheet.
  static List<LocationFilterOption> demoSingle() => const [
    LocationFilterOption(
      id: 'head',
      name: 'Head Office',
      address: 'Bailey St, Stafford ST17 4BG, United Kingdom',
    ),
  ];
}

class LocationsFilterSheet {
  LocationsFilterSheet._();

  /// Shows multi-location sheet when [locations] has 2+, otherwise single empty sheet.
  static Future<String?> show(
    BuildContext context, {
    required List<LocationFilterOption> locations,
    String selectedId = LocationFilterOption.allId,
    VoidCallback? onCreateLocation,
  }) {
    final isSingleOrEmpty = locations.length <= 1;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        if (isSingleOrEmpty) {
          return _SingleLocationSheetBody(onCreateLocation: onCreateLocation);
        }
        return _MultiLocationsSheetBody(
          locations: locations,
          initialSelectedId: selectedId,
          onCreateLocation: onCreateLocation,
        );
      },
    );
  }
}

/// Empty / single-location bottom sheet.
class _SingleLocationSheetBody extends StatelessWidget {
  const _SingleLocationSheetBody({this.onCreateLocation});

  final VoidCallback? onCreateLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      'Locations',
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
            Container(
              width: double.infinity,
              color: kWhiteF8,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 40,
                    color: kGreyColor.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  AppText.p2(
                    "You're currently using one location",
                    color: kGreyColor,
                    weight: FontWeight.w500,
                  ),
                  const SizedBox(height: 20),
                  MyButton(
                    size: MyButtonSize.normal,
                    width: 200,
                    backgroundColor: kWhite,
                    outlineColor: kBlack200,
                    fontColor: kBlack,
                    buttonText: 'Create a Location',
                    onTap: () async {
                      Navigator.pop(context);
                      onCreateLocation?.call();
                    },
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

class _MultiLocationsSheetBody extends StatefulWidget {
  const _MultiLocationsSheetBody({
    required this.locations,
    required this.initialSelectedId,
    this.onCreateLocation,
  });

  final List<LocationFilterOption> locations;
  final String initialSelectedId;
  final VoidCallback? onCreateLocation;

  @override
  State<_MultiLocationsSheetBody> createState() =>
      _MultiLocationsSheetBodyState();
}

class _MultiLocationsSheetBodyState extends State<_MultiLocationsSheetBody> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    final items = [LocationFilterOption.all, ...widget.locations];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      'Locations',
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
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = items[index];
                  final selected = option.id == _selectedId;
                  return _LocationOptionTile(
                    option: option,
                    selected: selected,
                    onTap: () => setState(() => _selectedId = option.id),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: kDividerColor),
            if (widget.onCreateLocation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: MyButton(
                  size: MyButtonSize.normal,
                  backgroundColor: kWhite,
                  outlineColor: kBlack200,
                  fontColor: kBlack,
                  buttonText: 'Create a Location',
                  onTap: () async {
                    Navigator.pop(context);
                    widget.onCreateLocation?.call();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: MyButton(
                      size: MyButtonSize.normal,
                      backgroundColor: kWhite,
                      outlineColor: kBorderColor,
                      fontColor: kBlack,
                      buttonText: 'Reset',
                      onTap: () async {
                        setState(
                          () => _selectedId = LocationFilterOption.allId,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: MyButton(
                      backgroundColor: kPrimaryButtonColor,
                      buttonText: 'Save',
                      onTap: () async {
                        Navigator.pop(context, _selectedId);
                      },
                    ),
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

class _LocationOptionTile extends StatelessWidget {
  const _LocationOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LocationFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  bool get _isAll => option.id == LocationFilterOption.allId;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kPrimaryColor : kBorderColor,
            width: selected ? 1.5 : 1,
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
                        AppText.p1(
                          option.name,
                          color: kBlack,
                          weight: FontWeight.w500,
                          align: TextAlign.left,
                        ),
                        if (!_isAll) ...[
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _LocationRadio(selected: selected),
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
                    Icon(
                      Icons.near_me,
                      size: 16,
                      color: kGreyColor.withOpacity(0.9),
                    ),
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

class _LocationRadio extends StatelessWidget {
  const _LocationRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
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
                width: 10,
                height: 10,
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
