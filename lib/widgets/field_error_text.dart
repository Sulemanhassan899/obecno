import 'package:flutter/material.dart';
import 'package:obecno/widgets/text_widget.dart';

/// Canonical field-error spacing used across the app (Book a Demo standard).
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.text, {super.key});

  final String text;

  static const EdgeInsets padding = EdgeInsets.only(
    left: 4,
    top: 10,
    bottom: 10,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextWidget(
        text: text,
        size: 12,
        color: Colors.red,
        textAlign: TextAlign.left,
      ),
    );
  }
}
