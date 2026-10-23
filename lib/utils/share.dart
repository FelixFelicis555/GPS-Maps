import 'package:share_plus/share_plus.dart';
import '../ads/ad_service.dart';

/// Opens the share sheet without letting the return trigger an app-open ad.
Future<void> guardedShare(ShareParams params) =>
    AdService.instance.guard(() => SharePlus.instance.share(params));
