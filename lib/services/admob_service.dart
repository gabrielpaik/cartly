import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_event_service.dart';

enum RewardedAdResult { rewarded, dismissed, unavailable, failedToShow }

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
        : 'ca-app-pub-7326648056182385/7877427532';
  }

  static String get _guestSaveInterstitialUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712';
    }
    return Platform.isIOS
        ? 'ca-app-pub-7326648056182385/3149023690'
        : 'ca-app-pub-7326648056182385/2241957474';
  }

  static String get _guestRetentionRewardedUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    return Platform.isIOS
        ? 'ca-app-pub-7326648056182385/3972622950'
        : 'ca-app-pub-7326648056182385/5798059103';
  }

  String get bannerUnitId => _bannerUnitId;

  Map<String, Object?> _eventProps({
    required String format,
    required String placement,
    required String unitId,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'format': format,
      'placement': placement,
      'unitId': unitId,
      'debugMode': kDebugMode,
      'isTestUnit': unitId.startsWith('ca-app-pub-3940256099942544/'),
      'platform': Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : Platform.operatingSystem,
      ...extra,
    };
  }

  void _trackAdEvent(
    String name, {
    required String format,
    required String placement,
    required String unitId,
    String? onceKey,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    unawaited(
      AppEventService.instance.track(
        name,
        screen: placement,
        onceKey: onceKey,
        props: _eventProps(
          format: format,
          placement: placement,
          unitId: unitId,
          extra: extra,
        ),
      ),
    );
  }

  void trackBannerLoaded() {
    _trackAdEvent(
      'admob_banner_loaded',
      format: 'banner',
      placement: 'inline_banner',
      unitId: _bannerUnitId,
      onceKey:
          'admob:banner:loaded:$_bannerUnitId:${kDebugMode ? 'debug' : 'release'}',
    );
  }

  void trackBannerLoadFailed(LoadAdError error) {
    _trackAdEvent(
      'admob_banner_failed',
      format: 'banner',
      placement: 'inline_banner',
      unitId: _bannerUnitId,
      onceKey: 'admob:banner:failed:$_bannerUnitId:${error.code}',
      extra: {
        'errorCode': error.code,
        'errorMessage': error.message,
        'errorDomain': error.domain,
      },
    );
  }

  void trackBannerImpression() {
    _trackAdEvent(
      'admob_banner_impression',
      format: 'banner',
      placement: 'inline_banner',
      unitId: _bannerUnitId,
      onceKey:
          'admob:banner:impression:$_bannerUnitId:${kDebugMode ? 'debug' : 'release'}',
    );
  }

  void trackBannerClick() {
    _trackAdEvent(
      'admob_banner_clicked',
      format: 'banner',
      placement: 'inline_banner',
      unitId: _bannerUnitId,
      onceKey:
          'admob:banner:clicked:$_bannerUnitId:${kDebugMode ? 'debug' : 'release'}',
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _trackAdEvent(
        'admob_initialize_succeeded',
        format: 'sdk',
        placement: 'bootstrap',
        unitId: Platform.isIOS
            ? 'ca-app-pub-7326648056182385~1227671006'
            : 'ca-app-pub-7326648056182385~9903617195',
        onceKey:
            'admob:initialize:${Platform.isIOS ? 'ios' : 'android'}:${kDebugMode ? 'debug' : 'release'}',
        extra: {
          'bannerUnitId': _bannerUnitId,
          'interstitialUnitId': _guestSaveInterstitialUnitId,
          'rewardedUnitId': _guestRetentionRewardedUnitId,
        },
      );
      unawaited(_preloadGuestSaveInterstitial());
      unawaited(_preloadGuestRetentionRewarded());
    } catch (error) {
      _trackAdEvent(
        'admob_initialize_failed',
        format: 'sdk',
        placement: 'bootstrap',
        unitId: Platform.isIOS
            ? 'ca-app-pub-7326648056182385~1227671006'
            : 'ca-app-pub-7326648056182385~9903617195',
        onceKey:
            'admob:initialize_failed:${Platform.isIOS ? 'ios' : 'android'}:${kDebugMode ? 'debug' : 'release'}',
        extra: {'error': error.toString()},
      );
      _initialized = false;
    }
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
          _trackAdEvent(
            'admob_interstitial_loaded',
            format: 'interstitial',
            placement: 'guest_cart_save',
            unitId: _guestSaveInterstitialUnitId,
            onceKey:
                'admob:interstitial:loaded:$_guestSaveInterstitialUnitId:${kDebugMode ? 'debug' : 'release'}',
          );
          if (!completer.isCompleted) completer.complete(true);
          if (identical(_guestSaveInterstitialLoadCompleter, completer)) {
            _guestSaveInterstitialLoadCompleter = null;
          }
        },
        onAdFailedToLoad: (error) {
          _trackAdEvent(
            'admob_interstitial_failed',
            format: 'interstitial',
            placement: 'guest_cart_save',
            unitId: _guestSaveInterstitialUnitId,
            onceKey:
                'admob:interstitial:failed:$_guestSaveInterstitialUnitId:${error.code}',
            extra: {
              'errorCode': error.code,
              'errorMessage': error.message,
              'errorDomain': error.domain,
            },
          );
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
          _trackAdEvent(
            'admob_rewarded_loaded',
            format: 'rewarded',
            placement: 'guest_retention',
            unitId: _guestRetentionRewardedUnitId,
            onceKey:
                'admob:rewarded:loaded:$_guestRetentionRewardedUnitId:${kDebugMode ? 'debug' : 'release'}',
          );
          if (!completer.isCompleted) completer.complete(true);
          if (identical(_guestRetentionRewardedLoadCompleter, completer)) {
            _guestRetentionRewardedLoadCompleter = null;
          }
        },
        onAdFailedToLoad: (error) {
          _trackAdEvent(
            'admob_rewarded_failed',
            format: 'rewarded',
            placement: 'guest_retention',
            unitId: _guestRetentionRewardedUnitId,
            onceKey:
                'admob:rewarded:failed:$_guestRetentionRewardedUnitId:${error.code}',
            extra: {
              'errorCode': error.code,
              'errorMessage': error.message,
              'errorDomain': error.domain,
            },
          );
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
      onAdShowedFullScreenContent: (ad) {
        _trackAdEvent(
          'admob_interstitial_showed',
          format: 'interstitial',
          placement: 'guest_cart_save',
          unitId: _guestSaveInterstitialUnitId,
        );
      },
      onAdImpression: (ad) {
        _trackAdEvent(
          'admob_interstitial_impression',
          format: 'interstitial',
          placement: 'guest_cart_save',
          unitId: _guestSaveInterstitialUnitId,
        );
      },
      onAdClicked: (ad) {
        _trackAdEvent(
          'admob_interstitial_clicked',
          format: 'interstitial',
          placement: 'guest_cart_save',
          unitId: _guestSaveInterstitialUnitId,
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        _trackAdEvent(
          'admob_interstitial_dismissed',
          format: 'interstitial',
          placement: 'guest_cart_save',
          unitId: _guestSaveInterstitialUnitId,
        );
        ad.dispose();
        _guestSaveInterstitial = null;
        unawaited(_preloadGuestSaveInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _trackAdEvent(
          'admob_interstitial_failed_to_show',
          format: 'interstitial',
          placement: 'guest_cart_save',
          unitId: _guestSaveInterstitialUnitId,
          extra: {'errorCode': error.code, 'errorMessage': error.message},
        );
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
      onAdShowedFullScreenContent: (ad) {
        _trackAdEvent(
          'admob_rewarded_showed',
          format: 'rewarded',
          placement: 'guest_retention',
          unitId: _guestRetentionRewardedUnitId,
        );
      },
      onAdImpression: (ad) {
        _trackAdEvent(
          'admob_rewarded_impression',
          format: 'rewarded',
          placement: 'guest_retention',
          unitId: _guestRetentionRewardedUnitId,
        );
      },
      onAdClicked: (ad) {
        _trackAdEvent(
          'admob_rewarded_clicked',
          format: 'rewarded',
          placement: 'guest_retention',
          unitId: _guestRetentionRewardedUnitId,
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        _trackAdEvent(
          'admob_rewarded_dismissed',
          format: 'rewarded',
          placement: 'guest_retention',
          unitId: _guestRetentionRewardedUnitId,
          extra: {'rewarded': rewarded},
        );
        ad.dispose();
        _guestRetentionRewarded = null;
        unawaited(_preloadGuestRetentionRewarded());
        if (!completer.isCompleted) {
          completer.complete(
            rewarded ? RewardedAdResult.rewarded : RewardedAdResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _trackAdEvent(
          'admob_rewarded_failed_to_show',
          format: 'rewarded',
          placement: 'guest_retention',
          unitId: _guestRetentionRewardedUnitId,
          extra: {'errorCode': error.code, 'errorMessage': error.message},
        );
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
          _trackAdEvent(
            'admob_rewarded_earned',
            format: 'rewarded',
            placement: 'guest_retention',
            unitId: _guestRetentionRewardedUnitId,
            extra: {'rewardAmount': reward.amount, 'rewardType': reward.type},
          );
        },
      );
    } catch (error) {
      _trackAdEvent(
        'admob_rewarded_show_threw',
        format: 'rewarded',
        placement: 'guest_retention',
        unitId: _guestRetentionRewardedUnitId,
        extra: {'error': error.toString()},
      );
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
