import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class PlaceSuggestion {
  final String id, main, secondary;
  const PlaceSuggestion(this.id, this.main, this.secondary);
  String get label => secondary.isEmpty ? main : '$main, $secondary';
}

class PlaceDetails {
  final double lat, lng;
  final String label;
  const PlaceDetails(this.lat, this.lng, this.label);
}

/// Google Places autocomplete via the `search-place` Supabase function (the
/// Google key stays on the server). Everything returns empty/null on failure so
/// callers can fall back to a plain geocoder search.
class PlacesService {
  /// New random token for one typing session: reuse it for every autocomplete
  /// call and the details call that ends it (Google bills them as one).
  static String newSession() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static Future<Map<String, dynamic>?> post(Map<String, dynamic> body) async {
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
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<PlaceSuggestion>> autocomplete(
    String input,
    String session, {
    (double, double)? near,
  }) async {
    final j = await post({
      'op': 'autocomplete',
      'input': input,
      'token': session,
      if (near != null) 'near': {'lat': near.$1, 'lng': near.$2},
    });
    if (j == null) return const [];
    return [
      for (final s in (j['suggestions'] as List? ?? const []))
        PlaceSuggestion(
          s['id'] as String,
          s['main'] as String? ?? '',
          s['secondary'] as String? ?? '',
        ),
    ];
  }

  static Future<PlaceDetails?> details(
    PlaceSuggestion s,
    String session,
  ) async {
    final j = await post({'op': 'details', 'id': s.id, 'token': session});
    if (j == null) return null;
    return PlaceDetails(
      (j['lat'] as num).toDouble(),
      (j['lng'] as num).toDouble(),
      s.label,
    );
  }
}

/// One place from a nearby / text search.
class NearbyPlace {
  final String id, name, address;
  final double lat, lng;
  final double? rating;
  final int? ratings;
  final bool? open;

  /// Straight-line metres from the search point (filled in by the service).
  final double meters;
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.rating,
    this.ratings,
    this.open,
    this.meters = 0,
  });

  String get distance => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Google place types for each Explore category (the names used on the
/// Explore list and the home-screen tiles). Unknown names fall back to a text
/// search for that name.
const kCategoryTypes = <String, List<String>>{
  'gas': ['gas_station'],
  'gas stations': ['gas_station'],
  'bars': ['bar'],
  'cafe': ['cafe'],
  'cafes': ['cafe'],
  'hotel': ['hotel'],
  'parking': ['parking'],
  'restaurants': ['restaurant'],
  'find restaurants': ['restaurant'],
  'charging station': ['electric_vehicle_charging_station'],
  'bus station': ['bus_station'],
  'train station': ['train_station'],
  'shopping malls': ['shopping_mall'],
  'grocery': ['grocery_store', 'supermarket'],
  'groceries': ['grocery_store', 'supermarket'],
  'pharmacy': ['pharmacy'],
  'gym': ['gym', 'fitness_center'],
  'salons': ['beauty_salon', 'hair_salon', 'hair_care'],
  'hospital': ['hospital'],
  'atm': ['atm'],
};

class PlacesSearch {
  static List<NearbyPlace> _parse(
    Map<String, dynamic>? j,
    double lat,
    double lng,
  ) {
    final out = <NearbyPlace>[];
    for (final p in (j?['places'] as List? ?? const [])) {
      final plat = (p['lat'] as num).toDouble();
      final plng = (p['lng'] as num).toDouble();
      out.add(
        NearbyPlace(
          id: p['id'] as String? ?? '',
          name: p['name'] as String? ?? '',
          address: p['address'] as String? ?? '',
          lat: plat,
          lng: plng,
          rating: (p['rating'] as num?)?.toDouble(),
          ratings: (p['ratings'] as num?)?.toInt(),
          open: p['open'] as bool?,
          meters: Geolocator.distanceBetween(lat, lng, plat, plng),
        ),
      );
    }
    out.sort((a, b) => a.meters.compareTo(b.meters));
    return out;
  }

  /// Places of [category] near ([lat], [lng]); widens the radius once if the
  /// first search is empty. Throws [PlacesException] if the service fails.
  static Future<List<NearbyPlace>> forCategory(
    String category,
    double lat,
    double lng,
  ) async {
    final types = kCategoryTypes[category.trim().toLowerCase()];
    if (types == null) return search(category, lat, lng);
    var best = <NearbyPlace>[];
    for (final radius in const [5000, 25000]) {
      final j = await PlacesService.post({
        'op': 'nearby',
        'types': types,
        'near': {'lat': lat, 'lng': lng},
        'radius': radius,
      });
      if (j == null) throw const PlacesException();
      final r = _relevant(category, _parse(j, lat, lng));
      if (r.length > best.length) best = r;
      // Enough real businesses found: no need to search wider.
      if (r.length >= 5) return r;
    }
    return best;
  }

  /// Categories whose real places usually have no reviews (ATMs, car parks,
  /// stations, chargers): never filtered by review count.
  static const _noReviewFilter = {
    'atm',
    'parking',
    'bus station',
    'train station',
    'charging station',
  };

  /// Reviews a place needs before it counts as a real business; categories
  /// that attract junk listings (people, home addresses) need more.
  static int _minReviews(String category) {
    switch (category.trim().toLowerCase()) {
      case 'hospital':
      case 'pharmacy':
      case 'hotel':
        return 10;
      default:
        return 3;
    }
  }

  /// Drops obscure listings (no reviews, often just a person's name) when
  /// there are enough reviewed places to show instead.
  static List<NearbyPlace> _relevant(String category, List<NearbyPlace> all) {
    if (_noReviewFilter.contains(category.trim().toLowerCase())) return all;
    final min = _minReviews(category);
    final reviewed = all.where((p) => (p.ratings ?? 0) >= min).toList();
    return reviewed.length >= 3 ? reviewed : all;
  }

  static Future<List<NearbyPlace>> search(
    String query,
    double lat,
    double lng,
  ) async {
    final j = await PlacesService.post({
      'op': 'textsearch',
      'query': query,
      'near': {'lat': lat, 'lng': lng},
    });
    if (j == null) throw const PlacesException();
    return _parse(j, lat, lng);
  }
}

class PlacesException implements Exception {
  const PlacesException();
  @override
  String toString() => 'Could not load places.';
}
