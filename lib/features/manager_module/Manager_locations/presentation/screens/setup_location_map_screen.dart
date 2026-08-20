import 'dart:async';

import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/toast_helper.dart';
import 'package:Obecno/shared/location/service/location_service.dart';
import 'package:Obecno/shared/location/service/place_search_service.dart';
import 'package:Obecno/shared/location/service/reverse_geocoding_service.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SelectedMapAddress {
  const SelectedMapAddress({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}

/// Full-screen map picker: tap map / search / use current location → confirm.
class SetupLocationMapScreen extends StatefulWidget {
  const SetupLocationMapScreen({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;

  static Future<SelectedMapAddress?> open(
    BuildContext context, {
    String? initialAddress,
    double? initialLatitude,
    double? initialLongitude,
  }) {
    return Navigator.push<SelectedMapAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupLocationMapScreen(
          initialAddress: initialAddress,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
        ),
      ),
    );
  }

  @override
  State<SetupLocationMapScreen> createState() => _SetupLocationMapScreenState();
}

class _SetupLocationMapScreenState extends State<SetupLocationMapScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _locationService = LocationServiceImpl();

  late LatLng _selected;
  String _address = '';
  bool _resolving = false;
  bool _searching = false;
  bool _locating = false;
  List<PlaceSearchResult> _results = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(
      widget.initialLatitude ?? 52.4862,
      widget.initialLongitude ?? -1.8904,
    );
    _address = widget.initialAddress?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_address.isEmpty) {
        unawaited(_goToCurrentLocation(silent: true));
      } else {
        unawaited(_resolveAddress(_selected));
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng point) async {
    setState(() {
      _selected = point;
      _resolving = true;
    });

    final name = await ReverseGeocodingServiceImpl.instance.resolve(
      lat: point.latitude,
      lon: point.longitude,
    );

    if (!mounted) return;
    setState(() {
      _resolving = false;
      _address = (name?.trim().isNotEmpty ?? false)
          ? name!.trim()
          : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    });
  }

  Future<void> _goToCurrentLocation({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final reading = await _locationService.getCurrentReading();
      final point = LatLng(reading.location.lat, reading.location.lon);
      _mapController.move(point, 16);
      await _resolveAddress(point);
    } catch (e) {
      if (!silent && mounted) {
        ToastHelper.couldNotGetLocation(context);
      }
      if (_address.isEmpty) {
        await _resolveAddress(_selected);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final q = value.trim();
      if (q.length < 3) {
        if (mounted) setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final results = await PlaceSearchService.instance.search(q);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = results;
      });
    });
  }

  Future<void> _selectSearchResult(PlaceSearchResult result) async {
    FocusScope.of(context).unfocus();
    final point = LatLng(result.lat, result.lon);
    _searchController.text = result.displayName;
    setState(() {
      _results = const [];
      _address = result.displayName;
      _selected = point;
    });
    _mapController.move(point, 16);
  }

  void _confirm() {
    final address = _address.trim();
    if (address.isEmpty || _resolving) return;
    Navigator.pop(
      context,
      SelectedMapAddress(
        address: address,
        latitude: _selected.latitude,
        longitude: _selected.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: BackButtonBg(
                title: 'Set up Location',
                padding: EdgeInsets.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search address',
                  hintStyle: const TextStyle(color: kGreyColor, fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: kGreyColor),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _results = const []);
                                },
                              )),
                  filled: true,
                  fillColor: kWhite,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: kBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: kBorderColor),
                  ),
                ),
              ),
            ),
            if (_results.isNotEmpty)
              Flexible(
                flex: 0,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: kDividerColor),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.place_outlined,
                          color: kGreyColor,
                          size: 20,
                        ),
                        title: AppText.caption(
                          item.displayName,
                          align: TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSearchResult(item),
                      );
                    },
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selected,
                      initialZoom: 15,
                      onTap: (_, point) => _resolveAddress(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.obecno.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selected,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              color: kredColor,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _locating ? null : () => _goToCurrentLocation(),
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: kWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: kBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: kBlack.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _locating
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: kBlack,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(
                color: kWhite,
                border: Border(top: BorderSide(color: kDividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.caption(
                    'Selected address',
                    color: kGreyColor,
                    weight: FontWeight.w500,
                    align: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.place,
                          size: 18,
                          color: kPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _resolving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : AppText.p2(
                                _address.isEmpty
                                    ? 'Tap on the map to select a location'
                                    : _address,
                                color: kBlack,
                                weight: FontWeight.w500,
                                align: TextAlign.left,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  MyButton(
                    buttonText: 'Use this address',
                    backgroundColor: kPrimaryButtonColor,
                    isactive: !_resolving && _address.trim().isNotEmpty,
                    onTap: () async => _confirm(),
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
