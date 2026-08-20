import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class LocationModel {
  final String name;
  final String address;
  final String image;
  final double? latitude;
  final double? longitude;

  LocationModel({
    required this.name,
    required this.address,
    required this.image,
    this.latitude,
    this.longitude,
  });
}

class LocationBottomSheet extends StatefulWidget {
  final List<LocationModel> locations;
  final String selected;

  const LocationBottomSheet({
    super.key,
    required this.locations,
    required this.selected,
  });

  @override
  State<LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<LocationBottomSheet> {
  String? selectedName;

  bool _hasPopped = false;

  @override
  void initState() {
    selectedName = widget.selected;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    AppText.h5("Select location"),
                    const Spacer(),
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.locations.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final item = widget.locations[index];
                    final isSelected = selectedName == item.name;
                    final rawAddr = item.address.trim();
                    final displayAddress =
                        (rawAddr.isEmpty ||
                            rawAddr.toLowerCase() == "location unavailable")
                        ? ((item.name.trim().isNotEmpty)
                              ? "Not in [${item.name.trim()}] range"
                              : "Not in office range")
                        : rawAddr;

                    return ButtonAnimations.press(
                      onTap: () {
                        if (_hasPopped) return;
                        _hasPopped = true;

                        setState(() {
                          selectedName = item.name;
                        });

                        Navigator.pop(context, item);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? kPrimaryColor : kBorderColor,
                            width: isSelected ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CommonImageView(
                              url: item.image,
                              height: 60,
                              width: 60,
                              radius: 8,
                              fit: BoxFit.cover,

                              /// fallback if null
                              placeHolder: Assets.imagesDummyMaps,

                              /// fallback if error (network fail etc)
                              errorImage: Assets.imagesDummyMaps,
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText.p1(
                                    item.name,
                                    weight: FontWeight.w600,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    spacing: 5,
                                    children: [
                                      CommonImageView(
                                        imagePath: Assets.imagesLocationDot,
                                        height: 12,
                                      ),
                                      AppText.caption(
                                        displayAddress,
                                        color: kGreyColor,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              height: 16,
                              width: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? kPrimaryColor
                                    : kTransperentColor,
                                border: Border.all(
                                  color: isSelected
                                      ? kPrimaryColor
                                      : kGreyColor,
                                  width: isSelected ? 4 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        height: 10,
                                        width: 10,
                                        decoration: const BoxDecoration(
                                          color: kWhite,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
