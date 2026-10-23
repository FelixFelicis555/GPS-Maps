import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Shared °C/°F toggle state.
final ValueNotifier<bool> useCelsius = ValueNotifier(true);

String fmtTemp(num c) =>
    useCelsius.value ? '${c.round()}°C' : '${(c * 9 / 5 + 32).round()}°F';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String fmtTime(DateTime? t) {
  if (t == null) return '--';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} '
      '${t.hour < 12 ? 'AM' : 'PM'}';
}

String _n(num? v, String unit, {int digits = 0}) =>
    v == null ? '--' : '${v.toStringAsFixed(digits)}$unit';

// ───────────────────────── Shared weather state ─────────────────────────

class WeatherState {
  final WeatherData? data;
  final String? error;
  final bool loading;
  const WeatherState({this.data, this.error, this.loading = false});
}

final ValueNotifier<WeatherState> weatherState = ValueNotifier(
  const WeatherState(),
);

Future<void> loadWeather() async {
  if (weatherState.value.loading) return;
  weatherState.value = WeatherState(
    data: weatherState.value.data,
    loading: true,
  );
  try {
    final p = await LocationService.current();
    final d = await WeatherService.forecast(p.latitude, p.longitude);
    weatherState.value = WeatherState(data: d);
  } on LocationException catch (e) {
    weatherState.value = WeatherState(error: e.message);
  } on WeatherException catch (e) {
    weatherState.value = WeatherState(error: e.message);
  } catch (_) {
    weatherState.value = const WeatherState(error: 'Could not load weather.');
  }
}

/// Builds [builder] once weather is loaded; otherwise shows progress / error.
/// Pass [scroll] when the placeholder sits inside a scrollable parent.
class WeatherGate extends StatefulWidget {
  final Widget Function(BuildContext, WeatherData) builder;
  final bool compact;
  const WeatherGate({super.key, required this.builder, this.compact = false});
  @override
  State<WeatherGate> createState() => _WeatherGateState();
}

class _WeatherGateState extends State<WeatherGate> {
  @override
  void initState() {
    super.initState();
    final s = weatherState.value;
    if (s.data == null && !s.loading) {
      Future.microtask(loadWeather);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<WeatherState>(
    valueListenable: weatherState,
    builder: (context, s, _) {
      final d = s.data;
      if (d != null) return widget.builder(context, d);
      final box = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: s.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(s.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadWeather,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      );
      return widget.compact ? box : Center(child: box);
    },
  );
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useCelsius,
    builder: (_, c, _) {
      Widget seg(String t, bool on) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: on ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : Colors.black,
          ),
        ),
      );
      return GestureDetector(
        onTap: () => useCelsius.value = !c,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [seg('°C', c), seg('°F', !c)]),
        ),
      );
    },
  );
}

List<Widget> _actions() => [
  const _UnitToggle(),
  IconButton(
    tooltip: 'Refresh',
    onPressed: loadWeather,
    icon: const Icon(Icons.refresh, color: kBlue),
  ),
];

// ───────────────────────── Home hero ─────────────────────────

class WeatherHero extends StatelessWidget {
  const WeatherHero({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        colors: [Color(0xFFBFE6FA), Color(0xFF4CC3C8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: WeatherGate(
      compact: true,
      builder: (_, d) => ValueListenableBuilder<bool>(
        valueListenable: useCelsius,
        builder: (_, _, _) {
          final c = d.current;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.city,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${_weekdays[c.time.weekday - 1]}, ${fmtDate(c.time)} · ${fmtTime(c.time)}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    fmtTemp(c.temp),
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(c.icon, size: 42, color: Colors.white),
                ],
              ),
              Text(
                c.description,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Feels Like ${c.feels == null ? '--' : fmtTemp(c.feels!)} | '
                'High ${c.high == null ? '--' : fmtTemp(c.high!)} | '
                'Low ${c.low == null ? '--' : fmtTemp(c.low!)}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 10),
              _SunRow(d.daily.first),
            ],
          );
        },
      ),
    ),
  );
}

