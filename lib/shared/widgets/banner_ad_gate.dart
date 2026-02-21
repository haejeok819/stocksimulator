import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';

class BannerAdGate extends StatefulWidget {
  const BannerAdGate({super.key});

  @override
  State<BannerAdGate> createState() => _BannerAdGateState();
}

class _BannerAdGateState extends State<BannerAdGate> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    if (AdService.instance.adsRemoved) {
      return;
    }

    _bannerAd = AdHelper.createBannerAd(adsRemoved: AdService.instance.adsRemoved)
      ?..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdService.instance.adsRemoved || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
