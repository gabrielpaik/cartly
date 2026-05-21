import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_ad_slot.dart';
import '../models/app_branding.dart';
import 'app_location_service.dart';
import 'auth_store.dart';
import 'my_page_insights.dart';

const _cartlyPublicBaseUrl = 'https://scan-api.seoa-nas.com';

class AppConfigStore {
  AppConfigStore._();
  static final AppConfigStore instance = AppConfigStore._();

  final ValueNotifier<AppBranding> branding = ValueNotifier(
    AppBranding.fallback,
  );
  final ValueNotifier<List<AppAdSlot>> adSlots = ValueNotifier(const []);
  final ValueNotifier<Map<String, dynamic>> copy = ValueNotifier(const {});
  final ValueNotifier<Map<String, dynamic>> explore = ValueNotifier(const {});
  final ValueNotifier<Map<String, dynamic>> runtime = ValueNotifier(const {});

  Future<void>? _activeRefresh;
  String? _brandingSignature;
  String? _adSlotsSignature;
  String? _copySignature;
  String? _exploreSignature;
  String? _runtimeSignature;

  String get _baseUrl {
    const appConfigEnv = String.fromEnvironment(
      'CARTLY_APP_CONFIG_BASE_URL',
      defaultValue: '',
    );
    if (appConfigEnv.trim().isNotEmpty) {
      return appConfigEnv.trim().replaceAll(RegExp(r'/$'), '');
    }
    const remoteEnv = String.fromEnvironment(
      'CARTLY_REMOTE_BASE_URL',
      defaultValue: '',
    );
    if (remoteEnv.trim().isNotEmpty) {
      return remoteEnv.trim().replaceAll(RegExp(r'/$'), '');
    }
    if (kReleaseMode) {
      return _cartlyPublicBaseUrl;
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8011';
    }
    return 'http://127.0.0.1:8011';
  }

  Future<void> load() async => refresh();

  int get receiptReminderDelayMinutes {
    final dynamic value = runtime.value['receiptReminderDelayMinutes'];
    if (value is num) {
      return value < 1 ? 60 : value.toInt();
    }
    return 60;
  }

  bool get myPageInsightsEnabled {
    final dynamic value = runtime.value['myPageInsightsEnabled'];
    if (value is bool) return value;
    return true;
  }

  int get myPageSummaryMonths {
    final dynamic value = runtime.value['myPageSummaryMonths'];
    if (value is num) {
      return value.toInt().clamp(1, 12);
    }
    return 3;
  }

  int get myPageTopCategoriesCount {
    final dynamic value = runtime.value['myPageTopCategoriesCount'];
    if (value is num) {
      return value.toInt().clamp(1, 8);
    }
    return 3;
  }

  int get myPageTopItemsCount {
    final dynamic value = runtime.value['myPageTopItemsCount'];
    if (value is num) {
      return value.toInt().clamp(1, 8);
    }
    return 3;
  }

