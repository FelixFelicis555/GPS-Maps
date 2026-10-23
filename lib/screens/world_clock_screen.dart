import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../theme.dart';
import '../widgets/common.dart';

class _City {
  final String name, country, zone, flag;
  const _City(this.name, this.country, this.zone, this.flag);
}

const _cities = <_City>[
  _City('New York', 'United States', 'America/New_York', '🇺🇸'),
  _City('Los Angeles', 'United States', 'America/Los_Angeles', '🇺🇸'),
  _City('Chicago', 'United States', 'America/Chicago', '🇺🇸'),
  _City('Denver', 'United States', 'America/Denver', '🇺🇸'),
  _City('Anchorage', 'United States', 'America/Anchorage', '🇺🇸'),
  _City('Honolulu', 'United States', 'Pacific/Honolulu', '🇺🇸'),
  _City('Toronto', 'Canada', 'America/Toronto', '🇨🇦'),
  _City('Vancouver', 'Canada', 'America/Vancouver', '🇨🇦'),
  _City('Mexico City', 'Mexico', 'America/Mexico_City', '🇲🇽'),
  _City('Bogotá', 'Colombia', 'America/Bogota', '🇨🇴'),
  _City('Lima', 'Peru', 'America/Lima', '🇵🇪'),
  _City('Santiago', 'Chile', 'America/Santiago', '🇨🇱'),
  _City('Buenos Aires', 'Argentina', 'America/Argentina/Buenos_Aires', '🇦🇷'),
  _City('São Paulo', 'Brazil', 'America/Sao_Paulo', '🇧🇷'),
  _City('Reykjavik', 'Iceland', 'Atlantic/Reykjavik', '🇮🇸'),
  _City('London', 'United Kingdom', 'Europe/London', '🇬🇧'),
  _City('Dublin', 'Ireland', 'Europe/Dublin', '🇮🇪'),
  _City('Lisbon', 'Portugal', 'Europe/Lisbon', '🇵🇹'),
  _City('Paris', 'France', 'Europe/Paris', '🇫🇷'),
  _City('Madrid', 'Spain', 'Europe/Madrid', '🇪🇸'),
  _City('Berlin', 'Germany', 'Europe/Berlin', '🇩🇪'),
  _City('Rome', 'Italy', 'Europe/Rome', '🇮🇹'),
  _City('Amsterdam', 'Netherlands', 'Europe/Amsterdam', '🇳🇱'),
  _City('Zurich', 'Switzerland', 'Europe/Zurich', '🇨🇭'),
  _City('Stockholm', 'Sweden', 'Europe/Stockholm', '🇸🇪'),
  _City('Warsaw', 'Poland', 'Europe/Warsaw', '🇵🇱'),
  _City('Athens', 'Greece', 'Europe/Athens', '🇬🇷'),
  _City('Istanbul', 'Türkiye', 'Europe/Istanbul', '🇹🇷'),
  _City('Moscow', 'Russia', 'Europe/Moscow', '🇷🇺'),
  _City('Cairo', 'Egypt', 'Africa/Cairo', '🇪🇬'),
  _City('Lagos', 'Nigeria', 'Africa/Lagos', '🇳🇬'),
  _City('Nairobi', 'Kenya', 'Africa/Nairobi', '🇰🇪'),
  _City('Johannesburg', 'South Africa', 'Africa/Johannesburg', '🇿🇦'),
  _City('Riyadh', 'Saudi Arabia', 'Asia/Riyadh', '🇸🇦'),
  _City('Dubai', 'United Arab Emirates', 'Asia/Dubai', '🇦🇪'),
  _City('Tehran', 'Iran', 'Asia/Tehran', '🇮🇷'),
  _City('Karachi', 'Pakistan', 'Asia/Karachi', '🇵🇰'),
  _City('Hyderabad', 'India', 'Asia/Kolkata', '🇮🇳'),
  _City('Mumbai', 'India', 'Asia/Kolkata', '🇮🇳'),
  _City('Delhi', 'India', 'Asia/Kolkata', '🇮🇳'),
  _City('Kathmandu', 'Nepal', 'Asia/Kathmandu', '🇳🇵'),
  _City('Dhaka', 'Bangladesh', 'Asia/Dhaka', '🇧🇩'),
  _City('Colombo', 'Sri Lanka', 'Asia/Colombo', '🇱🇰'),
  _City('Bangkok', 'Thailand', 'Asia/Bangkok', '🇹🇭'),
  _City('Jakarta', 'Indonesia', 'Asia/Jakarta', '🇮🇩'),
  _City('Singapore', 'Singapore', 'Asia/Singapore', '🇸🇬'),
  _City('Kuala Lumpur', 'Malaysia', 'Asia/Kuala_Lumpur', '🇲🇾'),
  _City('Hong Kong', 'Hong Kong', 'Asia/Hong_Kong', '🇭🇰'),
  _City('Shanghai', 'China', 'Asia/Shanghai', '🇨🇳'),
  _City('Manila', 'Philippines', 'Asia/Manila', '🇵🇭'),
  _City('Seoul', 'South Korea', 'Asia/Seoul', '🇰🇷'),
  _City('Tokyo', 'Japan', 'Asia/Tokyo', '🇯🇵'),
  _City('Perth', 'Australia', 'Australia/Perth', '🇦🇺'),
  _City('Sydney', 'Australia', 'Australia/Sydney', '🇦🇺'),
  _City('Auckland', 'New Zealand', 'Pacific/Auckland', '🇳🇿'),
];

