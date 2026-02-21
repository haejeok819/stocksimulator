import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static Future<InterstitialAd?> loadInterstitial({bool adsRemoved = false}) async {
    if (adsRemoved) {
      return null;
    }

    InterstitialAd? ad;
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd loadedAd) {
          if (adsRemoved) {
            loadedAd.dispose();
            ad = null;
            return;
          }
          ad = loadedAd;
        },
        onAdFailedToLoad: (_) {
          ad = null;
        },
      ),
    );
    return ad;
  }

  static BannerAd? createBannerAd({
    BannerAdListener listener = const BannerAdListener(),
    bool adsRemoved = false,
  }) {
    if (adsRemoved) {
      return null;
    }

    return BannerAd(
      adUnitId: bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: listener,
    );
  }
}
