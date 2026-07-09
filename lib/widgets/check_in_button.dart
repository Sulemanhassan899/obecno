

import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/animations/heart_beat_animation.dart';
import 'package:Obecno/core/animations/ripple_animation%20.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class CheckInButton extends StatelessWidget {
  const CheckInButton({
    super.key,
    required this.color,
    required this.text,
    this.onTap,
    this.enabled = true,
    this.showBreakBadge = false,
    this.breakBadgeText = "Break",
    this.breakBadgeColor,
    this.onBreakTap,
    this.size = 250,
    this.isOnBreak = false,
    this.isActive = true,
    this.isLoading = false, // ✅ new
  });

  final Color color;
  final String text;
  final bool isOnBreak;
  final bool isActive;
  final bool isLoading; // ✅ new

  final VoidCallback? onTap;
  final bool enabled;

  final bool showBreakBadge;
  final String breakBadgeText;
  final Color? breakBadgeColor;

  final VoidCallback? onBreakTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rippleSize = size + 40;

    return Center(
      child: SizedBox(
        width: rippleSize + 40,
        height: rippleSize + 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            WaterRippleEffect(
              color: color,
              size: 250,
              opacityFactor: 0.25,
              minScale: 0.2,
              maxScale: 1.6,
              duration: const Duration(milliseconds: 5000),
              rippleCount: 4,
              play: isActive,
            ),
            ButtonAnimations.press(
              // ✅ block taps while loading too
              onTap: (enabled && !isLoading) ? onTap : null,
              child: Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                // ✅ swap content for a spinner while loading
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 34,
                          width: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(kWhite),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.only(left: isOnBreak ? 4 : 0),
                              child: CommonImageView(
                                imagePath: isOnBreak
                                    ? Assets.imagesMugHotWhite
                                    : Assets.imagesCheckInHand,
                                height: isOnBreak ? 64 : 106,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppText.h5(
                            text,
                            color: kWhite,
                            weight: FontWeight.w600,
                          ),
                        ],
                      ),
              ),
            ),

            /// ✅ FIXED CONDITION — also hide badge while loading
            if (showBreakBadge && enabled && !isOnBreak && !isLoading)
              Positioned(
                bottom: size * 0.13,
                right: size * 0.13,
                child: ButtonAnimations.press(
                  onTap: onBreakTap,
                  child: Container(
                    width: size * 0.32,
                    height: size * 0.32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: breakBadgeColor ?? kYellowColor,
                      boxShadow: [
                        BoxShadow(
                          color: (breakBadgeColor ?? kYellowColor).withOpacity(
                            0.4,
                          ),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CommonImageView(
                          imagePath: Assets.imagesMugHot,
                          height: 26,
                        ),
                        const SizedBox(height: 2),
                        AppText.p2(breakBadgeText, color: kSubText),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
