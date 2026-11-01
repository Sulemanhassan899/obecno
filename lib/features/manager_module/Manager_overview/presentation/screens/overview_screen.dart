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
  State<OverviewScreen> createState() => OverviewScreenState();
}

class OverviewScreenState extends State<OverviewScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final List<CurvedAnimation> _entranceAnimations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManagerOverviewProvider>().load();
      context.read<ManagerLocationsProvider>().load();
      context.read<ManagerEmployeesProvider>().load();
    });
    _entranceController.forward();
  }

  void playEntranceAnimation() {
    if (!mounted) return;
    _entranceController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    for (final animation in _entranceAnimations) {
      animation.dispose();
    }
    _entranceController.dispose();
    super.dispose();
  }

  CurvedAnimation _curveFor(int index, int total) {
    final safeTotal = total <= 1 ? 1 : total;
    final start = (index / safeTotal) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
    );
  }

  Widget _staggered(int index, int total, Widget child) {
    if (_entranceAnimations.length != total) {
      for (final animation in _entranceAnimations) {
        animation.dispose();
      }
      _entranceAnimations
        ..clear()
        ..addAll(List.generate(total, (i) => _curveFor(i, total)));
    }
    final animation = _entranceAnimations[index];
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 18),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerOverviewProvider>();
    final summary = provider.summary;
    final isInitialLoad = provider.isLoading && summary == null;
    // 0 header, then loading placeholder or stats + actions
    final total = isInitialLoad ? 2 : 3;

    return Scaffold(
      backgroundColor: kbackground1,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: ShimmerRefreshIndicator(
          instagramStyle: true,
          triggerFraction: 0.40,
          showOrb: false,
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
                SliverToBoxAdapter(
                  child: _staggered(0, total, const OverviewHeader()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                if (isInitialLoad)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _staggered(
                      1,
                      total,
                      const Center(child: ShimmerProgress()),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _staggered(
                      1,
                      total,
                      OverviewStatsCard(
                        summary: summary ?? OverviewSummary.empty,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: _staggered(
                      2,
                      total,
                      const OverviewActionsGrid(),
                    ),
                  ),
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
