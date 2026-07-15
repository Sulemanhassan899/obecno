import 'package:Obecno/core/constants/all_colors.dart';
import 'package:flutter/material.dart';


class CheckBoxWidget extends StatelessWidget {
  final bool isChecked;
  final Function(bool?)? onChanged;
  final Color kborderColor;
  final bool haveCheckBoxTrue = false;

  const CheckBoxWidget({
    super.key,
    this.isChecked = false,
    required this.onChanged,
    this.kborderColor = kSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 20,
      child: Checkbox(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        side: BorderSide(color: kSecondaryColor),
        checkColor: Colors.white,
        activeColor: Colors.blue,
        fillColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return kSecondaryColor;
          }
          return Colors.white;
        }),
        value: isChecked,
        onChanged: onChanged,
      ),
    );
  }
}
