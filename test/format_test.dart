import 'package:flutter_test/flutter_test.dart';
import 'package:gps/services/currency_service.dart';
import 'package:gps/utils/format.dart';

void main() {
  test('fmtNum groups and trims', () {
    expect(fmtNum(1234567.891, maxDecimals: 2), '1,234,567.89');
    expect(fmtNum(2.5000), '2.5');
    expect(fmtNum(0), '0');
    expect(fmtNum(-0.00001, maxDecimals: 2), '0');
    expect(fmtNum(-12.5), '-12.5');
    expect(fmtNum(double.nan), '--');
  });

  test('parseNum handles separators', () {
    expect(parseNum('12.5'), 12.5);
    expect(parseNum('1,234.5'), 1234.5);
    expect(parseNum('1,5'), 1.5);
    expect(parseNum('1,234'), 1234);
    expect(parseNum(''), isNull);
    expect(parseNum('abc'), isNull);
  });

  test('Rates.convert goes through USD', () {
    final r = Rates({'USD': 1, 'INR': 80, 'EUR': 0.8}, _t);
    expect(r.convert(10, 'USD', 'INR'), 800);
    expect(r.convert(80, 'INR', 'EUR'), closeTo(0.8, 1e-9));
  });

  test('currency flags', () {
    expect(CurrencyService.flag('INR'), '🇮🇳');
    expect(CurrencyService.flag('EUR'), '🇪🇺');
    expect(CurrencyService.flag('XAU'), '💱');
  });
}

final _t = DateTime(2026);