const _defaults = [
  'New York',
  'London',
  'Dubai',
  'Singapore',
  'Tokyo',
  'Sydney',
];

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});
  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const months = [
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
  static bool _tzReady = false;

  late Timer timer;
  DateTime now = DateTime.now();

  /// When set, all clocks show this instant instead of the live time.
  DateTime? pinned;
  List<String> selected = [..._defaults];

  DateTime get ref => pinned ?? now;

  @override
  void initState() {
    super.initState();
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && pinned == null) setState(() => now = DateTime.now());
    });
    _restore();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('clock_cities');
      if (l != null && mounted) {
        setState(
          () => selected = l
              .where((n) => _cities.any((c) => c.name == n))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('clock_cities', selected);
    } catch (_) {}
  }

  tz.TZDateTime _at(_City c) => tz.TZDateTime.from(ref, tz.getLocation(c.zone));

  String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _date(DateTime t) =>
      '${days[t.weekday - 1]}, ${t.day} ${months[t.month - 1]}';

  String _diff(Duration d) {
    final m = d.inMinutes;
    if (m == 0) return 'Same time';
    final a = m.abs();
    final s = a % 60 == 0
        ? '${a ~/ 60}h'
        : (a < 60 ? '${a}m' : '${a ~/ 60}h ${a % 60}m');
    return '${m < 0 ? '-' : '+'}$s';
  }

  bool _isDay(DateTime t) => t.hour >= 6 && t.hour < 18;

  Future<void> _pickTime() async {
    final local = ref.toLocal();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
      helpText: 'Time at your location',
    );
    if (t == null) return;
    setState(
      () => pinned = DateTime(
        local.year,
        local.month,
        local.day,
        t.hour,
        t.minute,
      ),
    );
  }

  Future<void> _add() async {
    final c = await showModalBottomSheet<_City>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CityPicker(exclude: selected),
    );
    if (c == null) return;
    setState(() => selected.add(c.name));
    _save();
  }

  Widget _row(
    String city,
    String sub,
    String flag,
    DateTime t,
    Duration? diff, {
    bool primary = false,
    VoidCallback? onRemove,
  }) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: cardDecoration(
        color: primary ? const Color(0xFFF6E8F6) : Colors.white,
        radius: 14,
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (primary)
                  const Text('Your time', style: TextStyle(fontSize: 10)),
                Text(
                  city,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: primary ? 18 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          Icon(
            _isDay(t) ? Icons.wb_sunny : Icons.nightlight_round,
            color: _isDay(t) ? Colors.orange : Colors.purple.shade300,
            size: 22,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _time(t),
                    style: TextStyle(
                      fontSize: primary ? 20 : 16,
                      fontWeight: FontWeight.w800,
                      color: primary ? const Color(0xFF7B1E7A) : Colors.black,
                    ),
                  ),
                  Text(
                    _date(t),
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          if (diff != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E8F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _diff(diff),
                style: const TextStyle(fontSize: 10, color: Color(0xFF7B1E7A)),
              ),
            ),
          ],
        ],
      ),
    );
    if (onRemove == null) return card;
    return Dismissible(
      key: ValueKey(city),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.toLocal();
    final homeOffset = local.timeZoneOffset;
    final rows = <Widget>[];
    for (final n in selected) {
      final c = _cities.firstWhere((x) => x.name == n);
      final t = _at(c);
      rows.add(
        _row(
          c.name,
          '${c.country} (${t.timeZoneName})',
          c.flag,
          t,
          t.timeZoneOffset - homeOffset,
          onRemove: () {
            setState(() => selected.remove(n));
            _save();
          },
        ),
      );
    }
    return AppScaffold(
      title: 'World clock',
      actions: [
        IconButton(
          tooltip: 'Compare a time',
          icon: const Icon(Icons.schedule, color: kBlue),
          onPressed: _pickTime,
        ),
        IconButton(
          tooltip: 'Add city',
          icon: const Icon(Icons.add_location_alt_outlined, color: kBlue),
          onPressed: _add,
        ),
      ],
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ListView(
          children: [
            if (pinned != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4CC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comparing at ${_time(local)} your time',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        pinned = null;
                        now = DateTime.now();
                      }),
                      child: const Text('Back to now'),
                    ),
                  ],
                ),
              ),
            _row(
              'Local time',
              '${local.timeZoneName} · UTC${_utc(homeOffset)}',
              '📍',
              local,
              null,
              primary: true,
            ),
            ...rows,
            if (selected.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tap the + button to add cities.',
                  textAlign: TextAlign.center,
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Swipe a city left to remove it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _utc(Duration d) {
    final m = d.inMinutes;
    final a = m.abs();
    return '${m < 0 ? '-' : '+'}${(a ~/ 60).toString().padLeft(2, '0')}:${(a % 60).toString().padLeft(2, '0')}';
  }
}

class _CityPicker extends StatefulWidget {
  final List<String> exclude;
  const _CityPicker({required this.exclude});
  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = _cities.where((c) {
      if (widget.exclude.contains(c.name)) return false;
      final s = q.toLowerCase();
      return c.name.toLowerCase().contains(s) ||
          c.country.toLowerCase().contains(s);
    }).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'Search city or country',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Text(
                    list[i].flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(list[i].name),
                  subtitle: Text(list[i].country),
                  onTap: () => Navigator.pop(context, list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