/// Sunrise / sunset / daylight / UV for one day.
class _SunRow extends StatelessWidget {
  final Snapshot day;
  const _SunRow(this.day);
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, Color c, String l, String v) => Expanded(
      child: Column(
        children: [
          Icon(i, color: c, size: 28),
          Text(l, style: const TextStyle(fontSize: 10)),
          Text(
            v,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    String daylight() {
      if (day.sunrise == null || day.sunset == null) return '--';
      final m = day.sunset!.difference(day.sunrise!).inMinutes;
      return '${m ~/ 60}h ${m % 60}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: cardDecoration(radius: 12),
      child: Row(
        children: [
          item(
            Icons.wb_twilight,
            Colors.orange,
            'Sun rise',
            fmtTime(day.sunrise),
          ),
          item(
            Icons.wb_twilight,
            Colors.deepOrange,
            'Sun set',
            fmtTime(day.sunset),
          ),
          item(
            Icons.timelapse,
            const Color(0xFF1A3A6B),
            'Daylight',
            daylight(),
          ),
          item(
            Icons.wb_sunny,
            Colors.amber,
            'UV max',
            _n(day.uv, '', digits: 1),
          ),
        ],
      ),
    );
  }
}

class _SunPad extends StatelessWidget {
  final Snapshot day;
  const _SunPad(this.day);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: _SunRow(day),
  );
}

// ───────────────────────── Shared pieces ─────────────────────────

class _Banner extends StatelessWidget {
  final List<Color> colors;
  final Color iconColor;
  final String city;
  final Snapshot snap;
  final String when;
  const _Banner(
    this.colors,
    this.iconColor, {
    required this.city,
    required this.snap,
    required this.when,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 120,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      city,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9),
              ),
              const Spacer(),
              ValueListenableBuilder<bool>(
                valueListenable: useCelsius,
                builder: (_, _, _) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${fmtTemp(snap.temp)} | ${snap.description}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF14237A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(snap.icon, size: 70, color: iconColor),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _Metric(this.icon, this.color, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class MetricsGrid extends StatelessWidget {
  final Snapshot snap;
  const MetricsGrid(this.snap, {super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useCelsius,
    builder: (_, _, _) {
      final items = [
        (
          Icons.wb_cloudy_outlined,
          Colors.amber,
          'Real feel',
          snap.feels == null ? '--' : fmtTemp(snap.feels!),
        ),
        (
          Icons.water_drop,
          Colors.blue,
          'Dew Point',
          snap.dew == null ? '--' : fmtTemp(snap.dew!),
        ),
        (Icons.cloud, Colors.lightBlue, 'Cloud Cover', _n(snap.cloud, '%')),
        (Icons.wb_sunny, Colors.orange, 'UV Index', _n(snap.uv, '', digits: 1)),
        (Icons.thermostat, Colors.red, 'Pressure', _n(snap.pressure, ' hPa')),
        (Icons.water, Colors.blue, 'Humidity', _n(snap.humidity, '%')),
        (
          Icons.air,
          Colors.blueGrey,
          'Wind',
          _n(snap.windMs, ' m/s', digits: 1),
        ),
        (
          Icons.visibility,
          Colors.blueGrey,
          'Visibility',
          snap.visibilityM == null
              ? '--'
              : '${(snap.visibilityM! / 1000).toStringAsFixed(1)} km',
        ),
      ];
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: cardDecoration(radius: 14),
        clipBehavior: Clip.antiAlias,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: .85,
          children: [
            for (final m in items)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200, width: .5),
                ),
                child: _Metric(m.$1, m.$2, m.$3, m.$4),
              ),
          ],
        ),
      );
    },
  );
}

String _when(Snapshot s, {bool withTime = true}) =>
    '${_weekdays[s.time.weekday - 1]}, ${fmtDate(s.time)}'
    '${withTime ? ' · ${fmtTime(s.time)}' : ''}';

Snapshot _dayOf(WeatherData d, DateTime t) => d.daily.firstWhere(
  (x) =>
      x.time.year == t.year && x.time.month == t.month && x.time.day == t.day,
  orElse: () => d.daily.first,
);

// ───────────────────────── Detail ─────────────────────────

