import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_ids.dart';

/// Owns SDK start-up, user consent (UMP) and the full-screen formats
/// (splash interstitial, interstitial, app-open).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// True once the SDK is initialised and ads may be requested.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  // Tuning knobs.
  static const _interstitialEveryNthNav = 3;
  static const _fullScreenCooldown = Duration(seconds: 60);
  static const _appOpenCooldown = Duration(seconds: 30);
  static const _appOpenMaxAge = Duration(hours: 4);

  bool _initStarted = false;
  bool _fullScreenShowing = false;
  bool _suppressAppOpen = false;
  DateTime? _lastFullScreen;
  int _navCount = 0;

  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ───────────────────────── start-up ─────────────────────────

  Future<void> init() async {
    if (_initStarted || !_supported) return;
    _initStarted = true;
    try {
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      ready.value = true;
      AppStateEventNotifier.startListening();
      AppStateEventNotifier.appStateStream.forEach(_onAppState);
      _loadInterstitial();
      _loadAppOpen();
    } catch (e) {
      debugPrint('Ads init failed: $e');
      _initStarted = false;
    }
  }

  /// Shows the GDPR/UMP consent form when required (needs a consent message
  /// configured in the AdMob console; otherwise this is a no-op).
  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {}
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  // ───────────────────────── helpers ─────────────────────────

  bool _cooldownOver(Duration d) =>
      _lastFullScreen == null ||
      DateTime.now().difference(_lastFullScreen!) > d;

  void _markFullScreenDone() {
    _fullScreenShowing = false;
    _lastFullScreen = DateTime.now();
  }

  /// Wrap flows that background the app on purpose (permission dialogs, share
  /// sheet, opening Google Maps) so returning from them doesn't trigger an
  /// app-open ad.
  Future<T> guard<T>(Future<T> Function() action) async {
    _suppressAppOpen = true;
    try {
      return await action();
    } finally {
      Future.delayed(
        const Duration(seconds: 1),
        () => _suppressAppOpen = false,
      );
    }
  }

  // ───────────────────────── interstitial ─────────────────────────

  void _loadInterstitial() {
    if (!ready.value || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (e) => debugPrint('Interstitial failed: $e'),
      ),
    );
  }

  /// Call when the user navigates somewhere. Every Nth call (subject to a
  /// cooldown) shows an interstitial first; [proceed] always runs afterwards.
  void showInterstitialThen(VoidCallback proceed) {
    _navCount++;
    final ad = _interstitial;
    final show =
        ready.value &&
        ad != null &&
        !_fullScreenShowing &&
        _navCount % _interstitialEveryNthNav == 0 &&
        _cooldownOver(_fullScreenCooldown);
    if (!show) {
      proceed();
      if (ad == null) _loadInterstitial();
      return;
    }
    _interstitial = null;
    _fullScreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _markFullScreenDone();
        _loadInterstitial();
        proceed();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _fullScreenShowing = false;
        _loadInterstitial();
        proceed();
      },
    );
    ad.show();
  }

  // ───────────────────────── splash interstitial ─────────────────────────

  /// Loads and shows the splash interstitial; completes when it is dismissed,
  /// fails, or [timeout] elapses while loading.
  Future<void> showSplashInterstitial({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!ready.value) return;
    final done = Completer<void>();
    InterstitialAd.load(
      adUnitId: AdIds.splashInterstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (done.isCompleted) {
            ad.dispose(); // timed out already
            return;
          }
          _fullScreenShowing = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _markFullScreenDone();
              if (!done.isCompleted) done.complete();
            },
            onAdFailedToShowFullScreenContent: (a, e) {
              a.dispose();
              _fullScreenShowing = false;
              if (!done.isCompleted) done.complete();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (_) {
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    await done.future.timeout(timeout, onTimeout: () {});
  }

  // ───────────────────────── app open ─────────────────────────

  bool get _appOpenFresh =>
      _appOpen != null &&
      _appOpenLoadedAt != null &&
      DateTime.now().difference(_appOpenLoadedAt!) < _appOpenMaxAge;

  void _loadAppOpen() {
    if (!ready.value || _appOpenFresh) return;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (e) => debugPrint('App open failed: $e'),
      ),
    );
  }

  void _onAppState(AppState state) {
    if (state != AppState.foreground) return;
    if (!ready.value || _fullScreenShowing || _suppressAppOpen) return;
    if (!_cooldownOver(_appOpenCooldown)) return;
    if (!_appOpenFresh) {
      _appOpen?.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    final ad = _appOpen!;
    _appOpen = null;
    _fullScreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _markFullScreenDone();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _fullScreenShowing = false;
        _loadAppOpen();
      },
    );
    ad.show();
  }
}
