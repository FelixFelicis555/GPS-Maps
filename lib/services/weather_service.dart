import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart';

/// One moment (current/hourly) or one day's summary of weather.
class Snapshot {
  final DateTime time;
  final int code;
  final double temp;
  final double? feels, dew, humidity, windMs, gustMs, pressure, cloud, uv;
  final double? visibilityM, high, low;
  final DateTime? sunrise, sunset;
  const Snapshot({
    required this.time,
    required this.code,
    required this.temp,
    this.feels,
    this.dew,
    this.humidity,
    this.windMs,
    this.gustMs,
    this.pressure,
    this.cloud,
    this.uv,
    this.visibilityM,
    this.high,
    this.low,
    this.sunrise,
    this.sunset,
  });

  String get description => describeCode(code).$1;
  IconData get icon => describeCode(code).$2;
}

class WeatherData {
  final String city;
  final double lat, lng;
  final Snapshot current;
  final List<Snapshot> hourly; // upcoming hours, starting now
  final List<Snapshot> daily; // today first
  const WeatherData({
    required this.city,
    required this.lat,
    required this.lng,
    required this.current,
    required this.hourly,
    required this.daily,
  });
}

/// WMO weather code -> (label, icon).
(String, IconData) describeCode(int c) {
  if (c == 0) return ('Clear sky', Icons.wb_sunny);
  if (c == 1) return ('Mainly clear', Icons.wb_sunny);
  if (c == 2) return ('Partly cloudy', Icons.wb_cloudy);
  if (c == 3) return ('Overcast', Icons.cloud);
  if (c == 45 || c == 48) return ('Fog', Icons.foggy);
  if (c >= 51 && c <= 57) return ('Drizzle', Icons.grain);
  if (c >= 61 && c <= 67) return ('Rain', Icons.water_drop);
  if (c >= 71 && c <= 77) return ('Snow', Icons.ac_unit);
  if (c >= 80 && c <= 82) return ('Rain showers', Icons.beach_access);
  if (c == 85 || c == 86) return ('Snow showers', Icons.ac_unit);
  if (c >= 95) return ('Thunderstorm', Icons.thunderstorm);
  return ('Unknown', Icons.cloud_queue);
}

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
  @override
  String toString() => message;
}

class WeatherService {
  static const _cur =
      'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,'
      'wind_speed_10m,wind_gusts_10m,pressure_msl,cloud_cover,dew_point_2m,'
      'visibility,uv_index';
  static const _hourly =
      'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,'
      'wind_speed_10m,wind_gusts_10m,pressure_msl,cloud_cover,dew_point_2m,'
      'visibility,uv_index';
  static const _daily =
      'weather_code,temperature_2m_max,temperature_2m_min,'
      'apparent_temperature_max,sunrise,sunset,uv_index_max,'
      'wind_speed_10m_max,wind_gusts_10m_max,relative_humidity_2m_mean,'
      'dew_point_2m_mean,pressure_msl_mean,cloud_cover_mean,visibility_mean';

