// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/shared/location/service/location_provider.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

class OfficeLocation extends StatefulWidget {
  const OfficeLocation({super.key});

  @override
  State<OfficeLocation> createState() => _OfficeLocationState();
}

class _OfficeLocationState extends State<OfficeLocation> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<LocationProvider>().refreshUserLocation());
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.HORIZONTAL,
        child: ListenableBuilder(
          listenable: Listenable.merge([authProvider, locationProvider]),
          builder: (context, _) {
            final locations = _orderedLocations(authProvider);
            final defaultId = _defaultLocationId(authProvider);

            return ListView(
              children: [
                const SizedBox(height: 20),

                /// HEADER
                BackButtonBg(title: "Offices & Locations"),

                const SizedBox(height: 20),

                if (locations.isEmpty)
                  _emptyState()
                else
                  for (int i = 0; i < locations.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    _officeCard(
                      location: locations[i],
                      isDefault: locations[i].id == defaultId,
                      liveStatus: locations[i].id == defaultId
                          ? _liveStatusFor(locationProvider)
                          : null,
                    ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  String? _defaultLocationId(AuthProvider authProvider) {
    for (final location in authProvider.locations) {
      if (location.isDefault) return location.id;
    }
    return authProvider.selectedLocation?.id;
  }

  List<AuthLocationModel> _orderedLocations(AuthProvider authProvider) {
    final locations = [...authProvider.locations];
    final defaultId = _defaultLocationId(authProvider);
    if (defaultId == null) return locations;
    locations.sort((a, b) {
      if (a.id == defaultId && b.id != defaultId) return -1;
      if (b.id == defaultId && a.id != defaultId) return 1;
      return 0;
    });
    return locations;
  }

  String? _liveStatusFor(LocationProvider locationProvider) {
    if (locationProvider.isRefreshing) return "Checking your location…";
    if (locationProvider.rangeMessage != null &&
        locationProvider.geofenceResult == null) {
      return locationProvider.rangeMessage;
    }
    final result = locationProvider.geofenceResult;
    if (result == null) return null;
    final distance = result.distanceMeters.round();
    return result.isInside
        ? "You're ${distance}m away — in range"
        : "You're ${distance}m away — out of range";
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: AppText.p2(
          "No offices or locations available",
          color: kGreyColor,
        ),
      ),
    );
  }

  Widget _officeCard({
    required AuthLocationModel location,
    bool isDefault = false,
    String? liveStatus,
  }) {
    final image = location.image ?? '';
    final address = location.displayAddress;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? kPrimaryColor : kBorderColor,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE
          Stack(
            children: [
              CommonImageView(
                url: image.isNotEmpty ? image : null,
                errorImage: Assets.imagesDummyMaps,
                height: 160,
                width: double.infinity,
                topLeftRadius: 16,
                topRightRadius: 16,
                fit: BoxFit.cover,
              ),

              if (isDefault)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText.small("Default", color: kPrimaryColor),
                  ),
                ),
            ],
          ),

          /// TEXT
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h6(location.name, weight: FontWeight.w600),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CommonImageView(
                      imagePath: Assets.imagesLocationDot2,
                      height: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AppText.small(
                        address.isNotEmpty ? address : "--",
                        align: TextAlign.left,
                      ),
                    ),
                  ],
                ),
                if (liveStatus != null) ...[
                  const SizedBox(height: 6),
                  AppText.small(liveStatus, color: kGreyColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
