import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';

/// Full-width status strip shown when a location is deactivated.
/// Mirrors [OfflineBanner] layout with red background and white text.
class LocationDeactivatedBanner extends StatelessWidget {
  const LocationDeactivatedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kredColor,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: AppText.p2(
            'Location Deactivated',
            color: kWhite,
            weight: FontWeight.w500,
            align: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
