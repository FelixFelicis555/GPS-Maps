import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme.dart';
import 'ad_ids.dart';
import 'ad_service.dart';

bool get _adsSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Anchored adaptive banner. Takes no space until an ad has loaded.
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});
  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.ready.addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (!_adsSupported ||
        _requested ||
        !AdService.instance.ready.value ||
        !mounted) {
      return;
    }
    _requested = true;
    final mq = MediaQuery.of(context);
    final width = mq.size.width.truncate() - 32;
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          mq.orientation,
          width,
        );
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, e) {
          debugPrint('Banner failed: $e');
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdService.instance.ready.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

/// Native ad rendered with Google's built-in "small" template (no platform
/// code needed). Takes no space until an ad has loaded.
class NativeAdView extends StatefulWidget {
  /// Compact layout built in native code (CompactNativeAdFactory on Android
  /// and iOS): a fixed 200x200 MediaView beside headline/body/CTA. AdMob needs
  /// a MediaView of at least 120x120 for ads that can show video; the small
  /// template has none.
  final bool compact;

  /// Side of the square MediaView in dp/pt for the compact layout (>= 120).
  final double mediaSize;

  /// When set, a loaded ad is framed by a strip of this colour.
  final Color? surround;

  /// Called with true once an ad has loaded, false when it is lost/failed, so
  /// the parent can make room for it.
  final ValueChanged<bool>? onLoadedChanged;
  const NativeAdView({
    super.key,
    this.compact = false,
    this.mediaSize = 200,
    this.surround,
    this.onLoadedChanged,
  });
  @override
  State<NativeAdView> createState() => _NativeAdViewState();
}

class _NativeAdViewState extends State<NativeAdView> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _requested = false;
  int _attempt = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    AdService.instance.ready.addListener(_maybeLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  void _maybeLoad() {
    if (!_adsSupported ||
        _requested ||
        !AdService.instance.ready.value ||
        !mounted) {
      return;
    }
    _requested = true;
    final ad = NativeAd(
      adUnitId: AdIds.native,
      request: const AdRequest(),
      factoryId: widget.compact ? 'compactNative' : null,
      customOptions: widget.compact
          ? {'mediaSize': widget.mediaSize.round()}
          : null,
      nativeTemplateStyle: widget.compact
          ? null
          : NativeTemplateStyle(
              templateType: TemplateType.small,
              mainBackgroundColor: Colors.white,
              cornerRadius: 14,
              callToActionTextStyle: NativeTemplateTextStyle(
                textColor: Colors.white,
                backgroundColor: kBlue,
                style: NativeTemplateFontStyle.bold,
                size: 13,
              ),
              primaryTextStyle: NativeTemplateTextStyle(
                textColor: kInk,
                style: NativeTemplateFontStyle.bold,
                size: 13,
              ),
            ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
          widget.onLoadedChanged?.call(true);
        },
        onAdFailedToLoad: (ad, e) {
          debugPrint('Native failed: $e');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          widget.onLoadedChanged?.call(false);
          // No-fill is often transient: retry a few times with backoff.
          if (_attempt < _retryDelays.length) {
            _retry = Timer(_retryDelays[_attempt++], () {
              _requested = false;
              _maybeLoad();
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  @override
  void dispose() {
    _retry?.cancel();
    AdService.instance.ready.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    final card = Container(
      margin: widget.compact
          ? const EdgeInsets.fromLTRB(12, 4, 12, 4)
          : const EdgeInsets.fromLTRB(12, 8, 12, 8),
      constraints: widget.compact
          ? BoxConstraints(
              minWidth: 320,
              minHeight: widget.mediaSize + 20,
              maxHeight: widget.mediaSize + 20,
            )
          : const BoxConstraints(minWidth: 320, minHeight: 90, maxHeight: 130),
      decoration: cardDecoration(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: ad),
    );
    return widget.surround == null
        ? card
        : ColoredBox(color: widget.surround!, child: card);
  }
}
