import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/shared/widgets/back_button.dart';

class ShareButton extends StatelessWidget {
  final VoidCallback onTap;
  const ShareButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,

      child: CommonImageView(imagePath: Assets.imagesShareButton, height: 28),
    );
  }
}
