import 'package:Obecno/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import 'text_widget.dart';

class CustomCheckbox extends StatefulWidget {
  final String? text;
  final String? text2;
  final Color? textcolor;
  final Function(bool) onChanged;

  const CustomCheckbox({
    super.key,
    this.text,
    this.text2,
    required this.onChanged,
    this.textcolor,
  });

  @override
  State<CustomCheckbox> createState() => _CustomCheckboxState();
}

class _CustomCheckboxState extends State<CustomCheckbox> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _isChecked = !_isChecked);
        widget.onChanged(_isChecked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min, // ✅ important
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _isChecked ? kPrimaryColor : kWhite,
              border: Border.all(
                color: _isChecked ? kPrimaryColor : kBorderColor,
                width: 1,
              ),
            ),
            child: _isChecked
                ? const Icon(Icons.check, color: kWhite, size: 16)
                : null,
          ),

          const SizedBox(width: 8),

          /// ✅ FIXED TEXT HANDLING
          Flexible(
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.text != null)
                  AppText.p2(widget.text!, color: widget.textcolor ?? kSubText),
                if (widget.text2 != null)
                  AppText.p2(
                    widget.text2!,
                    color: widget.textcolor ?? kSubText,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
