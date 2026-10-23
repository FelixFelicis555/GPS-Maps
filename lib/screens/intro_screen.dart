import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ads/ad_service.dart';
import '../ads/ad_widgets.dart';
import '../theme.dart';
import 'home_screen.dart';

const kIntroSeenKey = 'intro_seen';

class _Chip {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Chip(this.icon, this.color, this.label, this.value);
}

class _IntroPage {
  final String image;
  final Color bg;
  final String headline;
  final String body;
  final List<_Chip> chips;
  const _IntroPage(
    this.image,
    this.bg,
    this.headline,
    this.body, [
    this.chips = const [],
  ]);
}

const _pages = [
  _IntroPage(
    'assets/images/intro_1.png',
    Color(0xFF002649),
    'Smart Routes for Every Journey',
    'Get turn-by-turn precision routing designed for driving, hiking, or '
        'biking. Avoid traffic and discover the optimal paths tailored to '
        'your pace.',
  ),
  _IntroPage(
    'assets/images/intro_2.png',
    Color(0xFF042444),
    'Live Weather on Your Path',
    'Never get caught off guard. Track hyper-local forecasts, precipitation '
        'radar, and wind speeds directly along your active route in real time.',
    [
      _Chip(Icons.grain, Color(0xFF4FC3F7), 'Rain in', '12 min'),
      _Chip(Icons.thermostat, Color(0xFFEF5350), '24°C', 'Along route'),
      _Chip(Icons.air, Color(0xFF4DD0E1), '18 km/h', 'Wind speed'),
      _Chip(Icons.thunderstorm, Color(0xFFFFCA28), 'Storm in', '35 min'),
    ],
  ),
  _IntroPage(
    'assets/images/intro_3.png',
    Color(0xFF092336),
    'Always Know Your Way',
    'Rely on an ultra-accurate digital compass, live altitude readout, and '
        'GPS coordinates—keeping you oriented even off the grid.',
    [
      _Chip(Icons.explore, Color(0xFF29B6F6), 'Heading', '315° NW'),
      _Chip(Icons.terrain, Color(0xFF66BB6A), 'Altitude', '842 m'),
      _Chip(Icons.location_on, Color(0xFFEF5350), 'Coordinates', '17.3850° N'),
    ],
  ),
];

/// First-launch walkthrough; shown once, then remembered.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _ctl = PageController();
  int _i = 0;

  Future<void> _finish() async {
    try {
      (await SharedPreferences.getInstance()).setBool(kIntroSeenKey, true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _next() async {
    if (_i < _pages.length - 1) {
      _ctl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    // Last page: ask for location up front, then continue either way.
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await AdService.instance.guard(Geolocator.requestPermission);
      }
    } catch (_) {}
    await _finish();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      backgroundColor: _pages[_i].bg,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctl,
            itemCount: _pages.length,
            onPageChanged: (v) => setState(() => _i = v),
            itemBuilder: (_, i) => _page(i),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: last ? null : _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(int i) => _IntroPageView(
    page: _pages[i],
    index: i,
    onNext: _next,
    button: _button,
    chip: _chip,
  );

  Widget _button(String? label) => GestureDetector(
    onTap: _next,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E8BFF), Color(0xFF0B5BE3)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x662E8BFF),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: label != null
          ? Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ],
            ),
    ),
  );

  Widget _chip(_Chip ch) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0x66061A33),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(ch.icon, color: ch.color, size: 20),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ch.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFB8CCE6), fontSize: 9),
              ),
              Text(
                ch.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One intro page: artwork with text/chips/dots/button over its frosted panel,
/// then the compact native ad in its own fixed-height slot. When an ad is
/// loaded the artwork is cropped from the top (the panel stays intact) so the
/// ad always gets its full height; short screens scroll.
class _IntroPageView extends StatefulWidget {
  final _IntroPage page;
  final int index;
  final VoidCallback onNext;
  final Widget Function(String? label) button;
  final Widget Function(_Chip chip) chip;
  const _IntroPageView({
    required this.page,
    required this.index,
    required this.onNext,
    required this.button,
    required this.chip,
  });
  @override
  State<_IntroPageView> createState() => _IntroPageViewState();
}

class _IntroPageViewState extends State<_IntroPageView> {
  // Native ad slot: 220 card + 8 margin.
  static const _adSlot = 228.0;
  static const _minArt = 440.0;
  bool _adLoaded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    final i = widget.index;
    final last = i == _pages.length - 1;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final imgH = w * 1499 / 1049;
        final artH = _adLoaded
            ? (c.maxHeight - _adSlot).clamp(_minArt, imgH)
            : imgH;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: w,
                height: artH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        p.image,
                        fit: BoxFit.cover,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                    // Laid out from the bottom so nothing can overlap.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 22,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              children: [
                                Text(
                                  p.headline,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p.body,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFCFE0F5),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Same height on every page so dots/button align.
                          SizedBox(
                            height: 48,
                            child: p.chips.isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        for (final ch in p.chips)
                                          Expanded(child: widget.chip(ch)),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var d = 0; d < _pages.length; d++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  height: 7,
                                  width: d == i ? 22 : 7,
                                  decoration: BoxDecoration(
                                    color: d == i
                                        ? const Color(0xFF2E8BFF)
                                        : Colors.white38,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: widget.button(
                              last ? 'Enable Location & Get Started' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Takes no space until an ad loads.
              NativeAdView(
                compact: true,
                surround: kBg,
                onLoadedChanged: (v) {
                  if (mounted && v != _adLoaded) setState(() => _adLoaded = v);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
