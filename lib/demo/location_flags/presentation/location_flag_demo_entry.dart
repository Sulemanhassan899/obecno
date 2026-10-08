import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/demo/location_flags/presentation/location_flag_demo_screen.dart';

class LocationFlagDemoButton extends StatelessWidget {
  const LocationFlagDemoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF222222),
      borderRadius: BorderRadius.circular(28),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const LocationFlagDemoScreen(),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText.p4(
                'Demo Attendance',
                color: kWhite,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drop-in overlay. Host screens opt in by wrapping their child.
class LocationFlagDemoEntry extends StatelessWidget {
  const LocationFlagDemoEntry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 24,
          child: const SafeArea(child: LocationFlagDemoButton()),
        ),
      ],
    );
  }
}
