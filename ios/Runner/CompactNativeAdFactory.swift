import GoogleMobileAds
import UIKit
import google_mobile_ads

/// Native ad with a square MediaView (customOptions["mediaSize"] pt, default 200,
/// must stay >= 120) beside headline/body/CTA.
class CompactNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let size = CGFloat((customOptions?["mediaSize"] as? NSNumber)?.doubleValue ?? 200)
    let adView = NativeAdView()
    adView.backgroundColor = .white

    let media = MediaView()
    media.translatesAutoresizingMaskIntoConstraints = false
    media.contentMode = .scaleAspectFit
    media.clipsToBounds = true

    let badge = UILabel()
    badge.text = " Ad "
    badge.font = .boldSystemFont(ofSize: 10)
    badge.textColor = .black
    badge.backgroundColor = UIColor(red: 1, green: 0.757, blue: 0.027, alpha: 1)
    badge.layer.cornerRadius = 4
    badge.clipsToBounds = true
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let advertiser = UILabel()
    advertiser.font = .systemFont(ofSize: 11)
    advertiser.textColor = UIColor(white: 0.37, alpha: 1)
    advertiser.text = nativeAd.advertiser ?? nativeAd.store ?? ""

    let headline = UILabel()
    headline.font = .boldSystemFont(ofSize: 15)
    headline.textColor = UIColor(red: 0.055, green: 0.075, blue: 0.188, alpha: 1)
    headline.numberOfLines = 2
    headline.text = nativeAd.headline

    let body = UILabel()
    body.font = .systemFont(ofSize: 12)
    body.textColor = UIColor(white: 0.27, alpha: 1)
    body.numberOfLines = size < 160 ? 1 : 3
    body.text = nativeAd.body
    body.isHidden = nativeAd.body == nil

    let cta = UIButton(type: .system)
    cta.setTitle(nativeAd.callToAction?.uppercased(), for: .normal)
    cta.titleLabel?.font = .boldSystemFont(ofSize: 13)
    cta.setTitleColor(.white, for: .normal)
    cta.backgroundColor = UIColor(red: 0.098, green: 0.463, blue: 0.824, alpha: 1)
    cta.layer.cornerRadius = 8
    cta.isHidden = nativeAd.callToAction == nil
    cta.isUserInteractionEnabled = false  // the SDK handles the tap
    cta.translatesAutoresizingMaskIntoConstraints = false
    cta.heightAnchor.constraint(equalToConstant: size < 160 ? 34 : 40).isActive = true

    let top = UIStackView(arrangedSubviews: [badge, advertiser])
    top.axis = .horizontal
    top.spacing = 6
    top.alignment = .center

    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

    let column = UIStackView(arrangedSubviews: [top, headline, body, spacer, cta])
    column.axis = .vertical
    column.spacing = 3
    column.translatesAutoresizingMaskIntoConstraints = false

    adView.addSubview(media)
    adView.addSubview(column)
    NSLayoutConstraint.activate([
      media.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
      media.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
      media.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10),
      media.widthAnchor.constraint(equalToConstant: size),
      media.heightAnchor.constraint(equalToConstant: size),
      column.leadingAnchor.constraint(equalTo: media.trailingAnchor, constant: 10),
      column.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
      column.topAnchor.constraint(equalTo: media.topAnchor),
      column.bottomAnchor.constraint(equalTo: media.bottomAnchor),
    ])

    adView.mediaView = media
    adView.headlineView = headline
    adView.bodyView = body
    adView.advertiserView = advertiser
    adView.callToActionView = cta
    adView.nativeAd = nativeAd
    return adView
  }
}
