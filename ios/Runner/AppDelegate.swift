import Flutter
import UIKit
import GoogleMaps
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Key comes from ios/Flutter/Secrets.xcconfig (MAPS_API_KEY) via Info.plist.
    // The SDK throws if it is never given a key, so a placeholder keeps the app
    // running (with a blank map) until the real key is added.
    let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
    GMSServices.provideAPIKey(key?.isEmpty == false ? key! : "MISSING_MAPS_API_KEY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: "compactNative",
      nativeAdFactory: CompactNativeAdFactory()
    )
  }
}
