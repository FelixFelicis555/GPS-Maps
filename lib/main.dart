import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GpsApp());
}

class GpsApp extends StatelessWidget {
  /// Tests pass false to skip the splash/ads and land on the home screen.
  final bool showSplash;
  const GpsApp({super.key, this.showSplash = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GPS maps & navigation',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: showSplash ? const SplashScreen() : const HomeScreen(),
  );
}
