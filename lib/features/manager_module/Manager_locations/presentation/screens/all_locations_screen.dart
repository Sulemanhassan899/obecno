import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/location_overview_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/invite_sent_dialog.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/new_location_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class AllLocationsScreen extends StatefulWidget {
  const AllLocationsScreen({super.key});

  @override
  State<AllLocationsScreen> createState() => _AllLocationsScreenState();
}

class _AllLocationsScreenState extends State<AllLocationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ManagerLocationsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerLocationsProvider>();
    final locations = provider.locations;
    final isInitialLoad = provider.isLoading && locations.isEmpty;

    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              BackButtonBg(
                title: 'Offices & Locations',
                padding: EdgeInsets.zero,
                rightWidget: ManagerPlusButton(
                  onTap: () => NewLocationSheet.show(context),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: isInitialLoad
                      ? const Center(child: CircularProgressIndicator())
                      : provider.hasError && locations.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            AppText.p1(
                              provider.errorMessage ??
                                  'Failed to load locations.',
                              color: kSubText,
                              align: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: provider.load,
                                child: const Text('Retry'),
                              ),
                            ),
                          ],
                        )
                      : locations.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            AppText.p1(
                              'No locations found.',
                              color: kSubText,
                              align: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: locations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final location = locations[index];
                            return _LocationCard(
                              location: location,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LocationOverviewScreen(
                                      location: location,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onTap});

  final ManagerLocationModel location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite,
      borderRadius: BorderRadius.circular(18),
      child: ButtonAnimations.press(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText.h4(
                          location.name,
                          weight: FontWeight.w700,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: CommonImageView(
                                imagePath: Assets.imagesLocationDot,
                                height: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AppText.p2(
                                location.address.isEmpty
                                    ? 'No Location'
                                    : location.address,
                                color: kGreyColor,
                                align: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CommonImageView(
                    url: location.hasNetworkImage ? location.image : null,
                    imagePath: location.hasNetworkImage
                        ? null
                        : location.imagePath,
                    height: 52,
                    width: 52,
                    fit: BoxFit.cover,
                    radius: 12,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Present',
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${location.present}',
                              style: const TextStyle(
                                color: kPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${location.total}',
                              style: const TextStyle(
                                color: kGreyColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: kDividerColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: _Metric(
                        label: 'Late',
                        child: AppText.h5(
                          '${location.lateCheckIns}',
                          color: kredColor,
                          weight: FontWeight.w700,
                          align: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        const SizedBox(height: 2),
        AppText.p2(
          label,
          color: kGreyColor,
          weight: FontWeight.w500,
          align: TextAlign.left,
        ),
      ],
    );
  }
}
