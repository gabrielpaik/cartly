import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_ad_slot.dart';
import '../models/app_branding.dart';

class AppConfigStore {
  AppConfigStore._();
  static final AppConfigStore instance = AppConfigStore._();

  final ValueNotifier<AppBranding> branding = ValueNotifier(
    AppBranding.fallback,
  );
  final ValueNotifier<List<AppAdSlot>> adSlots = ValueNotifier(const []);
  final ValueNotifier<Map<String, dynamic>> copy = ValueNotifier(const {});
  final ValueNotifier<Map<String, dynamic>> explore = ValueNotifier(const {});

  String get _baseUrl {
    const env = String.fromEnvironment(
      'CARTLY_APP_CONFIG_BASE_URL',
      defaultValue: '',
    );
    if (env.trim().isNotEmpty) {
      return env.trim().replaceAll(RegExp(r'/$'), '');
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8011';
    }
    return 'http://127.0.0.1:8011';
  }

  Future<void> load() async => refresh();

  AppAdSlot? slotByKey(String slotKey) {
    try {
      return adSlots.value.firstWhere((slot) => slot.slotKey == slotKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('$_baseUrl/v1/app-config'));
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        client.close(force: true);
        return;
      }
      final body = await utf8.decodeStream(res);
      client.close(force: true);
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      final brandingJson = data?['branding'] as Map<String, dynamic>?;
      final adsJson = data?['ads'] as Map<String, dynamic>?;
      final slotList =
          ((adsJson?['slots'] as List?) ??
          (data?['adSlots'] as List?) ??
          const []);
      final copyJson = data?['copy'] as Map<String, dynamic>?;
      final exploreJson = data?['explore'] as Map<String, dynamic>?;

      branding.value = AppBranding.fromJson(brandingJson);
      adSlots.value = slotList
          .whereType<Map>()
          .map((item) => AppAdSlot.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      copy.value = copyJson == null
          ? const {}
          : Map<String, dynamic>.from(copyJson);
      explore.value = exploreJson == null
          ? const {}
          : Map<String, dynamic>.from(exploreJson);
    } catch (_) {
      // keep fallback; no throw on runtime config fetch failure
    }
  }
}
