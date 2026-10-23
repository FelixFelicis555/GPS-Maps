import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ads/ad_service.dart';
import '../config.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../utils/share.dart';

class _RoundedMap extends StatelessWidget {
  final Widget child;
  const _RoundedMap({required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
  );
}

/// Error panel with retry (and a Settings shortcut when permission is blocked).
class _LocationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LocationError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(
            onPressed: Geolocator.openAppSettings,
            child: const Text('Open settings'),
          ),
        ],
      ),
    ),
  );
}

const _fallbackCenter = LatLng(20.5937, 78.9629);

/// Shared by screens that need the user's position.
mixin _UserLocation<T extends StatefulWidget> on State<T> {
  Position? position;
  String? locationError;
  bool locating = true;

  Future<void> locate() async {
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      setState(() => position = p);
      onLocated(p);
    } on LocationException catch (e) {
      if (mounted) setState(() => locationError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => locationError = 'Could not get your location.');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void onLocated(Position p) {}
  LatLng get here => LatLng(position!.latitude, position!.longitude);
}

// ---------------------------------------------------------------- Address

class AddressFinderScreen extends StatefulWidget {
  const AddressFinderScreen({super.key});
  @override
  State<AddressFinderScreen> createState() => _AddressFinderScreenState();
}

class _AddressFinderScreenState extends State<AddressFinderScreen>
    with _UserLocation {
  final _search = TextEditingController();
  GoogleMapController? _map;
  LatLng? _picked;
  String? _address;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    locate();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void onLocated(Position p) =>
      _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 15));

  Future<void> _pick(LatLng l, {String? address}) async {
    setState(() {
      _picked = l;
      _address = address ?? 'Looking up address…';
    });
    _map?.animateCamera(CameraUpdate.newLatLngZoom(l, 16));
    final a =
        address ?? await LocationService.addressOf(l.latitude, l.longitude);
    if (mounted && _picked == l) setState(() => _address = a);
  }

  Future<void> _submit(String q) async {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await LocationService.search(q);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No results found')));
      return;
    }
    _pick(LatLng(r.$1, r.$2), address: r.$3);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Address finder',
    showAd: false,
    showBanner: true,
    body: _RoundedMap(
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _fallbackCenter,
                zoom: 4,
              ),
              onMapCreated: (c) {
                _map = c;
                if (position != null) onLocated(position!);
              },
              myLocationEnabled: position != null,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: {
                if (_picked != null)
                  Marker(
                    markerId: const MarkerId('picked'),
                    position: _picked!,
                  ),
              },
              onTap: (l) => _pick(l),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Search for place or address',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _submit(_search.text),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (_picked != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(radius: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _address ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: kBlue),
                      onPressed: () => guardedShare(
                        ShareParams(
                          text:
                              '${_address ?? ''}\nhttps://maps.google.com/?q=${_picked!.latitude},${_picked!.longitude}',
                        ),
                      ),
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

// ---------------------------------------------------------------- Traffic

/// Zoom in / out buttons (the map's built-in controls only exist on Android;
/// pinch-to-zoom works everywhere).
class _ZoomButtons extends StatelessWidget {
  final GoogleMapController? Function() controller;
  const _ZoomButtons({required this.controller});

