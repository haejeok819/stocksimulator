import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static const Duration _interstitialCooldown = Duration(minutes: 7);
  static const int _interstitialDailyCap = 5;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  bool _adsRemoved = false;

  DateTime? _lastInterstitialShownAt;
  int _interstitialShownCountToday = 0;
  String? _interstitialCountDateKey;
  String? _currentSessionId;
  bool _interstitialShownInSession = false;

  bool get adsRemoved => _adsRemoved;

  void setAdsRemoved(bool value) {
    _adsRemoved = value;
    if (value) {
      _interstitial?.dispose();
      _interstitial = null;
      _rewarded?.dispose();
      _rewarded = null;
      _loadingInterstitial = false;
      _loadingRewarded = false;
    }
  }

  void startSession(String sessionId) {
    if (sessionId.isEmpty) return;
    _currentSessionId = sessionId;
    _interstitialShownInSession = false;
  }

  void endSession(String sessionId) {
    if (_currentSessionId != sessionId) return;
    _currentSessionId = null;
    _interstitialShownInSession = false;
  }

  bool canShowInterstitial({required String reason}) {
    if (_adsRemoved || _currentSessionId == null) {
      return false;
    }
    if (_interstitialShownInSession) {
      return false;
    }

    _normalizeDailyCapState();
    if (_interstitialShownCountToday >= _interstitialDailyCap) {
      debugPrint('Interstitial blocked by daily cap. reason=$reason');
      return false;
    }

    final DateTime? lastShown = _lastInterstitialShownAt;
    if (lastShown != null && DateTime.now().difference(lastShown) < _interstitialCooldown) {
      debugPrint('Interstitial blocked by cooldown. reason=$reason');
      return false;
    }

    return true;
  }

  void markInterstitialShown() {
    _normalizeDailyCapState();
    _lastInterstitialShownAt = DateTime.now();
    _interstitialShownInSession = true;
    _interstitialShownCountToday += 1;
  }

  Future<void> preloadInterstitial() async {
    if (_adsRemoved || _loadingInterstitial || _interstitial != null) {
      return;
    }

    _loadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (_adsRemoved) {
            ad.dispose();
            _loadingInterstitial = false;
            return;
          }
          _interstitial?.dispose();
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial preload failed: $error');
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  Future<void> preloadRewarded() async {
    if (_adsRemoved || _loadingRewarded || _rewarded != null) {
      return;
    }

    _loadingRewarded = true;
    await RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          if (_adsRemoved) {
            ad.dispose();
            _loadingRewarded = false;
            return;
          }
          _rewarded?.dispose();
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Rewarded preload failed: $error');
          _rewarded = null;
          _loadingRewarded = false;
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

  Future<RewardedAd?> takeOrLoadRewarded() async {
    if (_adsRemoved) {
      return null;
    }

    final RewardedAd? cached = _rewarded;
    if (cached != null) {
      _rewarded = null;
      return cached;
    }

    return AdHelper.loadRewarded(adsRemoved: _adsRemoved);
  }

  Future<bool> tryShowInterstitialGate({
    required String reason,
    Future<void> Function()? onProceed,
    Future<void> Function()? onSkip,
  }) async {
    if (!canShowInterstitial(reason: reason)) {
      if (onSkip != null) {
        await onSkip();
      }
      return false;
    }

    final InterstitialAd? ad = await takeOrLoadInterstitial();
    if (ad == null) {
      if (onSkip != null) {
        await onSkip();
      }
      unawaited(preloadInterstitial());
      return false;
    }

    final Completer<bool> completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('Interstitial show failed[$reason]: $error');
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    try {
      ad.show();
    } catch (error) {
      debugPrint('Interstitial show exception[$reason]: $error');
      ad.dispose();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    final bool shown = await completer.future;
    if (shown) {
      markInterstitialShown();
      if (onProceed != null) {
        await onProceed();
      }
    } else if (onSkip != null) {
      await onSkip();
    }

    unawaited(preloadInterstitial());
    return shown;
  }

  Future<bool> showRewardedFor8xUnlock() async {
    if (_adsRemoved) {
      return true;
    }

    final RewardedAd? ad = await takeOrLoadRewarded();
    if (ad == null) {
      unawaited(preloadRewarded());
      return false;
    }

    final Completer<bool> completer = Completer<bool>();
    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (Ad ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (Ad ad, AdError error) {
        debugPrint('Rewarded show failed: $error');
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    try {
      ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
        rewardEarned = true;
      });
    } catch (error) {
      debugPrint('Rewarded show exception: $error');
      ad.dispose();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    final bool unlocked = await completer.future;
    unawaited(preloadRewarded());
    return unlocked;
  }

  void _normalizeDailyCapState() {
    final String todayKey = _todayKey();
    if (_interstitialCountDateKey == todayKey) {
      return;
    }
    _interstitialCountDateKey = todayKey;
    _interstitialShownCountToday = 0;
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}$month$day';
  }
}
