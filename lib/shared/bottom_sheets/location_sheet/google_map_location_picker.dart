import 'dart:async';

import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/utils/maps_launcher.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/google_maps_link_parser.dart';
import 'package:obecno/shared/location/service/location_service.dart';
import 'package:obecno/shared/location/service/place_search_service.dart';
import 'package:obecno/shared/location/service/reverse_geocoding_service.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PickedOfficeLocation {
  const PickedOfficeLocation({
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

/// Map picker for New Location.
///
/// Uses OpenStreetMap tiles in-app (no Google API key required). Google Maps
/// widgets stay blank when [GOOGLE_MAPS_API_KEY] is missing.
class GoogleMapLocationPicker extends StatefulWidget {
  const GoogleMapLocationPicker({
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

  static Future<PickedOfficeLocation?> open(
    BuildContext context, {
    String? initialAddress,
    double? initialLatitude,
    double? initialLongitude,
    int? initialRadiusMeters,
  }) {
    return Navigator.push<PickedOfficeLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleMapLocationPicker(
          initialAddress: initialAddress,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialRadiusMeters: initialRadiusMeters,
        ),
      ),
    );
  }

  @override
  State<GoogleMapLocationPicker> createState() =>
      _GoogleMapLocationPickerState();
}

class _GoogleMapLocationPickerState extends State<GoogleMapLocationPicker>
    with WidgetsBindingObserver {
  static const _fallback = LatLng(52.4862, -1.8904);
  static const _minRadiusMeters = 10;
  static const _maxRadiusMeters = 5000;
  static const _radiusStepMeters = 10;
  static const _radiusBlue = kBlue;
  static final _radiusFill = kBlue.withOpacity(0.18);

  static final _coordPattern = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$',
  );

  final _mapController = MapController();
  final _locationService = LocationServiceImpl();
  final _searchController = TextEditingController();
  late final TextEditingController _radiusController;

  late LatLng _selected;
  late int _radiusMeters;
  String _address = '';
  bool _resolving = false;
  bool _locating = false;
  bool _searching = false;
  bool _openingMaps = false;
  bool _importing = false;
  bool _mapsLaunched = false;
  String? _radiusError;
  List<PlaceSearchResult> _results = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selected = LatLng(
      widget.initialLatitude ?? _fallback.latitude,
      widget.initialLongitude ?? _fallback.longitude,
    );
    _radiusMeters = _normalizeRadius(
      widget.initialRadiusMeters ?? ManagerLocationModel.defaultRadiusMeters,
    );
    _radiusController = TextEditingController(text: '$_radiusMeters');
    _address = widget.initialAddress?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLatitude == null || widget.initialLongitude == null) {
        unawaited(_goToCurrentLocation(silent: true));
      } else if (_address.isEmpty) {
        unawaited(_resolveAddress(_selected));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _searchController.dispose();
    _radiusController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _mapsLaunched) {
      unawaited(_importFromClipboard(silent: true));
    }
  }

  int _normalizeRadius(int value) {
    if (value < _minRadiusMeters) return _minRadiusMeters;
    if (value > _maxRadiusMeters) return _maxRadiusMeters;
    return value;
  }

  void _onRadiusChanged(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _radiusError = 'Enter a radius in meters.';
      });
      return;
    }
    final next = _normalizeRadius(parsed);
    setState(() {
      _radiusMeters = next;
      _radiusError = null;
    });
  }

  void _setRadius(int value) {
    final next = _normalizeRadius(value);
    _radiusController.text = '$next';
    _radiusController.selection = TextSelection.collapsed(
      offset: _radiusController.text.length,
    );
    setState(() {
      _radiusMeters = next;
      _radiusError = null;
    });
  }

  void _adjustRadius(int delta) {
    final current =
        int.tryParse(_radiusController.text.trim()) ?? _radiusMeters;
    _setRadius(current + delta);
  }

  Widget _radiusStepButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: Icon(icon, size: 22, color: kBlack),
      ),
    );
  }

  Future<void> _resolveAddress(
    LatLng point, {
    String? fallbackLabel,
  }) async {
    setState(() {
      _selected = point;
      _resolving = true;
    });

    final name = await ReverseGeocodingServiceImpl.instance.resolve(
      lat: point.latitude,
      lon: point.longitude,
    );

    if (!mounted) return;
    final resolved = name?.trim();
    setState(() {
      _resolving = false;
      _address = (resolved != null && resolved.isNotEmpty)
          ? resolved
          : (fallbackLabel?.trim().isNotEmpty ?? false)
              ? fallbackLabel!.trim()
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
    } catch (_) {
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

  LatLng? _parseCoordinates(String raw) {
    final match = _coordPattern.firstMatch(raw.trim());
    if (match == null) return null;
    final lat = double.tryParse(match.group(1) ?? '');
    final lon = double.tryParse(match.group(2) ?? '');
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return LatLng(lat, lon);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final q = value.trim();
      if (q.isEmpty) {
        if (mounted) {
          setState(() {
            _results = const [];
            _searching = false;
          });
        }
        return;
      }

      final coords = _parseCoordinates(q);
      if (coords != null) {
        if (!mounted) return;
        setState(() {
          _searching = false;
          _results = [
            PlaceSearchResult(
              displayName:
                  '${coords.latitude.toStringAsFixed(7)}, '
                  '${coords.longitude.toStringAsFixed(7)}',
              lat: coords.latitude,
              lon: coords.longitude,
            ),
          ];
        });
        return;
      }

      if (q.length < 3) {
        if (mounted) {
          setState(() {
            _results = const [];
            _searching = false;
          });
        }
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
    setState(() => _results = const []);
    _mapController.move(point, 16);
    await _resolveAddress(point, fallbackLabel: result.displayName);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _results = const [];
      _searching = false;
    });
  }

  void _zoomBy(double delta) {
    final zoom = (_mapController.camera.zoom + delta).clamp(3.0, 19.0);
    _mapController.move(_mapController.camera.center, zoom);
  }

  Widget _mapRoundButton({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
        child: Center(child: child),
      ),
    );
  }

  Future<void> _openGoogleMapsApp() async {
    if (_openingMaps) return;
    setState(() => _openingMaps = true);
    final opened = await MapsLauncher.open(
      lat: _selected.latitude,
      lon: _selected.longitude,
      label: _address.isEmpty ? 'Office location' : _address,
    );
    if (!mounted) return;
    setState(() {
      _openingMaps = false;
      if (opened) _mapsLaunched = true;
    });
    if (!opened) {
      ToastHelper.error(context, message: 'Could not open Google Maps.');
    }
  }

  Future<void> _importFromClipboard({bool silent = false}) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || !GoogleMapsLinkParser.looksLikeMapsLink(text)) {
        if (!silent && mounted) {
          ToastHelper.error(
            context,
            message:
                'Copy a place link from Google Maps, then tap Paste link.',
          );
        }
        return;
      }

      final parsed = await GoogleMapsLinkParser.parseText(text);
      if (!mounted) return;
      if (parsed == null) {
        if (!silent) {
          ToastHelper.error(
            context,
            message: 'Could not read coordinates from that Google Maps link.',
          );
        }
        return;
      }

      final point = LatLng(parsed.latitude, parsed.longitude);
      _mapController.move(point, 16);
      await _resolveAddress(point, fallbackLabel: parsed.label);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _confirm() {
    final address = _address.trim();
    if (address.isEmpty || _resolving) return;
    final parsed = int.tryParse(_radiusController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _radiusError = 'Enter a radius in meters.');
      return;
    }
    final radius = _normalizeRadius(parsed);
    Navigator.pop(
      context,
      PickedOfficeLocation(
        address: address,
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        radiusMeters: radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _address.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: kbackground1,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: BackButtonBg(
                title: 'Office Location',
                padding: EdgeInsets.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  if (_results.isEmpty) return;
                  unawaited(_selectSearchResult(_results.first));
                },
                decoration: InputDecoration(
                  hintText: 'Search place or lat, lng',
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
                              onPressed: _clearSearch,
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
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selected,
                            radius: _radiusMeters.toDouble(),
                            useRadiusInMeter: true,
                            color: _radiusFill,
                            borderColor: _radiusBlue,
                            borderStrokeWidth: 2,
                          ),
                        ],
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _mapRoundButton(
                          onTap: () => _zoomBy(1),
                          child: const Icon(Icons.add, color: kBlack, size: 24),
                        ),
                        const SizedBox(height: 10),
                        _mapRoundButton(
                          onTap: () => _zoomBy(-1),
                          child: const Icon(
                            Icons.remove,
                            color: kBlack,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _mapRoundButton(
                          onTap:
                              _locating ? null : () => _goToCurrentLocation(),
                          child: _locating
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: ShimmerProgress(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: kBlack,
                                  size: 22,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.48,
              ),
              decoration: const BoxDecoration(
                color: kWhite,
                border: Border(top: BorderSide(color: kDividerColor)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                          child: _resolving || _importing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: ShimmerProgress(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              : AppText.p2(
                                  hasSelection
                                      ? _address
                                      : 'Tap on the map to select a location',
                                  color: kBlack,
                                  weight: FontWeight.w500,
                                  align: TextAlign.left,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    if (hasSelection) ...[
                      const SizedBox(height: 6),
                      AppText.caption(
                        '${_selected.latitude.toStringAsFixed(7)},'
                        '${_selected.longitude.toStringAsFixed(7)}',
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppText.caption(
                      'Radius (meters) *',
                      color: kBlack,
                      weight: FontWeight.w500,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _radiusStepButton(
                          icon: Icons.remove,
                          onTap: () => _adjustRadius(-_radiusStepMeters),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomTextField(
                            controller: _radiusController,
                            hintText: '250',
                            haveLebelText: false,
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
                        ),
                        const SizedBox(width: 10),
                        _radiusStepButton(
                          icon: Icons.add,
                          onTap: () => _adjustRadius(_radiusStepMeters),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MyButton(
                      buttonText: 'Use this location',
                      backgroundColor: kPrimaryColor,
                      isactive: hasSelection &&
                          !_resolving &&
                          !_importing &&
                          _radiusError == null,
                      onTap: () async => _confirm(),
                    ),
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
