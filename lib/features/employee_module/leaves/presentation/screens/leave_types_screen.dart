import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/leaves/data/leaves_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/main.dart';

class LeaveTypesScreen extends StatefulWidget {
  const LeaveTypesScreen({super.key});

  @override
  State<LeaveTypesScreen> createState() => _LeaveTypesScreenState();
}

class _LeaveTypesScreenState extends State<LeaveTypesScreen> {
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

  @override
  Widget build(BuildContext context) {
    final types = _store.types;
    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: Column(
          children: [
            const BackButtonBg(
              title: 'Leave types',
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ShimmerRefreshIndicator(
                instagramStyle: true,
                triggerFraction: 0.40,
                showOrb: false,
                onRefresh: () => _store.refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CommonImageView(
                            imagePath: Assets.imagesInfoCircle,
                            height: 25,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppText.p2(
                              _store.quotaResetLabel,
                              color: kSubText,
                              weight: FontWeight.w500,
                              align: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final type in types) ...[
                      _LeaveTypeCard(type: type),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveTypeCard extends StatelessWidget {
  const _LeaveTypeCard({required this.type});

  final LeaveTypeInfo type;

  static Color colorForProgress(double progress) {
    if (progress <= 0) return kGreyColor;
    if (progress <= 0.33) return kPrimaryColor;
    if (progress < 0.7) return kPurple;
    return kredColor;
  }

  String _usedLabel(int used) =>
      used == 0 ? '0' : used.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final used = type.used;
    final progress = type.progress.clamp(0.0, 1.0);
    final accent = colorForProgress(progress);
    final totalLabel = type.total.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText.p1(
                  type.name,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _usedLabel(used),
                      style: TextStyle(
                        fontFamily: AppFonts.Poppins,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    TextSpan(
                      text: ' / $totalLabel',
                      style: const TextStyle(
                        fontFamily: AppFonts.Poppins,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: kBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: kGreyContainerGreyColor.withValues(
                    alpha: 0.7,
                  ),
                  color: colorForProgress(value),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppText.caption(
                type.resetLabel,
                color: kGreyColor,
                weight: FontWeight.w400,
                align: TextAlign.left,
              ),
              const Spacer(),
              ButtonAnimations.press(
                onTap: () {},
                child: Row(
                  children: [
                    AppText.caption(
                      'View details',
                      color: kSubText,
                      weight: FontWeight.w500,
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: kSubText),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
