import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class CompanyModel {
  final String name;
  final String address;
  final String image;

  CompanyModel({
    required this.name,
    required this.address,
    required this.image,
  });
}

class CompanyBottomSheet extends StatefulWidget {
  final List<CompanyModel> companys;
  final String selected;

  const CompanyBottomSheet({
    super.key,
    required this.companys,
    required this.selected,
  });

  @override
  State<CompanyBottomSheet> createState() => _CompanyBottomSheetState();
}

class _CompanyBottomSheetState extends State<CompanyBottomSheet> {
  String? selectedName;

  @override
  void initState() {
    selectedName = widget.selected;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                AppText.h5("Select company"),
                const Spacer(),
                ButtonAnimations.press(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// LIST
          ListView.builder(
            shrinkWrap: true,
            itemCount: widget.companys.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final item = widget.companys[index];
              final isSelected = selectedName == item.name;

              return ButtonAnimations.press(
                onTap: () {
                  setState(() {
                    selectedName = item.name;
                  });

                  Future.delayed(const Duration(milliseconds: 1500), () {
                    Navigator.pop(context, item);
                  });
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
                      /// IMAGE
                      item.image.isNotEmpty
                          ? CommonImageView(
                              imagePath: item.image,
                              height: 60,
                              width: 60,
                              radius: 8,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 60,
                              width: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            ),

                      const SizedBox(width: 12),

                      /// TEXT
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText.p1(item.name, weight: FontWeight.w600),
                            const SizedBox(height: 4),
                            Row(
                              spacing: 5,
                              children: [
                                CommonImageView(
                                  imagePath: Assets.imagesLocationDot,
                                  height: 12,
                                ),
                                AppText.caption(
                                  item.address,
                                  color: kGreyColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      /// RADIO
                      Container(
                        height: 16,
                        width: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? kPrimaryColor : kTransperentColor,
                          border: Border.all(
                            color: isSelected ? kPrimaryColor : kGreyColor,
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

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