  Widget _btn(IconData icon, String tip, CameraUpdate Function() update) =>
      Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tip,
          icon: Icon(icon, color: Colors.black87),
          onPressed: () => controller()?.animateCamera(update()),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _btn(Icons.add, 'Zoom in', CameraUpdate.zoomIn),
      const SizedBox(height: 8),
      _btn(Icons.remove, 'Zoom out', CameraUpdate.zoomOut),
    ],
  );
}

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});
  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> with _UserLocation {
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    locate();
  }

  @override
  void onLocated(Position p) =>
      _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 13));

  @override
  Widget build(BuildContext context) {
    Widget chip(String t, Color c) => Expanded(
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return AppScaffold(
      title: 'Traffic updates',
      showAd: false,
      showBanner: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: _fallbackCenter,
                          zoom: 4,
                        ),
                        onMapCreated: (c) {
                          _map = c;
                          if (position != null) onLocated(position!);
                        },
                        trafficEnabled: true,
                        myLocationEnabled: position != null,
                        myLocationButtonEnabled: true,
                        zoomGesturesEnabled: true,
                        zoomControlsEnabled: false,
                      ),
                      // Mid-right keeps clear of the map's own my-location button
                      // (bottom-right on iOS, top-right on Android).
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _ZoomButtons(controller: () => _map),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          chip('Low Traffic', const Color(0xFF3CC85A)),
                          chip('Medium Traffic', const Color(0xFFFF9800)),
                        ],
                      ),
                      Row(
                        children: [
                          chip('Heavy traffic', const Color(0xFFE53935)),
                          chip('Severe traffic', const Color(0xFF8E1B24)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- Current location

class CurrentLocationScreen extends StatefulWidget {
  const CurrentLocationScreen({super.key});
  @override
  State<CurrentLocationScreen> createState() => _CurrentLocationScreenState();
}

class _CurrentLocationScreenState extends State<CurrentLocationScreen>
    with _UserLocation {
  GoogleMapController? _map;
  String _address = 'Locating…';

  @override
  void initState() {
    super.initState();
    locate();
  }

  @override
  void onLocated(Position p) {
    _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 16));
    LocationService.addressOf(p.latitude, p.longitude).then((a) {
      if (mounted) setState(() => _address = a);
    });
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Current location',
    showAd: false,
    showBanner: true,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: locationError != null
            ? _LocationError(message: locationError!, onRetry: locate)
            : Column(
                children: [
                  Expanded(
                    child: position == null
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: here,
                              zoom: 16,
                            ),
                            onMapCreated: (c) => _map = c,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: false,
                            markers: {
                              Marker(
                                markerId: const MarkerId('me'),
                                position: here,
                              ),
                            },
                          ),
                  ),
                  LocationInfo(
                    address: _address,
                    lat: position?.latitude ?? 0,
                    lng: position?.longitude ?? 0,
                  ),
                ],
              ),
      ),
    ),
  );
}

