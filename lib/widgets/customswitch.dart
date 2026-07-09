// lib/widgets/custom_theme_switch.dart
import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import '../core/state/change_notifier_provider.dart';
import '../theme/theme_provider.dart';
import 'text_widget.dart';

class CustomThemeSwitch extends StatelessWidget {
  final String lightModeText;
  final String darkModeText;
  final Color activeColor;
  final Color inactiveColor;
  final Color trackColorLight;
  final Color trackColorDark;
  final double width;
  final double height;

  const CustomThemeSwitch({
    super.key,
    this.lightModeText = "Light Mode",
    this.darkModeText = "Dark Mode",
    this.activeColor = kPrimaryColor,
    this.inactiveColor = Colors.grey,
    this.trackColorLight = kGreyColor2,
    this.trackColorDark = kGreyColor,
    this.width = 180,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    // Watch ThemeProvider — rebuilds automatically on theme change
    final themeProvider = context.watch<ThemeProvider>();
    final isLightMode = themeProvider.themeMode == ThemeMode.light;

    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().toggleTheme(),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isLightMode
              ? trackColorLight
              : trackColorDark.withOpacity(0.6),
        ),
        child: Stack(
          children: [
            // Dark Mode Text
            AnimatedOpacity(
              opacity: isLightMode ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: TextWidget(
                    text: darkModeText,
                    paddingLeft: 20,
                    weight: FontWeight.w600,
                    color: isLightMode ? Colors.black87 : kWhite,
                    size: 14,
                  ),
                ),
              ),
            ),

            // Light Mode Text
            AnimatedOpacity(
              opacity: isLightMode ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: TextWidget(
                    text: lightModeText,
                    paddingRight: 20,
                    weight: FontWeight.w600,
                    color: isLightMode ? Colors.black87 : kWhite,
                    size: 14,
                  ),
                ),
              ),
            ),

            // The Moving Switch Knob
            AnimatedAlign(
              alignment: isLightMode
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                width: height - 12,
                height: height - 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLightMode ? activeColor : inactiveColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isLightMode ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
