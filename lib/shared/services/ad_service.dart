import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  bool _loading = false;

  Future<void> preloadInterstitial() async {
    if (_loading || _interstitial != null) {
      return;
    }

    _loading = true;
    await InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitial?.dispose();
          _interstitial = ad;
          _loading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial preload failed: $error');
          _interstitial = null;
          _loading = false;
        },
      ),
    );
  }

  Future<void> showOnClose({required VoidCallback onDone}) async {
    final InterstitialAd? ad = _interstitial;
    if (ad == null) {
      onDone();
      await preloadInterstitial();
      return;
    }

    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        onDone();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('Interstitial show failed: $error');
        ad.dispose();
        onDone();
        preloadInterstitial();
      },
    );

    try {
      ad.show();
    } catch (error) {
      debugPrint('Interstitial show exception: $error');
      ad.dispose();
      onDone();
      await preloadInterstitial();
    }
  }
}
