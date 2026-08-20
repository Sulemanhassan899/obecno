import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
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