/// Address + lat/lng + Copy/Share, reused by Compass.
class LocationInfo extends StatelessWidget {
  final String address;
  final double lat, lng;
  const LocationInfo({
    super.key,
    required this.address,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final text = '$address\nLat: $lat, Lng: $lng';
    Widget btn(String t, VoidCallback f) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: f,
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
    void copy(String msg) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current location:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(address, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.black87),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Latitude: $lat',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.black87),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Longitude: $lng',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black87),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                btn('Copy', () => copy('Copied')),
                const SizedBox(width: 16),
                btn('Share', () => guardedShare(ShareParams(text: text))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Routing

class _RouteResult {
  final List<LatLng> points;
  final String duration, distance;
  const _RouteResult(this.points, this.duration, this.distance);
}

List<LatLng> _decodePolyline(String enc) {
  final out = <LatLng>[];
  int i = 0, lat = 0, lng = 0;
  int next() {
    int shift = 0, result = 0, b;
    do {
      b = enc.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (i < enc.length) {
    lat += next();
    lng += next();
    out.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return out;
}

class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key});
  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> with _UserLocation {
  int mode = 0;
  // (icon, Routes API travelMode)
  static const modes = [
    (Icons.directions_car, 'DRIVE'),
    (Icons.two_wheeler, 'TWO_WHEELER'),
    (Icons.directions_bus, 'TRANSIT'),
    (Icons.directions_walk, 'WALK'),
  ];

  final _dest = TextEditingController();
  final _origin = TextEditingController();
  GoogleMapController? _map;
  LatLng? _destination;

  /// Typed start point; null means "use my current location".
  LatLng? _originPoint;
  List<PlaceSuggestion> _sugs = const [];
  bool _sugForOrigin = false;
  String _session = PlacesService.newSession();
  Timer? _deb;
  final Map<int, _RouteResult?> _routes = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    locate();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _dest.dispose();
    _origin.dispose();
    super.dispose();
  }

  @override
  void onLocated(Position p) =>
      _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 14));

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  (double, double)? get _near =>
      position == null ? null : (position!.latitude, position!.longitude);

  /// Where the route starts: the typed start point, else the user's location.
  LatLng? get _from => _originPoint ?? (position == null ? null : here);

  void _recompute() {
    final d = _destination;
    if (d != null) _setDestinationLatLng(d);
  }

  /// Google Places suggestions while typing (debounced).
  void _onTyped(String v, {required bool origin}) {
    _deb?.cancel();
    final q = v.trim();
    if (origin && q.isEmpty && _originPoint != null) {
      setState(() {
        _originPoint = null;
        _sugs = const [];
      });
      _recompute();
      return;
    }
    if (q.length < 2) {
      if (_sugs.isNotEmpty) setState(() => _sugs = const []);
      return;
    }
    _deb = Timer(const Duration(milliseconds: 300), () async {
      final r = await PlacesService.autocomplete(q, _session, near: _near);
      if (!mounted) return;
      // Drop answers for text the user has since changed.
      if ((origin ? _origin : _dest).text.trim() != q) return;
      setState(() {
        _sugs = r;
        _sugForOrigin = origin;
      });
    });
  }

  Future<void> _pick(PlaceSuggestion s) async {
    final origin = _sugForOrigin;
    FocusScope.of(context).unfocus();
    setState(() => _sugs = const []);
    final d = await PlacesService.details(s, _session);
    _session = PlacesService.newSession();
    if (!mounted) return;
    if (d == null) return _toast('Could not load that place');
    final ll = LatLng(d.lat, d.lng);
    if (origin) {
      _origin.text = d.label;
      setState(() => _originPoint = ll);
      _map?.animateCamera(CameraUpdate.newLatLngZoom(ll, 14));
      _recompute();
    } else {
      _dest.text = d.label;
      _setDestinationLatLng(ll);
    }
  }

  /// Back to using the device location as the start point.
  void _useMyLocation() {
    _origin.clear();
    setState(() {
      _originPoint = null;
      _sugs = const [];
    });
    if (position != null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 14));
    }
    _recompute();
  }

  Future<void> _setOrigin(String q) async {
    if (q.trim().isEmpty) return _useMyLocation();
    FocusScope.of(context).unfocus();
    setState(() => _sugs = const []);
    final r = await LocationService.search(q, near: _near);
    if (!mounted) return;
    if (r == null) return _toast('Starting point not found');
    _origin.text = r.$3.isEmpty ? q : r.$3;
    setState(() => _originPoint = LatLng(r.$1, r.$2));
    _map?.animateCamera(CameraUpdate.newLatLngZoom(_originPoint!, 14));
    _recompute();
  }

  Future<void> _setDestination(String q) async {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _sugs = const []);
    final r = await LocationService.search(q, near: _near);
    if (!mounted) return;
    if (r == null) return _toast('Destination not found');
    _dest.text = r.$3.isEmpty ? q : r.$3;
    _setDestinationLatLng(LatLng(r.$1, r.$2));
  }

  Future<void> _setDestinationLatLng(LatLng d) async {
    final from = _from;
    if (from == null) {
      return _toast(locationError ?? 'Waiting for your location…');
    }
    setState(() {
      _destination = d;
      _loading = true;
      _routes.clear();
    });
    final results = await Future.wait([
      for (var i = 0; i < modes.length; i++) _fetch(from, d, modes[i].$2),
    ]);
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < results.length; i++) {
        _routes[i] = results[i];
      }
      _loading = false;
    });
    final r = _routes[mode];
    if (r == null) {
      _toast(
        routingConfigured
            ? 'No route found for this mode'
            : 'Routing is not configured (set SUPABASE_URL and SUPABASE_ANON_KEY)',
      );
    } else {
      _fit(r.points);
    }
  }

  Future<_RouteResult?> _fetch(LatLng a, LatLng b, String m) async {
    if (!routingConfigured) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$kSupabaseUrl/functions/v1/compute-route'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $kSupabaseAnonKey',
            },
            body: jsonEncode({
              'origin': {'lat': a.latitude, 'lng': a.longitude},
              'destination': {'lat': b.latitude, 'lng': b.longitude},
              'travelMode': m,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('compute-route $m: ${res.statusCode} ${res.body}');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final poly = j['polyline'] as String? ?? '';
      if (poly.isEmpty) return null;
      return _RouteResult(
        _decodePolyline(poly),
        _formatDuration((j['durationSeconds'] as num).toInt()),
        _formatDistance((j['distanceMeters'] as num).toInt()),
      );
    } catch (e) {
      debugPrint('compute-route $m failed: $e');
      return null;
    }
  }

  static String _formatDuration(int secs) {
    final mins = (secs / 60).round();
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60} h ${mins % 60} min';
  }

  static String _formatDistance(int meters) =>
      meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km';

  void _fit(List<LatLng> pts) {
    if (pts.isEmpty) return;
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
        80,
      ),
    );
  }

  Future<void> _navigate() async {
    final d = _destination;
    if (d == null) return _toast('Choose a destination first');
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${d.latitude},${d.longitude}',
      'travelmode': const [
        'driving',
        'two-wheeler',
        'transit',
        'walking',
      ][mode],
    });
    if (!await AdService.instance.guard(
          () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ) &&
        mounted) {
      _toast('Could not open Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _routes[mode];
    return AppScaffold(
      title: 'Routing',
      showAd: false,
      showBanner: true,
      body: _RoundedMap(
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _fallbackCenter,
                  zoom: 4,
                ),
                onMapCreated: (c) {
                  _map = c;
                  if (position != null) onLocated(position!);
                },
                myLocationEnabled: position != null,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onLongPress: (l) {
                  _dest.text =
                      '${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}';
                  _setDestinationLatLng(l);
                },
                markers: {
                  if (_originPoint != null)
                    Marker(
                      markerId: const MarkerId('origin'),
                      position: _originPoint!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                  if (_destination != null)
                    Marker(
                      markerId: const MarkerId('dest'),
                      position: _destination!,
                    ),
                },
                polylines: {
                  if (route != null)
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: route.points,
                      color: kBlue,
                      width: 6,
                    ),
                },
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(radius: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(
                      Icons.circle,
                      Colors.green,
                      locating
                          ? 'Locating…'
                          : (position != null
                                ? 'Your location'
                                : 'Starting point'),
                      controller: _origin,
                      onChanged: (v) => _onTyped(v, origin: true),
                      onSubmitted: _setOrigin,
                      onTrailing: locationError != null && _originPoint == null
                          ? locate
                          : _useMyLocation,
                      trailing: locationError != null && _originPoint == null
                          ? Icons.refresh
                          : Icons.my_location,
                    ),
                    if (_sugs.isNotEmpty && _sugForOrigin) _suggestions(),
                    const SizedBox(height: 8),
                    _field(
                      Icons.location_on,
                      Colors.red,
                      'Destination (or long-press map)',
                      controller: _dest,
                      onChanged: (v) => _onTyped(v, origin: false),
                      onSubmitted: _setDestination,
                      trailing: Icons.search,
                      onTrailing: () => _setDestination(_dest.text),
                    ),
                    if (_sugs.isNotEmpty && !_sugForOrigin) _suggestions(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < modes.length; i++)
                          GestureDetector(
                            onTap: () {
                              setState(() => mode = i);
                              final r = _routes[i];
                              if (r != null) _fit(r.points);
                            },
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: mode == i
                                      ? kBlue
                                      : Colors.white,
                                  child: Icon(
                                    modes[i].$1,
                                    color: mode == i
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _loading
                                      ? '…'
                                      : (_routes[i]?.duration ?? '--'),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (route != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${route.distance} · ${route.duration}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        onPressed: _destination == null ? null : _navigate,
                        child: const Text(
                          'Navigate now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  Widget _suggestions() => Container(
    margin: const EdgeInsets.only(top: 4),
    constraints: const BoxConstraints(maxHeight: 220),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _sugs.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, i) {
        final x = _sugs[i];
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.place_outlined, size: 18),
          title: Text(
            x.main,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: x.secondary.isEmpty
              ? null
              : Text(
                  x.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
          onTap: () => _pick(x),
        );
      },
    ),
  );

  Widget _field(
    IconData i,
    Color c,
    String hint, {
    IconData? trailing,
    TextEditingController? controller,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    VoidCallback? onTrailing,
    bool enabled = true,
  }) => Row(
    children: [
      Icon(i, size: 14, color: c),
      const SizedBox(width: 10),
      Expanded(
        child: TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            suffixIcon: trailing == null
                ? null
                : IconButton(
                    icon: Icon(trailing, size: 16),
                    onPressed: onTrailing,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ),
    ],
  );
}
