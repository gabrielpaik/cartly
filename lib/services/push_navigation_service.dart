import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_attention_service.dart';

class PushNavigationService {
  PushNavigationService._();

  static final PushNavigationService instance = PushNavigationService._();
  static const MethodChannel _platformChannel = MethodChannel('cartly/push');

  final ValueNotifier<String?> pendingTargetTab = ValueNotifier<String?>(null);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _platformChannel.setMethodCallHandler(_handlePlatformCall);

    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((message) {
      final targetTab = _normalizeTargetTab(
        message.data['targetTab'] as String?,
      );
      if (targetTab == null) return;
      unawaited(AppAttentionService.instance.markTargetTab(targetTab));
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }

    await syncAttentionFromSystemNotifications();
  }

  Future<void> syncAttentionFromSystemNotifications() async {
    try {
      final targetTab = await _platformChannel.invokeMethod<String>(
        'latestDeliveredTargetTab',
      );
      final normalized = _normalizeTargetTab(targetTab);
      if (normalized != null) {
        await AppAttentionService.instance.markTargetTab(normalized);
      }
    } catch (_) {}
  }

  Future<void> clearSystemAttentionForTab(String targetTab) async {
    final normalized = _normalizeTargetTab(targetTab);
    if (normalized == null) return;
    try {
      await _platformChannel.invokeMethod(
        'clearDeliveredNotificationsForTargetTab',
        normalized,
      );
    } catch (_) {}
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'foregroundNotificationReceived':
        final arguments = call.arguments;
        if (arguments is Map) {
          final rawTargetTab = arguments['targetTab'];
          final targetTab = _normalizeTargetTab(rawTargetTab?.toString());
          if (targetTab != null) {
            await AppAttentionService.instance.markTargetTab(targetTab);
          }
        }
        return;
      default:
        return;
    }
  }

  void handleLocalNotificationPayload(String? payload) {
    final targetTab = _targetTabFromPayload(payload);
    if (targetTab == null) return;
    _setPendingTargetTab(targetTab);
  }

  String? consumePendingTargetTab() {
    final targetTab = pendingTargetTab.value;
    pendingTargetTab.value = null;
    return targetTab;
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final targetTab = _normalizeTargetTab(message.data['targetTab'] as String?);
    if (targetTab == null) return;
    _setPendingTargetTab(targetTab);
  }

  void _setPendingTargetTab(String targetTab) {
    pendingTargetTab.value = targetTab;
    unawaited(AppAttentionService.instance.markTargetTab(targetTab));
  }

  String? _targetTabFromPayload(String? payload) {
    final normalizedPayload = (payload ?? '').trim();
    if (normalizedPayload.isEmpty) return null;
    if (normalizedPayload == 'receipt-reminder') {
      return 'home';
    }
    try {
      final parsed = jsonDecode(normalizedPayload);
      if (parsed is Map<String, dynamic>) {
        return _normalizeTargetTab(parsed['targetTab'] as String?);
      }
    } catch (_) {}
    return null;
  }

  String? _normalizeTargetTab(String? value) {
    switch ((value ?? '').trim()) {
      case 'home':
      case 'explore':
      case 'my':
        return value!.trim();
      default:
        return null;
    }
  }
}