  static Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw const WeatherException('Weather service is unavailable.');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(
        'Could not load weather. Check your connection.',
      );
    }
  }

  static double? _d(List? l, int i) =>
      (l == null || i >= l.length) ? null : (l[i] as num?)?.toDouble();
  static DateTime? _t(List? l, int i) =>
      (l == null || i >= l.length || l[i] == null)
      ? null
      : DateTime.parse(l[i]);

  static Future<WeatherData> forecast(double lat, double lng) async {
    final j = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'current': _cur,
        'hourly': _hourly,
        'daily': _daily,
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
        'forecast_days': '8',
      }),
    );
    final c = j['current'] as Map<String, dynamic>;
    final h = j['hourly'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final now = DateTime.parse(c['time']);

    final daily = <Snapshot>[
      for (var i = 0; i < (d['time'] as List).length; i++) _daySnap(d, i),
    ];
    final hourly = <Snapshot>[];
    final ht = h['time'] as List;
    for (var i = 0; i < ht.length && hourly.length < 24; i++) {
      final t = DateTime.parse(ht[i]);
      if (t.isBefore(DateTime(now.year, now.month, now.day, now.hour))) {
        continue;
      }
      hourly.add(
        Snapshot(
          time: t,
          code: (h['weather_code'][i] as num?)?.toInt() ?? 0,
          temp: _d(h['temperature_2m'], i) ?? 0,
          feels: _d(h['apparent_temperature'], i),
          dew: _d(h['dew_point_2m'], i),
          humidity: _d(h['relative_humidity_2m'], i),
          windMs: _d(h['wind_speed_10m'], i),
          gustMs: _d(h['wind_gusts_10m'], i),
          pressure: _d(h['pressure_msl'], i),
          cloud: _d(h['cloud_cover'], i),
          uv: _d(h['uv_index'], i),
          visibilityM: _d(h['visibility'], i),
        ),
      );
    }
    final today = daily.first;
    final current = Snapshot(
      time: now,
      code: (c['weather_code'] as num).toInt(),
      temp: (c['temperature_2m'] as num).toDouble(),
      feels: (c['apparent_temperature'] as num?)?.toDouble(),
      dew: (c['dew_point_2m'] as num?)?.toDouble(),
      humidity: (c['relative_humidity_2m'] as num?)?.toDouble(),
      windMs: (c['wind_speed_10m'] as num?)?.toDouble(),
      gustMs: (c['wind_gusts_10m'] as num?)?.toDouble(),
      pressure: (c['pressure_msl'] as num?)?.toDouble(),
      cloud: (c['cloud_cover'] as num?)?.toDouble(),
      uv: (c['uv_index'] as num?)?.toDouble(),
      visibilityM: (c['visibility'] as num?)?.toDouble(),
      high: today.high,
      low: today.low,
      sunrise: today.sunrise,
      sunset: today.sunset,
    );
    return WeatherData(
      city: await LocationService.cityOf(lat, lng),
      lat: lat,
      lng: lng,
      current: current,
      hourly: hourly,
      daily: daily,
    );
  }

  static Snapshot _daySnap(Map<String, dynamic> d, int i) => Snapshot(
    time: DateTime.parse(d['time'][i]),
    code: (d['weather_code'][i] as num?)?.toInt() ?? 0,
    temp: _d(d['temperature_2m_max'], i) ?? 0,
    high: _d(d['temperature_2m_max'], i),
    low: _d(d['temperature_2m_min'], i),
    feels: _d(d['apparent_temperature_max'], i),
    dew: _d(d['dew_point_2m_mean'], i),
    humidity: _d(d['relative_humidity_2m_mean'], i),
    windMs: _d(d['wind_speed_10m_max'], i),
    gustMs: _d(d['wind_gusts_10m_max'], i),
    pressure: _d(d['pressure_msl_mean'], i),
    cloud: _d(d['cloud_cover_mean'], i),
    uv: _d(d['uv_index_max'], i),
    visibilityM: _d(d['visibility_mean'], i),
    sunrise: _t(d['sunrise'], i),
    sunset: _t(d['sunset'], i),
  );

  /// Past day (ERA5 archive). Some fields (UV, visibility) are not archived.
  static Future<Snapshot> historic(double lat, double lng, DateTime day) async {
    final s =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final j = await _get(
      Uri.https('archive-api.open-meteo.com', '/v1/archive', {
        'latitude': '$lat',
        'longitude': '$lng',
        'start_date': s,
        'end_date': s,
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'apparent_temperature_max,sunrise,sunset,wind_speed_10m_max,'
            'wind_gusts_10m_max,relative_humidity_2m_mean,dew_point_2m_mean,'
            'pressure_msl_mean,cloud_cover_mean',
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
      }),
    );
    final d = j['daily'] as Map<String, dynamic>;
    if ((d['time'] as List).isEmpty) {
      throw const WeatherException('No data for that date.');
    }
    return _daySnap(d, 0);
  }
}
