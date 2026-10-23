import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ads/ad_service.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';
import 'map_screens.dart';

export 'bill_splitter_screen.dart';
export 'currency_screen.dart';
export 'translator_screen.dart';
export 'unit_converter_screen.dart';
export 'world_clock_screen.dart';

// ───────────────────────── Compass ─────────────────────────

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});
  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double? _heading;
  double? _lat, _lng;
  String _address = 'Locating…';
  String? _error;
  StreamSubscription<CompassEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen((e) {
      if (mounted && e.heading != null) setState(() => _heading = e.heading);
    });
    _locate();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _error = null);
    try {
      final p = await LocationService.current();
      final a = await LocationService.addressOf(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
        _address = a;
      });
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noSensor = FlutterCompass.events == null;
    return AppScaffold(
      title: 'Compass',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: const Color(0xFFFFF4E3),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        noSensor
                            ? 'No compass sensor on this device'
                            : (_heading == null
                                  ? 'Calibrating…'
                                  : '${_heading!.round() % 360}° ${_cardinal(_heading!)}'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: FittedBox(
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: CustomPaint(
                              painter: _CompassPainter(_heading ?? 0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: _locate,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                LocationInfo(address: _address, lat: _lat ?? 0, lng: _lng ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  static String _cardinal(double deg) {
    const d = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return d[((deg % 360) / 45).round() % 8];
  }
}

class _CompassPainter extends CustomPainter {
  final double headingDeg;
  const _CompassPainter(this.headingDeg);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFC9992F));
    canvas.drawCircle(c, r * .93, Paint()..color = const Color(0xFF1C4B8F));
    canvas.drawCircle(
      c,
      r * .93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFE9C45B),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-headingDeg * math.pi / 180);
    final tick = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5;
    for (var i = 0; i < 72; i++) {
      final a = i * math.pi / 36;
      final len = i % 9 == 0 ? 14.0 : 7.0;
      canvas.drawLine(
        Offset(math.sin(a) * (r * .86), -math.cos(a) * (r * .86)),
        Offset(math.sin(a) * (r * .86 - len), -math.cos(a) * (r * .86 - len)),
        tick,
      );
    }
    // star points
    final gold = Paint()..color = const Color(0xFFE9C45B);
    for (final a in [45.0, 135.0, 225.0, 315.0]) {
      canvas.save();
      canvas.rotate(a * math.pi / 180);
      canvas.drawPath(
        Path()
          ..moveTo(0, -r * .62)
          ..lineTo(r * .07, 0)
          ..lineTo(-r * .07, 0)
          ..close(),
        gold,
      );
      canvas.restore();
    }
    // needle
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * .7)
        ..lineTo(r * .1, 0)
        ..lineTo(-r * .1, 0)
        ..close(),
      Paint()..color = const Color(0xFFE53935),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, r * .7)
        ..lineTo(r * .1, 0)
        ..lineTo(-r * .1, 0)
        ..close(),
      Paint()..color = const Color(0xFF2E7DD7),
    );
    canvas.restore();
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String t, Offset o) {
      tp.text = TextSpan(
        text: t,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      );
      tp.layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    label('N', c + Offset(0, -r * .74));
    label('S', c + Offset(0, r * .74));
    label('E', c + Offset(r * .74, 0));
    label('W', c + Offset(-r * .74, 0));
    canvas.drawCircle(c, 9, gold);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.headingDeg != headingDeg;
}

// ───────────────────────── Gauges ─────────────────────────

class _GaugePainter extends CustomPainter {
  final double value, max, step;
  final Color accent;
  _GaugePainter(this.value, this.max, this.step, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFB8BEC8));
    canvas.drawCircle(c, r * .93, Paint()..color = const Color(0xFF0B1020));
    const start = 135 * math.pi / 180, sweep = 270 * math.pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * .82),
      start,
      sweep * (value / max).clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red],
          transform: const GradientRotation(0),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var v = 0.0; v <= max; v += step) {
      final a = start + sweep * v / max;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r * .72),
        c + dir * (r * .8),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
      tp.text = TextSpan(
        text: v.round().toString(),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      );
      tp.layout();
      tp.paint(
        canvas,
        c + dir * (r * .6) - Offset(tp.width / 2, tp.height / 2),
      );
    }
    final a = start + sweep * (value / max).clamp(0, 1);
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * (r * .7),
      Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, 10, Paint()..color = const Color(0xFF444B5A));
    canvas.drawCircle(c, 5, Paint()..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.value != value;
}

