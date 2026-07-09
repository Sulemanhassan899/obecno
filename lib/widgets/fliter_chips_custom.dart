import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import 'common_image_view_widget.dart';
import 'text_widget.dart';

class FliterChipCutom extends StatefulWidget {
  final String img;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const FliterChipCutom({
    super.key,
    required this.img,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<FliterChipCutom> createState() => _FliterChipCutomState();
}

class _FliterChipCutomState extends State<FliterChipCutom> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        margin: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: widget.isSelected ? kPrimaryColor : kBorderColor,
          ),
        ),
        child: Row(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextWidget(
              text: widget.text,
              size: 16,
              fontFamily: AppFonts.Poppins,
            ),
          ],
        ),
      ),
    );
  }
}
