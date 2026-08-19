import 'package:flutter/material.dart';
import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';

/// Selected filter chip with clear (x).
class SelectedFilterChip extends StatelessWidget {
  const SelectedFilterChip({
    super.key,
    required this.label,
    required this.onClear,
    this.onTap,
  });

  final String label;
  final VoidCallback onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor2,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: kBlack.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText.p2(
                label,
                color: kBlack,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            const SizedBox(width: 8),
            ButtonAnimations.press(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: kBlack),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable filter chip that opens a bottom sheet.
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: kWhite,
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText.p2(
                label,
                color: kBlack,
                align: TextAlign.left,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}