/// Gauge fed by a live stream. [start] returns null on success or an error
/// message (permission denied, sensor unavailable) shown with a Retry button.
class _GaugeScreen extends StatefulWidget {
  final String title, unit;
  final double max, step;
  final Future<String?> Function(void Function(double) onValue) start;
  const _GaugeScreen({
    required this.title,
    required this.unit,
    required this.max,
    required this.step,
    required this.start,
  });
  @override
  State<_GaugeScreen> createState() => _GaugeScreenState();
}

class _GaugeScreenState extends State<_GaugeScreen> {
  double value = 0, minV = double.infinity, maxV = 0, sum = 0;
  int n = 0;
  final history = <double>[];
  String? error;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    setState(() => error = null);
    final err = await widget.start((v) {
      if (!mounted) return;
      setState(() {
        value = v;
        minV = math.min(minV, v);
        maxV = math.max(maxV, v);
        sum += v;
        n++;
        history.add(v);
        if (history.length > 40) history.removeAt(0);
      });
    });
    if (mounted && err != null) setState(() => error = err);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget stat(String l, double v, Color c) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          border: Border.all(color: c.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              l,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              v.isFinite ? v.toStringAsFixed(1) : '--',
              style: TextStyle(
                color: c,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              widget.unit,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
    return AppScaffold(
      title: widget.title,
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            if (error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                  TextButton(onPressed: _begin, child: const Text('Retry')),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('Settings'),
                  ),
                ],
              ),
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _GaugePainter(
                      value,
                      widget.max,
                      widget.step,
                      Colors.red,
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            value.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            widget.unit,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                stat('Minimum', minV, Colors.green),
                stat(
                  'Average',
                  n == 0 ? double.nan : sum / n,
                  Colors.lightBlue,
                ),
                stat('Maximum', maxV, Colors.orange),
                stat('Real Time', value, Colors.redAccent),
              ],
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LinePainter(history, widget.max),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> data;
  final double max;
  _LinePainter(this.data, this.max);
  @override
  void paint(Canvas canvas, Size s) {
    if (data.length < 2) return;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final p = Offset(
        s.width * i / (data.length - 1),
        s.height * (1 - data[i] / max),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = Colors.green.withValues(alpha: .3));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) => true;
}

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});
  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  StreamSubscription<Position>? _sub;

  Future<String?> _start(void Function(double) onValue) async {
    try {
      await LocationService.current(); // checks services + permission
    } on LocationException catch (e) {
      return e.message;
    }
    await _sub?.cancel();
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          ),
        ).listen(
          // m/s -> km/h; speed is -1 / NaN when unknown
          (p) => onValue(p.speed.isFinite && p.speed > 0 ? p.speed * 3.6 : 0),
          onError: (_) {},
        );
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GaugeScreen(
    title: 'Speedometer',
    unit: 'km/h',
    max: 240,
    step: 20,
    start: _start,
  );
}

class SoundMeterScreen extends StatefulWidget {
  const SoundMeterScreen({super.key});
  @override
  State<SoundMeterScreen> createState() => _SoundMeterScreenState();
}

class _SoundMeterScreenState extends State<SoundMeterScreen> {
  StreamSubscription<NoiseReading>? _sub;

  Future<String?> _start(void Function(double) onValue) async {
    final status = await AdService.instance.guard(
      Permission.microphone.request,
    );
    if (!status.isGranted) return 'Microphone permission is required.';
    await _sub?.cancel();
    try {
      _sub = NoiseMeter().noise.listen(
        (r) => onValue(
          r.meanDecibel.isFinite ? r.meanDecibel.clamp(0, 120).toDouble() : 0,
        ),
        onError: (_) {},
      );
    } catch (_) {
      return 'Could not start the microphone.';
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GaugeScreen(
    title: 'Sound meter',
    unit: 'dB',
    max: 120,
    step: 10,
    start: _start,
  );
}
