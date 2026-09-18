import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';

class UnverifiedAccountBanner extends StatelessWidget {
  const UnverifiedAccountBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kredColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: kWhite, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: AppText.p2(
              'Your account is not verified.',
              color: kWhite,
              weight: FontWeight.w600,
              align: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
