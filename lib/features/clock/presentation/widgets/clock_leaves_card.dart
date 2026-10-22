import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/leaves/data/leaves_store.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leaves_screen.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/main.dart';

class ClockLeavesCard extends StatefulWidget {
  const ClockLeavesCard({super.key});

  @override
  State<ClockLeavesCard> createState() => _ClockLeavesCardState();
}

class _ClockLeavesCardState extends State<ClockLeavesCard> {
  final LeavesStore _store = bindings.leavesStore;

  @override
  void initState() {
    super.initState();
    _store.addListener(_refresh);
    _store.ensureLoaded();
  }

  @override
  void dispose() {
    _store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _openLeaves(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeavesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final available = _store.totalAvailable;

    return ButtonAnimations.press(
      onTap: () => _openLeaves(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            CommonImageView(
              imagePath: Assets.imagesLeavesBgIcon,
              height: 44,
              width: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.h6('Leaves', weight: FontWeight.w600),
                  const SizedBox(height: 2),
                  AppText.caption(
                    '$available Available',
                    color: kGreyColor,
                    weight: FontWeight.w400,
                  ),
                ],
              ),
            ),
            AppText.p2('Apply for Leave'),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: kBlack),
          ],
        ),
      ),
    );
  }
}
