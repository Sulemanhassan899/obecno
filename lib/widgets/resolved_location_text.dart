import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/main.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';
import 'package:Obecno/shared/location/service/reverse_geocoding_service.dart';

/// A widget that resolves a raw GPS coordinate or known-location string to a
/// human-readable label.
///
/// [onlyKnownLocations] – when `true`, reverse geocoding is skipped.  If the
/// coordinates do not match any known office the widget shows
/// "Not in office range" instead of fetching an external address.  Use this
/// for the attendance *card* and bottom-sheet *header* where you only want to
/// display office names.  Leave it `false` (the default) for timeline tiles
/// where the real geocoded address is desired.
class ResolvedLocationText extends StatefulWidget {
  const ResolvedLocationText({
    super.key,
    required this.rawLocation,
    required this.knownLocations,
    required this.builder,
    this.service,
    this.onlyKnownLocations = false,
  });

  final String? rawLocation;
  final List<KnownLocation> knownLocations;
  final Widget Function(BuildContext context, String text) builder;
  final ReverseGeocodingService? service;

  /// When true, skips reverse geocoding and shows "Not in office range" when
  /// the location coordinates don't match any known office.
  final bool onlyKnownLocations;

  @override
  State<ResolvedLocationText> createState() => _ResolvedLocationTextState();
}

class _ResolvedLocationTextState extends State<ResolvedLocationText> {
  late String _text;
  String? _resolvingFor;

  String get _notInOfficeRange {
    final locName = bindings.authProvider.selectedLocationName;
    if (locName.isEmpty) return "Not in office range";
    return "Not in $locName range";
  }

  @override
  void initState() {
    super.initState();
    _text = _resolveInitial();
    _maybeResolve();
  }

  @override
  void didUpdateWidget(covariant ResolvedLocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawLocation != widget.rawLocation ||
        oldWidget.onlyKnownLocations != widget.onlyKnownLocations) {
      _text = _resolveInitial();
      _maybeResolve();
    }
  }

  String _resolveInitial() {
    final resolved = AttendanceFormat.resolvedDisplayLocation(
      widget.rawLocation,
      widget.knownLocations,
    );
    // If not in any known office and caller wants known-locations-only mode,
    // show "Not in [selectedLocationName] range" immediately without waiting for geocoding.
    if (widget.onlyKnownLocations) {
      if (resolved == "Location unavailable") return _notInOfficeRange;
      final isKnown = widget.knownLocations.any((k) => k.name == resolved);
      if (!isKnown) return _notInOfficeRange;
    }
    return resolved;
  }

  void _maybeResolve() {
    // Never reverse-geocode when the caller wants known-locations-only output.
    if (widget.onlyKnownLocations) return;

    final raw = widget.rawLocation;
    if (raw == null || !AttendanceFormat.isRawCoordinates(raw)) return;
    if (_text != "Location unavailable") return;

    final point = GeoPoint.tryParse(raw);
    if (point == null) return;

    _resolvingFor = raw;
    final service = widget.service ?? ReverseGeocodingServiceImpl.instance;
    unawaited(
      service.resolve(lat: point.lat, lon: point.lon).then((resolved) {
        if (!mounted || _resolvingFor != raw) return;
        if (resolved == null || resolved.trim().isEmpty) return;
        setState(() => _text = resolved.trim());
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _text);
}
