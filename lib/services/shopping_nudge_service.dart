import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_attention_service.dart';
import 'app_config_store.dart';
import 'push_navigation_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  PushNavigationService.instance.handleLocalNotificationPayload(
    response.payload,
  );
}

class ShoppingNudgeService {
  ShoppingNudgeService._();

  static final ShoppingNudgeService instance = ShoppingNudgeService._();

  static const int _receiptReminderId = 42001;
  static const String _receiptReminderScheduledAtKey =
      'shopping_nudge_receipt_scheduled_at_v1';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _permissionsRequested = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    _prefs ??= await SharedPreferences.getInstance();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        PushNavigationService.instance.handleLocalNotificationPayload(
          response.payload,
        );
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;
  }

  Duration get _receiptReminderDelay =>
      Duration(minutes: AppConfigStore.instance.receiptReminderDelayMinutes);

  Future<void> refreshReceiptReminder({
    required bool hasPendingShoppingContext,
  }) async {
    await initialize();

    if (!hasPendingShoppingContext) {
      await cancelReceiptReminder();
      return;
    }

    await _requestPermissionsIfNeeded();

    final scheduledAt = tz.TZDateTime.now(tz.local).add(_receiptReminderDelay);

    try {
      await _notifications.zonedSchedule(
        _receiptReminderId,
        '장보기가 끝나셨나요?',
        '저장하고 영수증을 등록해보세요!',
        scheduledAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'shopping_nudges',
            'Shopping nudges',
            channelDescription: '장보기 저장 및 영수증 등록 리마인더',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '{"targetTab":"home","kind":"receipt-reminder"}',
      );

      await _prefs?.setInt(
        _receiptReminderScheduledAtKey,
        scheduledAt.millisecondsSinceEpoch,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ShoppingNudgeService.refreshReceiptReminder schedule failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _prefs?.remove(_receiptReminderScheduledAtKey);
    }
  }

  Future<void> syncHomeAttentionFromReminderStatus() async {
    await initialize();
    final scheduledAtMillis = _prefs?.getInt(_receiptReminderScheduledAtKey);
    if (scheduledAtMillis == null) return;
    if (DateTime.now().millisecondsSinceEpoch < scheduledAtMillis) return;
    await AppAttentionService.instance.markHome();
  }

  Future<void> acknowledgeReceiptReminder() async {
    await initialize();
    final scheduledAtMillis = _prefs?.getInt(_receiptReminderScheduledAtKey);
    if (scheduledAtMillis == null) return;
    if (DateTime.now().millisecondsSinceEpoch < scheduledAtMillis) return;
    await _prefs?.remove(_receiptReminderScheduledAtKey);
  }

  Future<void> cancelReceiptReminder() async {
    await initialize();
    final hadScheduledAt = _prefs?.containsKey(_receiptReminderScheduledAtKey) ??
        false;
    if (!hadScheduledAt) return;

    try {
      await _notifications.cancel(_receiptReminderId);
    } catch (error, stackTrace) {
      debugPrint(
        'ShoppingNudgeService.cancelReceiptReminder cancel failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await _prefs?.remove(_receiptReminderScheduledAtKey);
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
