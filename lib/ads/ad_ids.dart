import 'dart:io';
import 'package:flutter/foundation.dart';

/// AdMob unit IDs. Debug builds always use Google's official test units so
/// development never generates invalid impressions/clicks on the live units
/// (which can get an AdMob account limited).
///
/// The app ID itself lives in AndroidManifest.xml / Info.plist.
class AdIds {
  AdIds._();

  // Live units (from the AdMob console). If your iOS app is registered
  // separately in AdMob, put its units in the *Ios constants below.
  static const _banner = 'ca-app-pub-1558076059559801/4899688250';
  static const _interstitial = 'ca-app-pub-1558076059559801/4159049354';
  static const _splashInterstitial = 'ca-app-pub-1558076059559801/9804530571';
  static const _appOpen = 'ca-app-pub-1558076059559801/8808740804';
  static const _native = 'ca-app-pub-1558076059559801/6883714809';

  static const _bannerIos = _banner;
  static const _interstitialIos = _interstitial;
  static const _splashInterstitialIos = _splashInterstitial;
  static const _appOpenIos = _appOpen;
  static const _nativeIos = _native;

  // Google test units.
  static const _tBanner = (
    'ca-app-pub-3940256099942544/6300978111',
    'ca-app-pub-3940256099942544/2934735716',
  );
  static const _tInterstitial = (
    'ca-app-pub-3940256099942544/1033173712',
    'ca-app-pub-3940256099942544/4411468910',
  );
  static const _tAppOpen = (
    'ca-app-pub-3940256099942544/9257395921',
    'ca-app-pub-3940256099942544/5575463023',
  );
  static const _tNative = (
    'ca-app-pub-3940256099942544/2247696110',
    'ca-app-pub-3940256099942544/3986624511',
  );

  static bool get _android => Platform.isAndroid;

  static String get banner => kDebugMode
      ? (_android ? _tBanner.$1 : _tBanner.$2)
      : (_android ? _banner : _bannerIos);
  static String get interstitial => kDebugMode
      ? (_android ? _tInterstitial.$1 : _tInterstitial.$2)
      : (_android ? _interstitial : _interstitialIos);
  static String get splashInterstitial => kDebugMode
      ? (_android ? _tInterstitial.$1 : _tInterstitial.$2)
      : (_android ? _splashInterstitial : _splashInterstitialIos);
  static String get appOpen => kDebugMode
      ? (_android ? _tAppOpen.$1 : _tAppOpen.$2)
      : (_android ? _appOpen : _appOpenIos);
  static String get native => kDebugMode
      ? (_android ? _tNative.$1 : _tNative.$2)
      : (_android ? _native : _nativeIos);
}
