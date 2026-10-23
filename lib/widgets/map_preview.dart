import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Compact, interactive Google Map for the home screen (pan, pinch-zoom, tap
/// the my-location button). It centres on the user only if location access is
/// already granted; it never shows a permission prompt itself.
class MapPreview extends StatefulWidget {
  const MapPreview({super.key});
  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  static const _fallback = LatLng(20.5937, 78.9629);
  GoogleMapController? _map;
  LatLng? _here;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() => _here = LatLng(p.latitude, p.longitude));
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_here!, 14));
    } catch (_) {}
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GoogleMap(
    initialCameraPosition: CameraPosition(
      target: _here ?? _fallback,
      zoom: _here == null ? 4 : 14,
    ),
    onMapCreated: (c) {
      _map = c;
      final here = _here;
      if (here != null) {
        c.animateCamera(CameraUpdate.newLatLngZoom(here, 14));
      }
    },
    myLocationEnabled: _here != null,
    myLocationButtonEnabled: _here != null,
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    compassEnabled: false,
    // The map sits inside a scrolling list: let it win drags and pinches.
    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    },
  );
}
