import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum RewardedAdResult {
  rewarded,
  dismissed,
  unavailable,
  failedToShow,
}

class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  static const Duration _adLoadTimeout = Duration(seconds: 8);

  bool _initialized = false;
  InterstitialAd? _guestSaveInterstitial;
  Completer<bool>? _guestSaveInterstitialLoadCompleter;
  RewardedAd? _guestRetentionRewarded;
  Completer<bool>? _guestRetentionRewardedLoadCompleter;

  static String get _bannerUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111';
    }
    return Platform.isIOS
        ? 'ca-app-pub-7326648056182385/6115570564'
        : 'ca-app-pub-3940256099942544/6300978111';
  }

  static String get _guestSaveInterstitialUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712';
    }
    return Platform.isIOS
        ? 'ca-app-pub-7326648056182385/3149023690'
        : 'ca-app-pub-3940256099942544/1033173712';
  }

  static String get _guestRetentionRewardedUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    return Platform.isIOS
        ? 'ca-app-pub-7326648056182385/3972622950'
        : 'ca-app-pub-3940256099942544/5224354917';
  }

  String get bannerUnitId => _bannerUnitId;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(_preloadGuestSaveInterstitial());
    unawaited(_preloadGuestRetentionRewarded());
  }

  Future<bool> _preloadGuestSaveInterstitial() async {
    if (_guestSaveInterstitial != null) return true;
    if (_guestSaveInterstitialLoadCompleter != null) {
      return _guestSaveInterstitialLoadCompleter!.future;
    }

    final completer = Completer<bool>();
    _guestSaveInterstitialLoadCompleter = completer;

    await InterstitialAd.load(
      adUnitId: _guestSaveInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _guestSaveInterstitial = ad;
          if (!completer.isCompleted) completer.complete(true);
          if (identical(_guestSaveInterstitialLoadCompleter, completer)) {
            _guestSaveInterstitialLoadCompleter = null;
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(false);
          if (identical(_guestSaveInterstitialLoadCompleter, completer)) {
            _guestSaveInterstitialLoadCompleter = null;
          }
        },
      ),
    );

    return completer.future.timeout(
      _adLoadTimeout,
      onTimeout: () {
        if (identical(_guestSaveInterstitialLoadCompleter, completer)) {
          _guestSaveInterstitialLoadCompleter = null;
        }
        return false;
      },
    );
  }

  Future<bool> _preloadGuestRetentionRewarded() async {
    if (_guestRetentionRewarded != null) return true;
    if (_guestRetentionRewardedLoadCompleter != null) {
      return _guestRetentionRewardedLoadCompleter!.future;
    }

    final completer = Completer<bool>();
    _guestRetentionRewardedLoadCompleter = completer;

    await RewardedAd.load(
      adUnitId: _guestRetentionRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _guestRetentionRewarded = ad;
          if (!completer.isCompleted) completer.complete(true);
          if (identical(_guestRetentionRewardedLoadCompleter, completer)) {
            _guestRetentionRewardedLoadCompleter = null;
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(false);
          if (identical(_guestRetentionRewardedLoadCompleter, completer)) {
            _guestRetentionRewardedLoadCompleter = null;
          }
        },
      ),
    );

    return completer.future.timeout(
      _adLoadTimeout,
      onTimeout: () {
        if (identical(_guestRetentionRewardedLoadCompleter, completer)) {
          _guestRetentionRewardedLoadCompleter = null;
        }
        return false;
      },
    );
  }

  Future<void> showGuestSaveInterstitial() async {
    await initialize();
    if (_guestSaveInterstitial == null) {
      final ready = await _preloadGuestSaveInterstitial();
      if (!ready) return;
    }

    final ad = _guestSaveInterstitial;
    if (ad == null) return;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _guestSaveInterstitial = null;
        unawaited(_preloadGuestSaveInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _guestSaveInterstitial = null;
        unawaited(_preloadGuestSaveInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
    );
    await ad.show();
    await completer.future;
  }

  Future<RewardedAdResult> showGuestRetentionRewarded() async {
    await initialize();
    if (_guestRetentionRewarded == null) {
      final ready = await _preloadGuestRetentionRewarded();
      if (!ready) return RewardedAdResult.unavailable;
    }

    final ad = _guestRetentionRewarded;
    if (ad == null) return RewardedAdResult.unavailable;

    var rewarded = false;
    final completer = Completer<RewardedAdResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _guestRetentionRewarded = null;
        unawaited(_preloadGuestRetentionRewarded());
        if (!completer.isCompleted) {
          completer.complete(
            rewarded
                ? RewardedAdResult.rewarded
                : RewardedAdResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _guestRetentionRewarded = null;
        unawaited(_preloadGuestRetentionRewarded());
        if (!completer.isCompleted) {
          completer.complete(RewardedAdResult.failedToShow);
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          rewarded = true;
        },
      );
    } catch (_) {
      ad.dispose();
      _guestRetentionRewarded = null;
      unawaited(_preloadGuestRetentionRewarded());
      if (!completer.isCompleted) {
        completer.complete(RewardedAdResult.failedToShow);
      }
    }

    return completer.future;
  }
}
