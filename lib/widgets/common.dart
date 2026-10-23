import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../ads/ad_widgets.dart';
import '../theme.dart';

/// Screen shell: app bar with back arrow, body, and the sponsored ad card.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool showAd;
  final bool showBanner;
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showAd = true,
    this.showBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.flip(
            flipX: true,
            child: SvgPicture.asset('assets/icons/back.svg', width: 28),
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        leadingWidth: 44,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (showBanner) const BannerAdView(),
            Expanded(child: body),
            if (showAd) const AdCard(),
          ],
        ),
      ),
    );
  }
}

/// Sponsored native ad slot (collapses when no ad is available).
class AdCard extends StatelessWidget {
  const AdCard({super.key});
  @override
  Widget build(BuildContext context) =>
      const NativeAdView(compact: true, mediaSize: 120);
}

class ToolTile extends StatelessWidget {
  final String title;
  final String asset;
  final VoidCallback onTap;
  final bool chevron;
  const ToolTile({
    super.key,
    required this.title,
    required this.asset,
    required this.onTap,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (chevron) const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: asset.isEmpty
                ? const Icon(
                    Icons.local_atm,
                    size: 40,
                    color: Color(0xFFFFA000),
                  )
                : SvgPicture.asset(asset, width: 44, height: 44),
          ),
        ],
      ),
    ),
  );
}

/// Offline stand-in for a real map (wire google_maps_flutter / flutter_map here).
class MapPlaceholder extends StatelessWidget {
  final bool traffic;
  final bool showPin;
  final int seed;
  const MapPlaceholder({
    super.key,
    this.traffic = false,
    this.showPin = true,
    this.seed = 7,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(painter: _MapPainter(traffic, seed)),
      if (showPin)
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Icon(Icons.location_on, color: Color(0xFFE5502D), size: 34),
          ),
        ),
    ],
  );
}

class _MapPainter extends CustomPainter {
  final bool traffic;
  final int seed;
  _MapPainter(this.traffic, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF6F7F9),
    );
    final r = Random(seed);
    final water = Paint()..color = const Color(0xFF8ED8F8);
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromLTWH(
          r.nextDouble() * size.width * .8,
          r.nextDouble() * size.height * .8,
          60 + r.nextDouble() * 70,
          40 + r.nextDouble() * 60,
        ),
        water,
      );
    }
    final park = Paint()..color = const Color(0xFFCDE8C0);
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.nextDouble() * size.width,
            r.nextDouble() * size.height,
            30,
            20,
          ),
          const Radius.circular(4),
        ),
        park,
      );
    }
    final road = Paint()
      ..color = const Color(0xFFDADCE0)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final colors = [
      const Color(0xFF3CC85A),
      const Color(0xFF3CC85A),
      const Color(0xFFFF9800),
      const Color(0xFFE53935),
    ];
    for (var i = 0; i < 26; i++) {
      final p = Path()
        ..moveTo(r.nextDouble() * size.width, r.nextDouble() * size.height)
        ..quadraticBezierTo(
          r.nextDouble() * size.width,
          r.nextDouble() * size.height,
          r.nextDouble() * size.width,
          r.nextDouble() * size.height,
        );
      canvas.drawPath(
        p,
        traffic
            ? (Paint()
                ..color = colors[r.nextInt(colors.length)]
                ..strokeWidth = 3
                ..style = PaintingStyle.stroke)
            : road,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.traffic != traffic || old.seed != seed;
}
