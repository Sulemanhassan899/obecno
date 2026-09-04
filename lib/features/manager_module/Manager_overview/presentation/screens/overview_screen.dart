import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
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
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            provider.refresh(),
            context.read<ManagerLocationsProvider>().refresh(),
            context.read<ManagerEmployeesProvider>().refresh(),
          ]);
        },
        child: Padding(
          padding: AppSizes.DEFAULT,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              const SliverToBoxAdapter(child: OverviewHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (isInitialLoad)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.hasError && summary == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _OverviewError(
                    message:
                        provider.errorMessage ?? 'Failed to load overview.',
                    onRetry: provider.load,
                  ),
                )
              else if (summary != null) ...[
                SliverToBoxAdapter(child: OverviewStatsCard(summary: summary)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                const SliverToBoxAdapter(child: OverviewActionsGrid()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.p1(message, color: kSubText, align: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
