import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

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
