import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps/screens/explore_screens.dart';
import 'package:gps/screens/map_screens.dart';
import 'package:gps/screens/tool_screens.dart';
import 'package:gps/screens/weather_screens.dart';

void main() {
  final screens = <String, Widget>{
    'address': const AddressFinderScreen(),
    'traffic': const TrafficScreen(),
    'location': const CurrentLocationScreen(),
    'routing': const RoutingScreen(),
    'compass': const CompassScreen(),
    'speedo': const SpeedometerScreen(),
    'sound': const SoundMeterScreen(),
    'currency': const CurrencyScreen(),
    'unit': const UnitConverterScreen(),
    'bill': const BillSplitterScreen(),
    'translator': const TranslatorScreen(),
    'clock': const WorldClockScreen(),
    'hourly': const HourlyScreen(),
    'weekly': const WeeklyScreen(),
    'daily': const DailyDetailScreen(title: 'Daily forecast'),
    'weekend': const WeekendScreen(),
    'historic': const HistoricScreen(),
    'exploreList': const ExploreListScreen(),
    'places': const PlacesScreen(category: 'Find restaurants'),
  };
  for (final e in screens.entries) {
    testWidgets('renders ${e.key}', (t) async {
      t.view.physicalSize = const Size(1080, 2280);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: e.value));
      await t.pump(const Duration(seconds: 1));
      expect(tester(t), isNull);
    });
  }
}

Object? tester(WidgetTester t) => t.takeException();
