import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class BreakTimingSheet {
  BreakTimingSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BreakTimingSheetBody(),
    );
  }
}

class _BreakTimingSheetBody extends StatefulWidget {
  const _BreakTimingSheetBody();

  @override
  State<_BreakTimingSheetBody> createState() => _BreakTimingSheetBodyState();
}

class _BreakTimingSheetBodyState extends State<_BreakTimingSheetBody> {
  String _maxBreak = '60:00 mins';
  String _initialMaxBreak = '60:00 mins';
  bool _trackLocation = true;
  bool _initialTrackLocation = true;

  static const _durationOptions = [
    '30:00 mins',
    '45:00 mins',
    '60:00 mins',
    '90:00 mins',
  ];

  void _reset() {
    setState(() {
      _maxBreak = _initialMaxBreak;
      _trackLocation = _initialTrackLocation;
    });
  }

  Future<void> _save() async {
    _initialMaxBreak = _maxBreak;
    _initialTrackLocation = _trackLocation;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      ToastHelper.changesSaved(rootContext);
    });
  }

  Future<void> _pickDuration() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText.h5(
                          'Max break duration',
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                      ),
                      ButtonAnimations.press(
                        onTap: () => Navigator.pop(sheetContext),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kDividerColor),
                ..._durationOptions.map(
                  (option) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(sheetContext, option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText.p2(
                              option,
                              align: TextAlign.left,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (option == _maxBreak)
                            const Icon(
                              Icons.check,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
    if (result != null && mounted) setState(() => _maxBreak = result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.h5(
                      'Break Timing',
                      weight: FontWeight.w600,
                      align: TextAlign.left,
                    ),
                  ),
                  ButtonAnimations.press(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: kDividerColor),
            Expanded(
              child: Container(
                color: kbackground2,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppText.p1(
                          'Enable or disable employee break timings.',
                          color: kGreyColor,
                          weight: FontWeight.w400,
                          align: TextAlign.left,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        children: [
                        GestureDetector(
      behavior: HitTestBehavior.opaque,
                            onTap: _pickDuration,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: AppText.p2(
                                      'Set max break duration',
                                      color: kBlack,
                                      weight: FontWeight.w500,
                                      align: TextAlign.left,
                                    ),
                                  ),
                                  AppText.p2(
                                    _maxBreak,
                                    color: kGreyColor,
                                    weight: FontWeight.w500,
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: kGreyColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppText.p2(
                                    'Break location tracking',
                                    color: kBlack,
                                    weight: FontWeight.w500,
                                    align: TextAlign.left,
                                  ),
                                ),
                                SizedBox(
                                  width: 55,
                                  height: 40,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Switch.adaptive(
                                      value: _trackLocation,
                                      activeColor: kPrimaryColor,
                                      thumbColor: MaterialStateProperty.all(
                                        kWhite,
                                      ),
                                      trackColor: MaterialStateProperty.all(
                                        kPrimaryColor,
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _trackLocation = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 20, 12),
                      child: AppText.p1(
                        'Breaks can only be started and ended when the employee is within office/location premises.',
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: kDividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: MyButton(
                      size: MyButtonSize.normal,
                      buttonText: 'Reset',
                      backgroundColor: kWhite,
                      fontColor: kBlack,
                      outlineColor: kBorderColor,
                      onTap: () async => _reset(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: MyButton(
                      buttonText: 'Save',
                      backgroundColor: kPrimaryButtonColor,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
