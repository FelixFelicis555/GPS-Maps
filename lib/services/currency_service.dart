import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Rates {
  /// Units of each currency per 1 USD.
  final Map<String, double> perUsd;
  final DateTime updated;
  final bool fromCache;
  const Rates(this.perUsd, this.updated, {this.fromCache = false});

  double convert(double amount, String from, String to) =>
      amount / perUsd[from]! * perUsd[to]!;
}

class CurrencyService {
  static const _kRates = 'fx_rates_v1';

  /// Live rates from open.er-api.com (free, no key; attribution required).
  /// Falls back to the last cached rates when offline.
  static Future<Rates> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _read(prefs.getString(_kRates));
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.updated) < const Duration(hours: 6)) {
      return Rates(cached.perUsd, cached.updated, fromCache: true);
    }
    try {
      final res = await http
          .get(Uri.https('open.er-api.com', '/v6/latest/USD'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('http ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['result'] != 'success') throw Exception('bad result');
      final rates = (j['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
      final now = DateTime.now();
      await prefs.setString(
        _kRates,
        jsonEncode({'t': now.millisecondsSinceEpoch, 'rates': rates}),
      );
      return Rates(rates, now);
    } catch (_) {
      if (cached != null) {
        return Rates(cached.perUsd, cached.updated, fromCache: true);
      }
      rethrow;
    }
  }

  static Rates? _read(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return Rates(
        (j['rates'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  static const names = {
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'INR': 'Indian Rupee',
    'JPY': 'Japanese Yen',
    'AED': 'UAE Dirham',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'CHF': 'Swiss Franc',
    'CNY': 'Chinese Yuan',
    'SGD': 'Singapore Dollar',
    'HKD': 'Hong Kong Dollar',
    'NZD': 'New Zealand Dollar',
    'KRW': 'South Korean Won',
    'SEK': 'Swedish Krona',
    'NOK': 'Norwegian Krone',
    'DKK': 'Danish Krone',
    'MXN': 'Mexican Peso',
    'BRL': 'Brazilian Real',
    'ZAR': 'South African Rand',
    'RUB': 'Russian Ruble',
    'TRY': 'Turkish Lira',
    'SAR': 'Saudi Riyal',
    'QAR': 'Qatari Riyal',
    'KWD': 'Kuwaiti Dinar',
    'BHD': 'Bahraini Dinar',
    'OMR': 'Omani Rial',
    'THB': 'Thai Baht',
    'MYR': 'Malaysian Ringgit',
    'IDR': 'Indonesian Rupiah',
    'PHP': 'Philippine Peso',
    'VND': 'Vietnamese Dong',
    'PKR': 'Pakistani Rupee',
    'BDT': 'Bangladeshi Taka',
    'LKR': 'Sri Lankan Rupee',
    'NPR': 'Nepalese Rupee',
    'EGP': 'Egyptian Pound',
    'NGN': 'Nigerian Naira',
    'KES': 'Kenyan Shilling',
    'PLN': 'Polish Zloty',
    'CZK': 'Czech Koruna',
    'HUF': 'Hungarian Forint',
    'ILS': 'Israeli Shekel',
    'ARS': 'Argentine Peso',
    'CLP': 'Chilean Peso',
    'COP': 'Colombian Peso',
    'PEN': 'Peruvian Sol',
    'UAH': 'Ukrainian Hryvnia',
    'TWD': 'New Taiwan Dollar',
  };

  static String flag(String code) {
    if (code == 'EUR') return '🇪🇺';
    if (code.length != 3 || code.startsWith('X')) return '💱';
    final a = code.codeUnitAt(0) - 65 + 0x1F1E6;
    final b = code.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([a, b]);
  }
}
