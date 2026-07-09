import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import 'text_widget.dart';

// ignore: must_be_immutable
class MyBullet extends StatelessWidget {
  MyBullet({super.key, required this.point, this.size});
  String point;
  double? size;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: '•',
            //paddingLeft: 25,
            color: kSubText,
            paddingRight: 10,
          ),
          Expanded(
            child: TextWidget(
              text: point,
              color: kSubText,
              size: size ?? 14,
              fontFamily: AppFonts.Poppins,
            ),
          ),
          SizedBox(width: 10),
        ],
      ),
    );
  }
}
