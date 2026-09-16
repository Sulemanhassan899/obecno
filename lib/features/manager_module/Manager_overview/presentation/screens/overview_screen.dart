import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/presentation/widgets/overview_header.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:flutter/material.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManagerOverviewProvider>().load();
      context.read<ManagerLocationsProvider>().load();
      context.read<ManagerEmployeesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerOverviewProvider>();
    final summary = provider.summary;
    final isInitialLoad = provider.isLoading && summary == null;

    return Scaffold(
      backgroundColor: kbackground1,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: ShimmerRefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              provider.refresh(),
              context.read<ManagerLocationsProvider>().refresh(),
              context.read<ManagerEmployeesProvider>().refresh(),
            ]);
          },
          child: Padding(
            padding: AppSizes.page(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: OverviewHeader()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                if (isInitialLoad)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: ShimmerProgress()),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: OverviewStatsCard(
                      summary: summary ?? OverviewSummary.empty,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  const SliverToBoxAdapter(child: OverviewActionsGrid()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