class DailyDetailScreen extends StatelessWidget {
  final String title;

  /// A specific hour/day; defaults to the current conditions.
  final Snapshot? snap;
  const DailyDetailScreen({super.key, required this.title, this.snap});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: title,
    actions: _actions(),
    body: WeatherGate(
      builder: (_, d) {
        final s = snap ?? d.current;
        final isDay = s.sunrise != null && s.high != null;
        return ListView(
          children: [
            _Banner(
              [const Color(0xFFBFE6FA), const Color(0xFFF2F7FF)],
              Colors.amber,
              city: d.city,
              snap: s,
              when: _when(s, withTime: !isDay),
            ),
            _SunPad(_dayOf(d, s.time)),
            MetricsGrid(s),
          ],
        );
      },
    ),
  );
}

class _ForecastCard extends StatelessWidget {
  final String label;
  final Snapshot snap;
  final Color dot;
  final VoidCallback onTap;
  const _ForecastCard(this.label, this.snap, this.dot, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmtTemp(snap.temp),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: dot,
                child: Icon(snap.icon, size: 16, color: Colors.black87),
              ),
            ],
          ),
          Text(
            snap.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          Text(
            'Wind: ${_n(snap.windMs, ' m/s', digits: 1)} · Hum: ${_n(snap.humidity, '%')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

Widget _cards(List<Widget> children) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.1,
    children: children,
  ),
);

