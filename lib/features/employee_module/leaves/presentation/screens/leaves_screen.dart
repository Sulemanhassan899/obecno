import 'package:flutter/cupertino.dart';
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
import 'package:obecno/features/employee_module/leaves/presentation/screens/holidays_calendar_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leave_history_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leave_types_screen.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/apply_leave_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_detail_sheet.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_request_card.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:obecno/main.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen>
    with WidgetsBindingObserver {
  final LeavesStore _store = bindings.leavesStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_refresh);
    _store.ensureLoaded();
    _store.watchPendingStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.unwatchPendingStatuses();
    _store.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _store.refresh();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openApply() async {
    await ApplyLeaveSheet.show(context);
    await _store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final balances = _store.balances;
    final requests = _store.requests;

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: Column(
          children: [
            const BackButtonBg(
              title: 'Leaves',
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            const SizedBox(height: 16),
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
                    _summaryCard(balances),
                    const SizedBox(height: 12),
                    _linksCard(),
                    if (requests.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      AppText.p1(
                        'Recent Requests',
                        weight: FontWeight.w600,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 12),
                      for (final request in requests.take(8)) ...[
                        LeaveRequestCard(
                          request: request,
                          onTap: () => LeaveDetailSheet.show(
                            context,
                            requestId: request.id,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Material(
          elevation: 10,
          color: kTransperentColor,
          borderRadius: BorderRadius.circular(50),
          shadowColor: kBlack.withOpacity(0.9),
          child: MyButton(
            width: 200,
            buttonText: 'Apply for Leave',
            backgroundColor: kBlack,
            fontColor: kWhite,
            onTap: _openApply,
          ),
        ),
      ),
    );
  }

  /// Stats + Leave types in one card (matches design).
  Widget _summaryCard(LeaveBalancesSummary balances) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 18),
            child: Row(
              children: [
                _statCell(
                  value: '${balances.allAvailable}',
                  total: '${balances.allTotal}',
                  label: 'All Leaves',
                  valueColor: kPrimaryColor,
                ),
                Container(width: 1, height: 48, color: kBorderColor),
                _statCell(
                  value: '${balances.casualAvailable}',
                  total: '${balances.casualTotal}',
                  label: 'Casual Leaves',
                  valueColor: kPurple,
                ),
                Container(width: 1, height: 48, color: kBorderColor),
                _statCell(
                  value: '${balances.sickAvailable}',
                  total: '${balances.sickTotal}',
                  label: 'Sick Leaves',
                  valueColor: kPurple,
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: kBorderColor),
          ),
          ButtonAnimations.press(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaveTypesScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.p1(
                      'Leave types',
                      weight: FontWeight.w500,
                      align: TextAlign.left,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: kGreyColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required String value,
    required String total,
    required String label,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    height: 1.2,
                  ),
                ),
                TextSpan(
                  text: ' / $total',
                  style: const TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 22,
                    color: kBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppText.caption(label, color: kGreyColor, weight: FontWeight.w500),
        ],
      ),
    );
  }

  Widget _linksCard() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          _navRow(
            paddingLeft: 14,
            paddingRight: 10,
            paddingVertical: 16,
            title: 'Leaves History',
            icon: Assets.imagesCalendarDay,
            size: 20,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaveHistoryScreen()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: kBorderColor),
          ),
          _navRow(
            paddingLeft: 10,
            paddingRight: 10,
            paddingVertical: 16,
            title: 'Holidays Calendar',
            icon: Assets.imagesLeavesFilledIcon,
            size: 26,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HolidaysCalendarScreen(
                    mode: HolidaysCalendarMode.employee,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _navRow({
    required String title,
    required String icon,
    required double size,
    required double paddingLeft,
    required double paddingRight,
    required double paddingVertical,
    required VoidCallback onTap,
  }) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: paddingLeft,
          right: paddingRight,
          top: paddingVertical,
          bottom: paddingVertical,
        ),
        child: Row(
          children: [
            CommonImageView(imagePath: icon, height: size),
            const SizedBox(width: 12),
            Expanded(
              child: AppText.p1(
                title,
                align: TextAlign.left,
                weight: FontWeight.w500,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }
}
