import 'package:Obecno/controller/overview_controller.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/model/overview_model.dart';
import 'package:Obecno/screens/Manager_module/overview_module/widgets/overview_header.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final OverViewController _controller = OverViewController();

  @override
  void initState() {
    super.initState();

    _controller.summary = OverViewMonthSummary(
      workingDays: 20,
      totalDays: 30,
      absentOrLeaves: 5,
      lateCheckIns: 2,
      lateCheckOuts: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final summary = _controller.summary;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const OverviewHeader(),

                const SizedBox(height: 20),

                /// 🔥 HANDLE NULL STATE
                if (summary == null)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  /// STATS CARD
                  OverviewStatsCard(summary: summary),
                  const SizedBox(height: 20),

                  /// ACTION GRID
                  const OverviewActionsGrid(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
