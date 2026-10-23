package com.questionsa.nearme

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/** Native ad with a fixed MediaView MediaView (see native_ad_compact.xml). */
class CompactNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_compact, null) as NativeAdView

        // Square MediaView side in dp (must stay >= 120 for video ads).
        val sizeDp = (customOptions?.get("mediaSize") as? Number)?.toInt() ?: 200
        val sizePx = (sizeDp * context.resources.displayMetrics.density).toInt()

        val media = adView.findViewById<MediaView>(R.id.ad_media)
        media.layoutParams = media.layoutParams.apply {
            width = sizePx
            height = sizePx
        }
        val textColumn = adView.findViewById<View>(R.id.ad_text_column)
        textColumn.layoutParams = textColumn.layoutParams.apply { height = sizePx }
        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val advertiser = adView.findViewById<TextView>(R.id.ad_advertiser)
        val cta = adView.findViewById<Button>(R.id.ad_cta)

        // Small media views leave less room beside them: trim body and CTA.
        if (sizeDp < 160) {
            body.maxLines = 1
            cta.layoutParams = cta.layoutParams.apply {
                height = (34 * context.resources.displayMetrics.density).toInt()
            }
        }

        adView.mediaView = media
        adView.headlineView = headline
        adView.bodyView = body
        adView.advertiserView = advertiser
        adView.callToActionView = cta

        headline.text = nativeAd.headline
        body.text = nativeAd.body
        body.visibility = if (nativeAd.body == null) View.GONE else View.VISIBLE
        advertiser.text = nativeAd.advertiser ?: nativeAd.store ?: ""
        cta.text = nativeAd.callToAction
        cta.visibility = if (nativeAd.callToAction == null) View.INVISIBLE else View.VISIBLE

        adView.setNativeAd(nativeAd)
        return adView
    }
}
