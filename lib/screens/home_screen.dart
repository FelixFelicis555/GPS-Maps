import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../ads/ad_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_preview.dart';
import 'explore_screens.dart';
import 'map_screens.dart';
import 'tool_screens.dart';
import 'weather_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  static const tabs = [
    ('assets/icons/maps.svg', 'Maps', Color(0xFFE8531F)),
    ('assets/icons/compass.svg', 'Travel tools', Color(0xFF2EA66B)),
    ('assets/icons/weather.svg', 'Weather', Color(0xFF4A6CF7)),
    ('assets/icons/explore_places.svg', 'Explore local', Color(0xFFF39C12)),
  ];

  void go(Widget w) => AdService.instance.showInterstitialThen(() {
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'GPS maps & navigation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => go(const TranslatorScreen()),
                  icon: SvgPicture.asset(
                    'assets/icons/change_language.svg',
                    width: 28,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: SvgPicture.asset(
                    'assets/icons/try_premium.svg',
                    width: 28,
                  ),
                ),
              ],
            ),
          ),
          _tabBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: [_maps, _travel, _weather, _explore][tab](),
            ),
          ),
          const AdCard(),
        ],
      ),
    ),
  );

  Widget _tabBar() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: cardDecoration(radius: 12),
    child: Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => tab = i),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      tabs[i].$1,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        tab == i ? tabs[i].$3 : Colors.grey.shade400,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: tab == i
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: tab == i ? Colors.black : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 52,
                      decoration: BoxDecoration(
                        color: tab == i ? tabs[i].$3 : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _grid(List<Widget> tiles) => GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.45,
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    children: tiles,
  );

  Widget _maps() => ListView(
    padding: EdgeInsets.zero,
    children: [
      SizedBox(
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              const Positioned.fill(child: MapPreview()),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => go(const RoutingScreen()),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Where to go?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          ToolTile(
            title: 'Routing',
            asset: 'assets/icons/routing.svg',
            onTap: () => go(const RoutingScreen()),
          ),
          ToolTile(
            title: 'Traffic updates',
            asset: 'assets/icons/traffic_updates.svg',
            onTap: () => go(const TrafficScreen()),
          ),
          ToolTile(
            title: 'Current location',
            asset: 'assets/icons/current_location.svg',
            onTap: () => go(const CurrentLocationScreen()),
          ),
          ToolTile(
            title: 'Address finder',
            asset: 'assets/icons/addres_finder.svg',
            onTap: () => go(const AddressFinderScreen()),
          ),
        ],
      ),
    ],
  );

  Widget _travel() => _grid([
    ToolTile(
      title: 'Compass',
      asset: 'assets/icons/compass-1.svg',
      onTap: () => go(const CompassScreen()),
    ),
    ToolTile(
      title: 'Speedometer',
      asset: 'assets/icons/speedometer.svg',
      onTap: () => go(const SpeedometerScreen()),
    ),
    ToolTile(
      title: 'Currency converter',
      asset: 'assets/icons/currency_converter.svg',
      onTap: () => go(const CurrencyScreen()),
    ),
    ToolTile(
      title: 'Unit converter',
      asset: 'assets/icons/unit_converter.svg',
      onTap: () => go(const UnitConverterScreen()),
    ),
    ToolTile(
      title: 'Bill splitter',
      asset: 'assets/icons/bill_spiliter.svg',
      onTap: () => go(const BillSplitterScreen()),
    ),
    ToolTile(
      title: 'Translator',
      asset: 'assets/icons/language_change.svg',
      onTap: () => go(const TranslatorScreen()),
    ),
    ToolTile(
      title: 'World clock',
      asset: 'assets/icons/world_clock.svg',
      onTap: () => go(const WorldClockScreen()),
    ),
    ToolTile(
      title: 'Sound meter',
      asset: 'assets/icons/sound_meter.svg',
      onTap: () => go(const SoundMeterScreen()),
    ),
  ]);

  Widget _weather() => ListView(
    padding: EdgeInsets.zero,
    children: [
      const WeatherHero(),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          ToolTile(
            chevron: true,
            title: 'Hourly weather',
            asset: 'assets/icons/hourly_weather.svg',
            onTap: () => go(const HourlyScreen()),
          ),
          ToolTile(
            chevron: true,
            title: 'Daily weather',
            asset: 'assets/icons/daily_weather.svg',
            onTap: () => go(const DailyDetailScreen(title: 'Daily forecast')),
          ),
          ToolTile(
            chevron: true,
            title: 'Weekly forecast',
            asset: 'assets/icons/weekly_weather.svg',
            onTap: () => go(const WeeklyScreen()),
          ),
          ToolTile(
            chevron: true,
            title: 'Historic forecast',
            asset: 'assets/icons/historic_forecast.svg',
            onTap: () => go(const HistoricScreen()),
          ),
        ],
      ),
    ],
  );

  Widget _explore() => ListView(
    padding: EdgeInsets.zero,
    children: [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: _exploreTiles(),
      ),
      TextButton(
        onPressed: () => go(const ExploreListScreen()),
        child: const Text('All categories'),
      ),
    ],
  );

  List<Widget> _exploreTiles() => [
    for (final c in const [
      ('Find restaurants', 'assets/icons/restaurants.svg'),
      ('Groceries', 'assets/icons/groceries.svg'),
      ('Gym', 'assets/icons/gym.svg'),
      ('Salons', 'assets/icons/saloon.svg'),
      ('Gas stations', 'assets/icons/gasolene.svg'),
      ('Cafes', 'assets/icons/cafes.svg'),
      ('Hospital', 'assets/icons/hospitals.svg'),
      ('ATM', ''),
    ])
      ToolTile(
        title: c.$1,
        asset: c.$2,
        onTap: () => go(PlacesScreen(category: c.$1)),
      ),
  ];
}