class WeeklyScreen extends StatelessWidget {
  const WeeklyScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Daily forecast',
    actions: _actions(),
    body: WeatherGate(
      builder: (context, d) => ValueListenableBuilder<bool>(
        valueListenable: useCelsius,
        builder: (_, _, _) => ListView(
          children: [
            _Banner(
              [const Color(0xFFBFE6FA), const Color(0xFFF2F7FF)],
              Colors.amber,
              city: d.city,
              snap: d.current,
              when: _when(d.current),
            ),
            _cards([
              for (var i = 0; i < d.daily.length; i++)
                _ForecastCard(
                  i == 0
                      ? 'Today, ${fmtDate(d.daily[i].time)}'
                      : '${_weekdays[d.daily[i].time.weekday - 1]}, ${fmtDate(d.daily[i].time)}',
                  d.daily[i],
                  const Color(0xFFF9A32A),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => d.daily[i].time.weekday >= 6
                          ? WeekendScreen(initialDay: d.daily[i].time)
                          : DailyDetailScreen(
                              title: 'Daily forecast',
                              snap: d.daily[i],
                            ),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}

class HourlyScreen extends StatelessWidget {
  const HourlyScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Hourly forecast',
    actions: _actions(),
    body: WeatherGate(
      builder: (context, d) => ValueListenableBuilder<bool>(
        valueListenable: useCelsius,
        builder: (_, _, _) => ListView(
          children: [
            _Banner(
              [const Color(0xFFFFE08A), const Color(0xFFFFB74D)],
              Colors.amber,
              city: d.city,
              snap: d.current,
              when: _when(d.current),
            ),
            _cards([
              for (final h in d.hourly)
                _ForecastCard(
                  '${h.time.day == d.current.time.day ? '' : '${_weekdays[h.time.weekday - 1]} '}${fmtTime(h.time)}',
                  h,
                  const Color(0xFFF7C948),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DailyDetailScreen(title: 'Hourly forecast', snap: h),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── Weekend ─────────────────────────

class WeekendScreen extends StatefulWidget {
  final DateTime? initialDay;
  const WeekendScreen({super.key, this.initialDay});
  @override
  State<WeekendScreen> createState() => _WeekendScreenState();
}

class _WeekendScreenState extends State<WeekendScreen> {
  int day = 0;
  bool _init = false;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Weekend forecast',
    actions: _actions(),
    body: WeatherGate(
      builder: (_, d) {
        final days = d.daily.where((x) => x.time.weekday >= 6).toList();
        if (days.isEmpty) {
          return const Center(child: Text('No weekend in the forecast range.'));
        }
        if (!_init && widget.initialDay != null) {
          final i = days.indexWhere(
            (x) => x.time.day == widget.initialDay!.day,
          );
          if (i >= 0) day = i;
        }
        _init = true;
        if (day >= days.length) day = 0;
        final s = days[day];
        final rows = [
          (
            'Real Feel: ${s.feels == null ? '--' : fmtTemp(s.feels!)}',
            'High / Low: ${s.high == null ? '--' : fmtTemp(s.high!)} / ${s.low == null ? '--' : fmtTemp(s.low!)}',
          ),
          (
            'Wind: ${_n(s.windMs, ' m/s', digits: 1)}',
            'Max Wind Gusts: ${_n(s.gustMs, ' m/s', digits: 1)}',
          ),
          (
            'UV Index: ${_n(s.uv, '', digits: 1)}',
            'Humidity: ${_n(s.humidity, '%')}',
          ),
          (
            'Dew Point: ${s.dew == null ? '--' : fmtTemp(s.dew!)}',
            'Pressure: ${_n(s.pressure, ' hPa')}',
          ),
          (
            'Cloud Cover: ${_n(s.cloud, '%')}',
            'Visibility: ${s.visibilityM == null ? '--' : '${(s.visibilityM! / 1000).toStringAsFixed(1)} km'}',
          ),
        ];
        Widget chip(Snapshot x, int i) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => day = i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: day == i ? const Color(0xFF0B7BC4) : Colors.white,
                border: Border.all(color: Colors.black54),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_weekdays[x.time.weekday - 1]}, ${fmtDate(x.time)}',
                style: TextStyle(
                  fontSize: 12,
                  color: day == i ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
        return ValueListenableBuilder<bool>(
          valueListenable: useCelsius,
          builder: (_, _, _) => ListView(
            children: [
              _Banner(
                [const Color(0xFFBFE6FA), const Color(0xFFF2F7FF)],
                Colors.amber,
                city: d.city,
                snap: s,
                when: _when(s, withTime: false),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(8),
                decoration: cardDecoration(radius: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < days.length && i < 3; i++)
                          chip(days[i], i),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SunRow(s),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(10),
                decoration: cardDecoration(radius: 14),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.$1,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  r.$2,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ───────────────────────── Historic ─────────────────────────

class HistoricScreen extends StatefulWidget {
  const HistoricScreen({super.key});
  @override
  State<HistoricScreen> createState() => _HistoricScreenState();
}

class _HistoricScreenState extends State<HistoricScreen> {
  DateTime date = DateTime.now().subtract(const Duration(days: 30));
  Snapshot? result;
  String? error;
  bool loading = false;
  int _req = 0;

  String two(int n) => n.toString().padLeft(2, '0');

  Future<void> _load(WeatherData d) async {
    final req = ++_req;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await WeatherService.historic(d.lat, d.lng, date);
      if (mounted && req == _req) setState(() => result = r);
    } on WeatherException catch (e) {
      if (mounted && req == _req) setState(() => error = e.message);
    } finally {
      if (mounted && req == _req) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, String value, {VoidCallback? onTap}) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8902B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AppScaffold(
      title: 'Historic forecast',
      actions: _actions(),
      body: WeatherGate(
        builder: (context, d) {
          if (result == null && !loading && error == null) {
            Future.microtask(() => _load(d));
          }
          final r = result;
          return ValueListenableBuilder<bool>(
            valueListenable: useCelsius,
            builder: (_, _, _) => ListView(
              children: [
                if (r != null) ...[
                  _Banner(
                    [const Color(0xFF8E7FE0), const Color(0xFF5C4CC0)],
                    Colors.white,
                    city: d.city,
                    snap: r,
                    when: _when(r, withTime: false),
                  ),
                  _SunPad(r),
                ],
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: cardDecoration(radius: 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          pill('City', d.city),
                          pill(
                            'Date',
                            '${two(date.day)}/${two(date.month)}/${date.year}',
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now().subtract(
                                  const Duration(days: 5),
                                ),
                              );
                              if (picked != null) {
                                date = picked;
                                _load(d);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(error!),
                              TextButton(
                                onPressed: () => _load(d),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (r != null)
                        MetricsGrid(r),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
