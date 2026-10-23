import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ads/ad_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../widgets/common.dart';

class ExploreListScreen extends StatefulWidget {
  const ExploreListScreen({super.key});
  @override
  State<ExploreListScreen> createState() => _ExploreListScreenState();
}

class _ExploreListScreenState extends State<ExploreListScreen> {
  static const cats = [
    ('Gas', Icons.local_gas_station, Color(0xFF5B0F1A)),
    ('Bars', Icons.local_bar, Color(0xFF2A7B8C)),
    ('Cafe', Icons.local_cafe, Color(0xFFCB6B6B)),
    ('Hotel', Icons.apartment, Color(0xFF0F3B3A)),
    ('Parking', Icons.local_parking, Color(0xFFF7941D)),
    ('Restaurants', Icons.restaurant, Color(0xFF8E1B24)),
    ('Charging Station', Icons.ev_station, Color(0xFF6B6B4F)),
    ('Bus Station', Icons.directions_bus, Color(0xFF2F4F66)),
    ('Train Station', Icons.train, Color(0xFF2F5C9B)),
    ('Shopping Malls', Icons.shopping_bag, Color(0xFFE0603E)),
    ('Grocery', Icons.shopping_basket, Color(0xFF1F9A8A)),
    ('Pharmacy', Icons.local_pharmacy, Color(0xFFC2185B)),
  ];
  String q = '';

  @override
  Widget build(BuildContext context) {
    final items = cats
        .where((c) => c.$1.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return AppScaffold(
      title: 'Explore local',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                if (v.trim().isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlacesScreen(category: v.trim()),
                  ),
                );
              },
              decoration: InputDecoration(
                hintText: 'Search here',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: items[i].$3,
                  child: Icon(items[i].$2, color: Colors.white, size: 20),
                ),
                title: Text(items[i].$1),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlacesScreen(category: items[i].$1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Real nearby places (Google Places via the `search-place` function) for a
/// category, or for any text typed in the Explore search box.
class PlacesScreen extends StatefulWidget {
  final String category;
  const PlacesScreen({super.key, required this.category});
  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  static const _sheetHeight = 340.0;

  GoogleMapController? _map;
  Position? _pos;
  List<NearbyPlace> _places = const [];
  bool _loading = true;
  String? _error;
  bool _openSettings = false;
  String? _selected;
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _openSettings = false;
    });
    try {
      final pos = _pos ?? await LocationService.current();
      if (!mounted) return;
      setState(() => _pos = pos);
      final r = await PlacesSearch.forCategory(
        widget.category,
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _places = r;
        _selected = null;
        _loading = false;
      });
      _fit();
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _openSettings = e.openSettings;
        _loading = false;
      });
    } on PlacesException {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load places. Check your connection and try again.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Try again.';
        _loading = false;
      });
    }
  }

  /// Frames the user and the results (the sheet covers the map's lower part,
  /// which the map's own padding accounts for).
  void _fit() {
    final pos = _pos;
    final map = _map;
    if (pos == null || map == null) return;
    var s = pos.latitude, n = s, w = pos.longitude, e = w;
    for (final p in _places.take(10)) {
      if (p.lat < s) s = p.lat;
      if (p.lat > n) n = p.lat;
      if (p.lng < w) w = p.lng;
      if (p.lng > e) e = p.lng;
    }
    if (s == n && w == e) {
      map.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
      return;
    }
    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
        60,
      ),
    );
  }

  void _select(NearbyPlace p, {bool pan = true}) {
    setState(() => _selected = p.id);
    if (pan) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lng), 16));
    }
    final ctx = _keys[p.id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: .1,
      );
    }
  }

  Future<void> _navigate(NearbyPlace p) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${p.lat},${p.lng}',
      if (p.id.isNotEmpty) 'destination_place_id': p.id,
    });
    final ok = await AdService.instance.guard(
      () => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category.replaceFirst('Find ', '');
    final pos = _pos;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: pos == null
                ? const MapPlaceholder(showPin: false, seed: 21)
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(pos.latitude, pos.longitude),
                      zoom: 14,
                    ),
                    onMapCreated: (c) {
                      _map = c;
                      _fit();
                    },
                    padding: const EdgeInsets.only(bottom: _sheetHeight),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    markers: {
                      for (final p in _places)
                        Marker(
                          markerId: MarkerId(p.id),
                          position: LatLng(p.lat, p.lng),
                          infoWindow: InfoWindow(title: p.name),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            p.id == _selected
                                ? BitmapDescriptor.hueAzure
                                : BitmapDescriptor.hueRed,
                          ),
                          onTap: () => _select(p, pan: false),
                        ),
                    },
                  ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 6),
                  ],
                ),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left, color: Colors.black),
                  label: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: _sheetHeight,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFEFF2),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: _sheetBody(),
                  ),
                  const AdCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.grey),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
              if (_openSettings)
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Open settings'),
                ),
            ],
          ),
        ),
      );
    }
    if (_places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No ${widget.category.toLowerCase()} found near you.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      children: [for (final p in _places) _card(p)],
    );
  }

  Widget _card(NearbyPlace p) {
    final selected = p.id == _selected;
    final key = _keys.putIfAbsent(p.id, GlobalKey.new);
    return GestureDetector(
      key: key,
      onTap: () => _select(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2327),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF4FC3F7) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.address.isNotEmpty)
                    Text(
                      p.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    children: [
                      Text(
                        p.distance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      if (p.rating != null)
                        Text(
                          '★ ${p.rating!.toStringAsFixed(1)}'
                          '${p.ratings == null ? '' : ' (${p.ratings})'}',
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 11,
                          ),
                        ),
                      if (p.open != null)
                        Text(
                          p.open! ? 'Open now' : 'Closed',
                          style: TextStyle(
                            color: p.open!
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFFEF5350),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _navigate(p),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.navigation,
                  size: 18,
                  color: Color(0xFFE8902B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
