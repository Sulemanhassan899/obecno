import 'package:obecno/core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/widgets/field_error_text.dart';
import 'text_widget.dart';

class CustomDropDown extends StatelessWidget {
  const CustomDropDown({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,

    this.hint,
    this.labelText,
    this.bgColor,
    this.marginBottom,
    this.width,

    /// 🔹 from second widget
    this.textSize,
    this.textColor,
    this.textWeight,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.hasStar = false,
    this.validator,
  });

  final List<dynamic>? items;
  final String selectedValue;
  final ValueChanged<dynamic>? onChanged;

  final String? hint;
  final String? labelText;

  final Color? bgColor;
  final double? marginBottom, width;

  final double? textSize, iconSize;
  final Color? textColor, iconColor;
  final FontWeight? textWeight;
  final Widget? icon;
  final bool hasStar;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom ?? 16),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: FormField<String>(
          initialValue: selectedValue.isEmpty ? null : selectedValue,
          validator: validator == null
              ? null
              : (_) => validator!(
                  selectedValue.trim().isEmpty ? null : selectedValue,
                ),
          builder: (field) {
            final hasError = field.hasError;
            final borderColor = hasError ? kRed : kBorderColor;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (labelText != null) ...[
                  Row(
                    children: [
                      AppText.p2(labelText ?? '', weight: FontWeight.w500),
                      if (hasStar)
                        const TextWidget(
                          text: ' *',
                          size: 14,
                          weight: FontWeight.w600,
                          color: kRed,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                Container(
                  height: 48,
                  width: width ?? double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: bgColor ?? kWhite,
                    border: Border.all(
                      color: borderColor,
                      width: hasError ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      isExpanded: true,
                      value: items != null && items!.contains(selectedValue)
                          ? selectedValue
                          : null,

                      hint: TextWidget(
                        text: hint ?? '',
                        size: textSize ?? 12,
                        color: textColor,
                        weight: textWeight ?? FontWeight.w500,
                      ),

                      icon:
                          icon ??
                          Icon(
                            Icons.arrow_drop_down,
                            size: iconSize ?? 24,
                            color: iconColor ?? kBlack,
                          ),

                      items: items?.map((item) {
                        return DropdownMenuItem<dynamic>(
                          value: item,
                          child: TextWidget(
                            text: item.toString(),
                            size: textSize ?? 12,
                            color: textColor ?? kBlack,
                            weight: textWeight ?? FontWeight.w600,
                          ),
                        );
                      }).toList(),

                      onChanged: (value) {
                        if (value == null) return;
                        onChanged?.call(value);
                        field.didChange(value.toString());
                        if (field.hasError) {
                          field.validate();
                        }
                      },
                    ),
                  ),
                ),

                if (hasError) FieldErrorText(field.errorText!),
              ],
            );
          },
        ),
      ),
    );
  }
}
