import 'package:flutter/material.dart';
import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';

/// A pill ("Status", "Locations") that opens a dropdown list right below
/// itself when tapped, and reports the chosen value back via [onSelected].
///
/// Purely presentational — it owns only the open/closed overlay state,
/// never the selected value itself. That lives in the controller.
class FilterDropdownChip extends StatefulWidget {
  const FilterDropdownChip({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
  });

  /// Current label shown on the chip (e.g. selected value or default title).
  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  State<FilterDropdownChip> createState() => _FilterDropdownChipState();
}

class _FilterDropdownChipState extends State<FilterDropdownChip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _open = false;

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Tap outside to dismiss.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: size.width,
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: widget.options.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: kDividerColor),
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      final selected = option == widget.label;
                      return ButtonAnimations.press(
                        onTap: () {
                          widget.onSelected(option);
                          _close();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: selected
                              ? kPrimaryColor.withOpacity(0.08)
                              : Colors.transparent,
                          child: AppText.p2(
                            option,
                            color: selected ? kPrimaryColor : kBlack,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: ButtonAnimations.press(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: kBorderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: AppText.p2(widget.label, color: kBlack),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}