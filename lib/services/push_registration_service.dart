import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'auth_store.dart';
import 'install_id_store.dart';
import 'remote_push_repository.dart';

class PushRegistrationService {
  PushRegistrationService._();

  static final PushRegistrationService instance = PushRegistrationService._();
  static const List<int> _tokenRetryDelaysMs = [0, 1200, 2500, 5000];
  static const MethodChannel _platformChannel = MethodChannel('cartly/push');

  final RemotePushRepository _repository = RemotePushRepository(
    authTokenProvider: () => AuthStore.instance.session.value?.authToken,
  );
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;
  bool _retryScheduled = false;
  bool _iosTokenResetAttempted = false;
  String? _cachedAppVersion;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    AuthStore.instance.session.addListener(_onSessionChanged);
    _messaging.onTokenRefresh.listen((token) {
      unawaited(
        refreshRegistration(
          pushProvider: 'fcm',
          pushToken: token,
          notificationsEnabled: token.trim().isNotEmpty,
        ),
      );
    });
    await refreshRegistration();
  }

  Future<void> refreshRegistration({
    String? pushProvider,
    String? pushToken,
    bool? notificationsEnabled,
    String? appVersion,
  }) async {
    AuthorizationStatus? authorizationStatus;
    try {
      await _messaging.setAutoInitEnabled(true);
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
      authorizationStatus = settings.authorizationStatus;
    } catch (_) {
      authorizationStatus = null;
    }

    if (Platform.isIOS) {
      await _requestIosRemoteNotifications();
    }

    _ResolvedPushState resolvedState;
    try {
      resolvedState = await _resolvePushState(pushToken);
    } catch (_) {
      final fallbackToken = pushToken?.trim();
      resolvedState = _ResolvedPushState(
        fcmToken: fallbackToken,
        apnsToken: null,
        resetAttempted: _iosTokenResetAttempted,
        resetPerformed: false,
      );
    }

    final enabled =
        notificationsEnabled ??
        authorizationStatus == AuthorizationStatus.authorized ||
            authorizationStatus == AuthorizationStatus.provisional;
    final resolvedAppVersion = await _resolveAppVersion(appVersion);
    final iosNativeState = await _readIosRegistrationState();

    final debugInfo = <String, Object?>{
      'authorizationStatus': authorizationStatus?.name,
      'platform': Platform.operatingSystem,
      'notificationsEnabled': enabled,
      'pushProvider': pushProvider ?? 'fcm',
      'repositoryBaseUrl': _repository.baseUrl,
      'appVersion': resolvedAppVersion,
      'apnsTokenPresent': (resolvedState.apnsToken ?? '').trim().isNotEmpty,
      'apnsTokenLength': (resolvedState.apnsToken ?? '').trim().length,
      'fcmTokenPresent': (resolvedState.fcmToken ?? '').trim().isNotEmpty,
      'fcmTokenLength': (resolvedState.fcmToken ?? '').trim().length,
      'iosResetPerformed': resolvedState.resetPerformed,
      'iosNativeRegisteredForRemoteNotifications': iosNativeState.registered,
      'iosNativeRegistrationError': iosNativeState.error,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final installId = await InstallIdStore.getOrCreate();
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      await _repository.registerDevice(
        installId: installId,
        platform: Platform.operatingSystem,
        pushProvider: pushProvider ?? 'fcm',
        pushToken: resolvedState.fcmToken,
        notificationsEnabled: enabled,
        appVersion: resolvedAppVersion,
        locale: locale.toLanguageTag(),
        debugInfo: debugInfo,
      );
    } catch (_) {
      _scheduleRetry();
      return;
    }

    if ((resolvedState.fcmToken ?? '').trim().isEmpty && enabled) {
      _scheduleRetry();
    }
  }

  Future<_ResolvedPushState> _resolvePushState(String? initialToken) async {
    final seeded = initialToken?.trim();
    if (seeded != null && seeded.isNotEmpty) {
      return _ResolvedPushState(
        fcmToken: seeded,
        apnsToken: Platform.isIOS ? await _messaging.getAPNSToken() : null,
        resetAttempted: _iosTokenResetAttempted,
        resetPerformed: false,
      );
    }

    var resetPerformed = false;
    if (Platform.isIOS) {
      resetPerformed = await _maybeResetIosFcmToken();
    }

    String? lastApnsToken;
    for (final delayMs in _tokenRetryDelaysMs) {
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      if (Platform.isIOS) {
        lastApnsToken = await _messaging.getAPNSToken();
        if ((lastApnsToken ?? '').trim().isEmpty) {
          continue;
        }
      }
      final token = await _messaging.getToken();
      if ((token ?? '').trim().isNotEmpty) {
        return _ResolvedPushState(
          fcmToken: token,
          apnsToken: lastApnsToken,
          resetAttempted: _iosTokenResetAttempted,
          resetPerformed: resetPerformed,
        );
      }
    }
    return _ResolvedPushState(
      fcmToken: null,
      apnsToken: lastApnsToken,
      resetAttempted: _iosTokenResetAttempted,
      resetPerformed: resetPerformed,
    );
  }

  Future<bool> _maybeResetIosFcmToken() async {
    if (_iosTokenResetAttempted) {
      return false;
    }

    for (final delayMs in _tokenRetryDelaysMs) {
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      final apnsToken = await _messaging.getAPNSToken();
      if ((apnsToken ?? '').trim().isEmpty) {
        continue;
      }

      _iosTokenResetAttempted = true;
      try {
        await _messaging.deleteToken();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return true;
    }
    return false;
  }

  Future<void> _requestIosRemoteNotifications() async {
    if (!Platform.isIOS) return;
    try {
      await _platformChannel.invokeMethod('registerForRemoteNotifications');
    } catch (_) {}
  }

  Future<_IosNativeRegistrationState> _readIosRegistrationState() async {
    if (!Platform.isIOS) {
      return const _IosNativeRegistrationState();
    }
    try {
      final registered = await _platformChannel.invokeMethod<bool>(
        'isRegisteredForRemoteNotifications',
      );
      final error = await _platformChannel.invokeMethod<String?>(
        'lastRemoteNotificationRegistrationError',
      );
      return _IosNativeRegistrationState(
        registered: registered,
        error: (error ?? '').trim().isEmpty ? null : error,
      );
    } catch (_) {
      return const _IosNativeRegistrationState();
    }
  }

  Future<String?> _resolveAppVersion(String? explicitVersion) async {
    final normalized = (explicitVersion ?? '').trim();
    if (normalized.isNotEmpty) {
      _cachedAppVersion = normalized;
      return normalized;
    }
    if ((_cachedAppVersion ?? '').isNotEmpty) {
      return _cachedAppVersion;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      final resolved = buildNumber.isNotEmpty
          ? '$version+$buildNumber'
          : version;
      _cachedAppVersion = resolved.isNotEmpty ? resolved : null;
    } catch (_) {
      _cachedAppVersion = null;
    }
    return _cachedAppVersion;
  }

  void _scheduleRetry() {
    if (_retryScheduled) return;
    _retryScheduled = true;
    Future<void>.delayed(const Duration(seconds: 8), () async {
      _retryScheduled = false;
      await refreshRegistration();
    });
  }

  void _onSessionChanged() {
    unawaited(refreshRegistration());
  }
}

class _ResolvedPushState {
  const _ResolvedPushState({
    required this.fcmToken,
    required this.apnsToken,
    required this.resetAttempted,
    required this.resetPerformed,
  });

  final String? fcmToken;
  final String? apnsToken;
  final bool resetAttempted;
  final bool resetPerformed;
}

class _IosNativeRegistrationState {
  const _IosNativeRegistrationState({this.registered, this.error});

  final bool? registered;
  final String? error;
}
