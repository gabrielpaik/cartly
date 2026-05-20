import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';

class AdMobBannerSlot extends StatefulWidget {
  final double height;

  const AdMobBannerSlot({super.key, this.height = 60});

  @override
  State<AdMobBannerSlot> createState() => _AdMobBannerSlotState();
}

class _AdMobBannerSlotState extends State<AdMobBannerSlot> {
  static const Duration _retryDelay = Duration(seconds: 10);

  BannerAd? _bannerAd;
  bool _loaded = false;
  bool _isLoading = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;

    await AdMobService.instance.initialize();
    final ad = BannerAd(
      adUnitId: AdMobService.instance.bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AdMobService.instance.trackBannerLoaded();
          _retryTimer?.cancel();
          if (!mounted) {
            ad.dispose();
            _isLoading = false;
            return;
          }
          setState(() {
            _bannerAd?.dispose();
            _bannerAd = ad as BannerAd;
            _loaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          AdMobService.instance.trackBannerLoadFailed(error);
          ad.dispose();
          _isLoading = false;
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _loaded = false;
          });
          _scheduleRetry();
        },
        onAdImpression: (ad) {
          AdMobService.instance.trackBannerImpression();
        },
        onAdClicked: (ad) {
          AdMobService.instance.trackBannerClick();
        },
      ),
    );
    await ad.load();
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive == true) return;
    _retryTimer = Timer(_retryDelay, () {
      if (!mounted) return;
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height,
      width: _bannerAd!.size.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
