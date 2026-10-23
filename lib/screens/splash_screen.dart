import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ads/ad_service.dart';
import 'home_screen.dart';
import 'intro_screen.dart';

/// Brand screen shown while ads/consent initialise; shows the splash
/// interstitial (if one loads in time) and then opens the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final started = DateTime.now();
    try {
      await AdService.instance.init().timeout(const Duration(seconds: 12));
      await AdService.instance.showSplashInterstitial();
    } catch (_) {
      // Never block the app on ads.
    }
    // Keep the brand screen up briefly even when no ad is shown.
    final left =
        const Duration(milliseconds: 1200) - DateTime.now().difference(started);
    if (left > Duration.zero) await Future.delayed(left);
    var seen = true;
    try {
      seen =
          (await SharedPreferences.getInstance()).getBool(kIntroSeenKey) ??
          false;
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => seen ? const HomeScreen() : const IntroScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF00142B),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/splash_bg.png', fit: BoxFit.cover),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0000142B), Color(0xE600142B)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'GPS: Navigation & Live Traffic',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Navigating your world, rain or shine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFBFD7F5), fontSize: 15),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
