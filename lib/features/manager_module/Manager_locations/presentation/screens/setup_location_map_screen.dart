import 'dart:async';

import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/shared/location/service/location_service.dart';
import 'package:obecno/shared/location/service/place_search_service.dart';
import 'package:obecno/shared/location/service/reverse_geocoding_service.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SelectedMapAddress {
  const SelectedMapAddress({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = ManagerLocationModel.defaultRadiusMeters,
  });

  final String address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
}

/// Full-screen map picker: tap map / search / use current location → confirm.
class SetupLocationMapScreen extends StatefulWidget {
  const SetupLocationMapScreen({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadiusMeters,
  });

  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final int? initialRadiusMeters;

  static Future<SelectedMapAddress?> open(
    BuildContext context, {
    String? initialAddress,
    double? initialLatitude,
    double? initialLongitude,
    int? initialRadiusMeters,
  }) {
    return Navigator.push<SelectedMapAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupLocationMapScreen(
          initialAddress: initialAddress,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialRadiusMeters: initialRadiusMeters,
        ),
      ),
    );
  }

  @override
  State<SetupLocationMapScreen> createState() => _SetupLocationMapScreenState();
}

class _SetupLocationMapScreenState extends State<SetupLocationMapScreen> {
  static const _selectedMarkerId = MarkerId('selected');
  static const _radiusCircleId = CircleId('radius');
  static const _minRadiusMeters = 10;
  static const _maxRadiusMeters = 5000;

  final _searchController = TextEditingController();
  late final TextEditingController _radiusController;
  final _locationService = LocationServiceImpl();

  GoogleMapController? _mapController;
  late LatLng _selected;
  late int _radiusMeters;
  String _address = '';
  bool _resolving = false;
  bool _searching = false;
  bool _locating = false;
  List<PlaceSearchResult> _results = const [];
  Timer? _debounce;
  String? _radiusError;

  CameraPosition get _initialCamera => CameraPosition(
        target: _selected,
        zoom: 15,
      );

  Set<Marker> get _markers => {
        Marker(
          markerId: _selectedMarkerId,
          position: _selected,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };

  Set<Circle> get _circles => {
        Circle(
          circleId: _radiusCircleId,
          center: _selected,
          radius: _radiusMeters.toDouble(),
          fillColor: kBlue.withOpacity(0.18),
          strokeColor: kBlue,
          strokeWidth: 2,
        ),
      };

  @override
  void initState() {
    super.initState();
    _selected = LatLng(
      widget.initialLatitude ?? 52.4862,
      widget.initialLongitude ?? -1.8904,
    );
    _radiusMeters = _normalizeRadius(
      widget.initialRadiusMeters ?? ManagerLocationModel.defaultRadiusMeters,
    );
    _radiusController = TextEditingController(text: '$_radiusMeters');
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
    _radiusController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  int _normalizeRadius(int value) {
    if (value < _minRadiusMeters) return _minRadiusMeters;
    if (value > _maxRadiusMeters) return _maxRadiusMeters;
    return value;
  }

  void _onRadiusChanged(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _radiusError = 'Enter a radius in meters.');
      return;
    }
    setState(() {
      _radiusMeters = _normalizeRadius(parsed);
      _radiusError = null;
    });
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 16}) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
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
      await _moveCamera(point);
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
    await _moveCamera(point);
  }

  void _confirm() {
    final address = _address.trim();
    if (address.isEmpty || _resolving) return;
    final parsed = int.tryParse(_radiusController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _radiusError = 'Enter a radius in meters.');
      return;
    }
    Navigator.pop(
      context,
      SelectedMapAddress(
        address: address,
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        radiusMeters: _normalizeRadius(parsed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                            child: ShimmerProgress(strokeWidth: 2),
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
                  GoogleMap(
                    initialCameraPosition: _initialCamera,
                    markers: _markers,
                    circles: _circles,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _resolveAddress,
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
                                child: ShimmerProgress(
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
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
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
                                    child: ShimmerProgress(
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
                  CustomTextField(
                    controller: _radiusController,
                    hintText: '250',
                    labelText: 'Radius (meters)',
                    haveLebelText: true,
                    hasStar: true,
                    keyboardType: TextInputType.number,
                    backgroundColor: kWhite,
                    enabledBorderColor: kBorderColor,
                    focusedBorderColor: kPrimaryColor,
                    radius: 12,
                    bottom: 0,
                    reserveHelperSpace: false,
                    errorText: _radiusError,
                    onChanged: _onRadiusChanged,
                  ),
                  const SizedBox(height: 14),
                  MyButton(
                    buttonText: 'Use this address',
                    backgroundColor: kPrimaryColor,
                    isactive: !_resolving &&
                        _address.trim().isNotEmpty &&
                        _radiusError == null,
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
