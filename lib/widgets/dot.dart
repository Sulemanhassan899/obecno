import 'package:obecno/core/constants/all_colors.dart';
import 'package:flutter/material.dart';

class Dot extends StatelessWidget {
  const Dot();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3)),
        Container(width: 20, height: 2, color: kGreyColor.withOpacity(0.3)),
        Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3)),
      ],
    );
  }
}
