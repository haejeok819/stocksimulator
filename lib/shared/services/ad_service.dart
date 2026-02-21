import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  bool _loading = false;
  bool _adsRemoved = false;

  bool get adsRemoved => _adsRemoved;

  void setAdsRemoved(bool value) {
    _adsRemoved = value;
    if (value) {
      _interstitial?.dispose();
      _interstitial = null;
      _loading = false;
    }
  }

  Future<void> preloadInterstitial() async {
    if (_adsRemoved || _loading || _interstitial != null) {
      return;
    }

    _loading = true;
    await InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (_adsRemoved) {
            ad.dispose();
            _loading = false;
            return;
          }
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

  Future<InterstitialAd?> takeOrLoadInterstitial() async {
    if (_adsRemoved) {
      return null;
    }

    final InterstitialAd? cached = _interstitial;
    if (cached != null) {
      _interstitial = null;
      return cached;
    }

    return AdHelper.loadInterstitial(adsRemoved: _adsRemoved);
  }

  Future<void> showOnClose({required VoidCallback onDone}) async {
    if (_adsRemoved) {
      onDone();
      return;
    }

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
