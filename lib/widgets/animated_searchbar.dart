import 'dart:math';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimSearchBar extends StatefulWidget {
  final double width;
  final double height;
  final TextEditingController textController;
  final Icon? suffixIcon;
  final Icon? prefixIcon;
  final String helpText;
  final int animationDurationInMilli;
  final VoidCallback onSuffixTap;
  final bool rtl;
  final bool autoFocus;
  final TextStyle? style;
  final bool closeSearchOnSuffixTap;
  final Color? color;
  final Color? textFieldColor;
  final Color? searchIconColor;
  final Color? textFieldIconColor;
  final Color? borderColor;
  final List<TextInputFormatter>? inputFormatters;
  final bool boxShadow;
  final Function(String) onSubmitted;
  final TextInputAction textInputAction;
  final Function(int) searchBarOpen;
  final ValueChanged<String>? onChanged;
  final bool closeOnSubmit;
  final bool autoOpen;

  const AnimSearchBar({
    Key? key,
    required this.width,
    required this.searchBarOpen,
    required this.textController,
    this.suffixIcon,
    this.prefixIcon,
    this.helpText = "",
    this.height = 100,
    this.color = Colors.white,
    this.textFieldColor = Colors.white,
    this.searchIconColor = Colors.black,
    this.textFieldIconColor = Colors.black,
    this.borderColor,
    this.textInputAction = TextInputAction.done,
    required this.onSuffixTap,
    this.animationDurationInMilli = 500,
    required this.onSubmitted,
    this.onChanged,
    this.closeOnSubmit = true,
    this.autoOpen = false,
    this.rtl = false,
    this.autoFocus = false,
    this.style,
    this.closeSearchOnSuffixTap = false,
    this.boxShadow = true,
    this.inputFormatters,
  }) : super(key: key);

  @override
  State<AnimSearchBar> createState() => _AnimSearchBarState();
}

class _AnimSearchBarState extends State<AnimSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _con;
  late final FocusNode focusNode;

  /// 0 = closed, 1 = open (instance state — not global)
  int _toggle = 0;
  String _textFieldValue = '';
  bool _isClosing = false;

  Color get _borderColor => widget.borderColor ?? kBorderColor;

  Duration get _duration =>
      Duration(milliseconds: widget.animationDurationInMilli);

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    _con = AnimationController(vsync: this, duration: _duration);

    if (widget.autoOpen) {
      // Start closed so the expand-from-right animation is visible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _open();
      });
    }
  }

  @override
  void dispose() {
    _con.stop();
    _con.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void unfocusKeyboard() {
    focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _open() async {
    if (_toggle == 1 || _isClosing) return;
    setState(() => _toggle = 1);
    widget.searchBarOpen(1);
    await _con.forward();
    if (!mounted) return;
    if (widget.autoFocus) {
      FocusScope.of(context).requestFocus(focusNode);
    }
  }

  Future<void> _close({bool clearText = true}) async {
    if (_toggle == 0 || _isClosing) return;
    _isClosing = true;
    unfocusKeyboard();

    if (clearText) {
      widget.textController.clear();
      _textFieldValue = '';
      widget.onChanged?.call('');
    }

    if (mounted) setState(() => _toggle = 0);

    try {
      await _con.reverse();
    } catch (_) {
      // Controller may already be disposing.
    }

    if (!mounted) return;
    _isClosing = false;
    widget.searchBarOpen(0);
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _toggle == 1;

    return Container(
      height: widget.height,
      alignment: widget.rtl ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        height: widget.height,
        width: isOpen ? widget.width : 48.0,
        decoration: BoxDecoration(
          color: isOpen ? widget.textFieldColor : widget.color,
          borderRadius: BorderRadius.circular(30.0),
          border: Border.all(color: _borderColor, width: 1.5),
          boxShadow: widget.boxShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            /// Text field row (centered vertically)
            AnimatedOpacity(
              opacity: isOpen ? 1.0 : 0.0,
              duration: Duration(
                milliseconds: (widget.animationDurationInMilli * 0.6).round(),
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 0, top: 5),
                alignment: Alignment.centerRight,
                width: widget.width / 1.3,

                child: TextField(
                  controller: widget.textController,
                  inputFormatters: widget.inputFormatters,
                  focusNode: focusNode,
                  textInputAction: widget.textInputAction,
                  cursorRadius: const Radius.circular(10.0),
                  cursorWidth: 2.0,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    _textFieldValue = value;
                    widget.onChanged?.call(value);
                  },
                  onSubmitted: (value) async {
                    widget.onSubmitted(value);
                    if (widget.closeOnSubmit) await _close();
                  },
                  onEditingComplete: () async {
                    if (widget.closeOnSubmit) await _close();
                  },
                  style:
                      widget.style ??
                      const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        height: 1.2,
                      ),
                  cursorColor: Colors.black,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.only(bottom: 5),
                    hintText: widget.helpText.isEmpty ? null : widget.helpText,
                    hintStyle: TextStyle(
                      color: kGreyColor.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            /// Clear / close button
            Positioned(
              right: 7,
              child: AnimatedOpacity(
                opacity: isOpen ? 1.0 : 0.0,
                duration: Duration(
                  milliseconds: (widget.animationDurationInMilli * 0.6).round(),
                ),
                child: IgnorePointer(
                  ignoring: !isOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      widget.onSuffixTap();
                      if (_textFieldValue.isEmpty ||
                          widget.closeSearchOnSuffixTap) {
                        await _close();
                      } else {
                        widget.textController.clear();
                        _textFieldValue = '';
                        widget.onChanged?.call('');
                        setState(() {});
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kBorderColor,
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      child: AnimatedBuilder(
                        animation: _con,
                        child:
                            widget.suffixIcon ??
                            Icon(
                              Icons.close,
                              size: 18.0,
                              color: widget.textFieldIconColor,
                            ),
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _con.value * 2.0 * pi,
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// Prefix / back
            Positioned(
              left: 0,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30.0),
                child: IconButton(
                  splashRadius: 19.0,
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: widget.prefixIcon != null
                      ? (isOpen
                            ? Icon(
                                Icons.arrow_back_ios,
                                color: widget.textFieldIconColor,
                                size: 18,
                              )
                            : widget.prefixIcon!)
                      : Icon(
                          isOpen ? Icons.arrow_back_ios : Icons.search,
                          color: isOpen
                              ? widget.textFieldIconColor
                              : widget.searchIconColor,
                          size: 20.0,
                        ),
                  onPressed: () async {
                    if (_toggle == 0) {
                      await _open();
                    } else {
                      await _close();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