  List<String> get myPageSectionOrder {
    final raw = runtime.value['myPageSectionOrder'];
    final fallback = <String>[
      'recentSaved',
      'monthlySummary',
      'allSavedHistory',
    ];
    final values = raw is List
        ? raw.whereType<String>().toList()
        : raw is String
        ? raw
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];
    if (values.isEmpty) {
      return fallback;
    }
    final ordered = <String>[];
    for (final item in values) {
      if (!fallback.contains(item) || ordered.contains(item)) {
        continue;
      }
      ordered.add(item);
    }
    for (final item in fallback) {
      if (!ordered.contains(item)) {
        ordered.add(item);
      }
    }
    return ordered;
  }

  List<MyPageCategoryGroup> get myPageCategoryGroups {
    final raw = runtime.value['myPageCategoryGroups'];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              MyPageCategoryGroup.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.label.trim().isNotEmpty)
        .toList();
  }

  AppAdSlot? slotByKey(String slotKey) {
    try {
      return adSlots.value.firstWhere((slot) => slot.slotKey == slotKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) {
      await activeRefresh;
      return;
    }

    final task = _performRefresh();
    _activeRefresh = task;
    try {
      await task;
    } finally {
      if (identical(_activeRefresh, task)) {
        _activeRefresh = null;
      }
    }
  }

  Future<void> _performRefresh() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('$_baseUrl/v1/app-config'));
      final session = AuthStore.instance.session.value;
      if (session != null && session.authToken.trim().isNotEmpty) {
        req.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${session.authToken}',
        );
      }
      final snapshot = AppLocationService.instance.snapshot.value;
      final city = snapshot?.normalizedCityName;
      final district = snapshot?.normalizedDistrictName;
      final neighborhood = snapshot?.normalizedNeighborhoodName;
      if (city != null && city.isNotEmpty) {
        req.headers.set('X-Cartly-City', Uri.encodeComponent(city));
      }
      if (district != null && district.isNotEmpty) {
        req.headers.set('X-Cartly-District', Uri.encodeComponent(district));
      }
      if (neighborhood != null && neighborhood.isNotEmpty) {
        req.headers.set('X-Cartly-Neighborhood', Uri.encodeComponent(neighborhood));
      }
      if (snapshot != null) {
        req.headers.set(
          'X-Cartly-Region-Captured-At',
          snapshot.capturedAt.toIso8601String(),
        );
        if (snapshot.source.trim().isNotEmpty) {
          req.headers.set('X-Cartly-Region-Source', snapshot.source);
        }
      }
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
      final runtimeJson = data?['runtime'] as Map<String, dynamic>?;

      _setBrandingIfChanged(brandingJson);
      _setAdSlotsIfChanged(slotList);
      _setJsonMapIfChanged(
        nextValue: copyJson == null ? const {} : Map<String, dynamic>.from(copyJson),
        currentSignature: _copySignature,
        onChanged: (signature, value) {
          _copySignature = signature;
          copy.value = value;
        },
      );
      _setJsonMapIfChanged(
        nextValue: exploreJson == null
            ? const {}
            : Map<String, dynamic>.from(exploreJson),
        currentSignature: _exploreSignature,
        onChanged: (signature, value) {
          _exploreSignature = signature;
          explore.value = value;
        },
      );
      _setJsonMapIfChanged(
        nextValue: runtimeJson == null
            ? const {}
            : Map<String, dynamic>.from(runtimeJson),
        currentSignature: _runtimeSignature,
        onChanged: (signature, value) {
          _runtimeSignature = signature;
          runtime.value = value;
        },
      );
    } catch (_) {
      // keep fallback; no throw on runtime config fetch failure
    }
  }

  void _setBrandingIfChanged(Map<String, dynamic>? nextValue) {
    final normalized = nextValue == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(nextValue);
    final nextSignature = _stableJsonEncode(normalized);
    if (_brandingSignature == nextSignature) {
      return;
    }
    _brandingSignature = nextSignature;
    branding.value = AppBranding.fromJson(normalized);
  }

  void _setAdSlotsIfChanged(List nextValue) {
    final normalized = nextValue
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final nextSignature = _stableJsonEncode(normalized);
    if (_adSlotsSignature == nextSignature) {
      return;
    }
    _adSlotsSignature = nextSignature;
    adSlots.value = normalized
        .map((item) => AppAdSlot.fromJson(item))
        .toList(growable: false);
  }

  void _setJsonMapIfChanged({
    required Map<String, dynamic> nextValue,
    required String? currentSignature,
    required void Function(String signature, Map<String, dynamic> value)
    onChanged,
  }) {
    final nextSignature = _stableJsonEncode(nextValue);
    if (currentSignature == nextSignature) {
      return;
    }
    onChanged(nextSignature, nextValue);
  }

  String _stableJsonEncode(Object? value) {
    final normalized = _normalizeJsonValue(value);
    return jsonEncode(normalized);
  }

  Object? _normalizeJsonValue(Object? value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in sortedKeys)
          key: _normalizeJsonValue(value[key]),
      };
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value;
  }
}
