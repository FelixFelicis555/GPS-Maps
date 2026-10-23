import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../ads/ad_service.dart';
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  final bool openSettings;
  const LocationException(this.message, {this.openSettings = false});
  @override
  String toString() => message;
}

class LocationService {
  static final _geo = Geocoding();

  /// Ensures services + permission are available, then returns the position.
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Location services are turned off.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await AdService.instance.guard(Geolocator.requestPermission);
    }
    if (perm == LocationPermission.denied) {
      throw const LocationException('Location permission was denied.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it in Settings.',
        openSettings: true,
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<String> addressOf(double lat, double lng) async {
    try {
      final p = (await _geo.placemarkFromCoordinates(lat, lng)).first;
      final parts = [
        p.street,
        p.locality,
        p.administrativeArea,
        p.country,
      ].whereType<String>().where((s) => s.isNotEmpty);
      return parts.join(', ');
    } catch (_) {
      return 'Address unavailable';
    }
  }

  static Future<String> cityOf(double lat, double lng) async {
    try {
      final p = (await _geo.placemarkFromCoordinates(lat, lng)).first;
      final parts = [
        p.locality,
        p.country,
      ].whereType<String>().where((s) => s.isNotEmpty);
      return parts.isEmpty ? 'Your location' : parts.join(', ');
    } catch (_) {
      return 'Your location';
    }
  }

  /// Google Places text search through the `search-place` Supabase function:
  /// finds businesses and landmarks ("AMB Cinemas"), not only street
  /// addresses. [near] biases results toward the user. Null on any failure.
  static Future<(double, double, String)?> _searchPlace(
    String query,
    (double, double)? near,
  ) async {
    if (!routingConfigured) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$kSupabaseUrl/functions/v1/search-place'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $kSupabaseAnonKey',
            },
            body: jsonEncode({
              'query': query,
              if (near != null) 'near': {'lat': near.$1, 'lng': near.$2},
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final name = j['name'] as String? ?? query;
      final address = j['address'] as String? ?? '';
      return (
        (j['lat'] as num).toDouble(),
        (j['lng'] as num).toDouble(),
        address.isEmpty ? name : '$name, $address',
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns null when nothing matches. Tries Google Places first (names and
  /// landmarks), then the device geocoder (street addresses).
  static Future<(double, double, String)?> search(
    String query, {
    (double, double)? near,
  }) async {
    final place = await _searchPlace(query, near);
    if (place != null) return place;
    try {
      final r = await _geo.locationFromAddress(query);
      if (r.isEmpty) return null;
      // Several places can share a name: prefer the one closest to the user.
      var l = r.first;
      if (near != null) {
        double d(Location x) => Geolocator.distanceBetween(
          near.$1,
          near.$2,
          x.latitude,
          x.longitude,
        );
        l = r.reduce((a, b) => d(a) <= d(b) ? a : b);
      }
      // Reverse-geocoding a point often names a neighbouring street or area, so
      // keep what the user typed at the front of the label.
      final address = await addressOf(l.latitude, l.longitude);
      final typed = query.trim();
      final label = address.toLowerCase().contains(typed.toLowerCase())
          ? address
          : '$typed, $address';
      return (l.latitude, l.longitude, label);
    } catch (_) {
      return null;
    }
  }
}
