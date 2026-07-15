import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/shared/widgets/custom_textfield.dart';
import 'package:Obecno/shared/widgets/custom_textfield_2.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:flutter/material.dart';

/// ======================
/// MODEL
/// ======================
class CountryModel {
  final String name;
  final String dialCode;

  CountryModel({required this.name, required this.dialCode});
}

List<CountryModel> countryList = [
  CountryModel(name: "Pakistan", dialCode: "+92"),
  CountryModel(name: "USA", dialCode: "+1"),
  CountryModel(name: "India", dialCode: "+91"),
  CountryModel(name: "UK", dialCode: "+44"),
];

/// ======================
/// DROPDOWN
/// ======================
class CountryDropdown extends StatefulWidget {
  final Function(CountryModel) onSelected;
  final CountryModel selected;

  const CountryDropdown({
    super.key,
    required this.onSelected,
    required this.selected,
  });

  @override
  State<CountryDropdown> createState() => _CountryDropdownState();
}

class _CountryDropdownState extends State<CountryDropdown> {
  OverlayEntry? overlayEntry;

  void toggleDropdown() {
    if (overlayEntry == null) {
      overlayEntry = _createOverlay();
      Overlay.of(context).insert(overlayEntry!);
    } else {
      overlayEntry?.remove();
      overlayEntry = null;
    }
  }

  OverlayEntry _createOverlay() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 6,
        width: size.width + 160,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: countryList.map((country) {
                return ListTile(
                  title: TextWidget(
                    text: "${country.name} (${country.dialCode})",
                    size: 14,
                  ),
                  onTap: () {
                    widget.onSelected(country);
                    toggleDropdown();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggleDropdown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextWidget(
            text: widget.selected.dialCode,
            weight: FontWeight.w500,
            size: 14,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );
  }
}

/// ======================
/// PHONE FIELD
/// ======================
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String selectedCode;
  final Function(String) onCodeChanged;

  const PhoneField({
    super.key,
    required this.controller,
    required this.selectedCode,
    required this.onCodeChanged,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late CountryModel selectedCountry;

  String? errorText;
  bool isValid = false;

  @override
  void initState() {
    super.initState();

    selectedCountry = countryList.firstWhere(
      (c) => c.dialCode == widget.selectedCode,
      orElse: () => countryList.first,
    );
  }

  /// ======================
  /// VALIDATION
  /// ======================
  void validate(String value) {
    if (value.isEmpty) {
      errorText = "Phone is required";
      isValid = false;
    } else if (value.length < 9) {
      errorText = "Invalid phone number";
      isValid = false;
    } else {
      errorText = null;
      isValid = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null
        ? Colors.red
        : isValid
        ? Colors.green
        : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// LABEL
        Row(
          children: [
            AppText.p2("Phone", weight: FontWeight.w500),

            const SizedBox(width: 4),
            const Text("*", style: TextStyle(color: Colors.red)),
          ],
        ),

        const SizedBox(height: 10),

        /// FIELD
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              /// COUNTRY
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 18),
                    const SizedBox(width: 8),

                    CountryDropdown(
                      selected: selectedCountry,
                      onSelected: (val) {
                        setState(() => selectedCountry = val);
                        widget.onCodeChanged(val.dialCode);
                      },
                    ),
                  ],
                ),
              ),

              /// INPUT
              Expanded(
                child: CustomTextField2(
                  controller: widget.controller,
                  hintText: "300 123 4567",
                  hintTextFontColor: kBlack,
                  hintTextFontSize: 14,
                  keyboardType: TextInputType.phone,
                  haveLebelText: false,
                  radius: 0,
                  bottom: 0,
                  isExpanded: true,
                  enabledBorderColor: kTransperentColor,
                  focusedBorderColor: kTransperentColor,
                  errorBorderColor: Colors.red,
                  focusedBorderWidth: 0,
                  backgroundColor: Colors.transparent,
                  contentPaddingLeft: 12,
                  onChanged: validate,
                ),
              ),

              /// VALID ICON
              if (isValid)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.check_circle, color: Colors.green),
                ),
            ],
          ),
        ),

        /// ERROR TEXT
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: AppText.p2(
              errorText!,
              color: kredColor,
              weight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
