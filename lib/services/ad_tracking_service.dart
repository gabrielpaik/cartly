import 'dart:convert';
import 'dart:io';

import '../models/app_ad_slot.dart';
import 'api_base.dart';
import 'auth_store.dart';

class AdTrackingService {
  AdTrackingService._();
  static final AdTrackingService instance = AdTrackingService._();

  final Map<String, String> _impressionIds = {};
  final Set<String> _inflightImpressions = {};
  final HttpClient _httpClient = HttpClient();

  Uri _uri(String path) => Uri.parse('${getCartlyApiBaseUrl()}$path');

  String _trackKey(AppAdSlot slot) {
    final campaignId = slot.config.campaignId ?? '';
    return '${slot.slotKey}:$campaignId';
  }

  Future<String?> recordImpression({
    required AppAdSlot slot,
    required String screenName,
  }) async {
    final campaignId = slot.config.campaignId?.trim();
    if (campaignId == null || campaignId.isEmpty || !slot.enabled) return null;

    final key = _trackKey(slot);
    final cached = _impressionIds[key];
    if (cached != null && cached.isNotEmpty) return cached;
    if (_inflightImpressions.contains(key)) return null;

    _inflightImpressions.add(key);
    try {
      final request = await _httpClient.postUrl(_uri('/v1/ads/impressions'));
      _applyHeaders(request);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'slotKey': slot.slotKey,
          'campaignId': campaignId,
          'screenName': screenName,
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;
      final impressionId = (data['impressionId'] as String?)?.trim();
      if (impressionId == null || impressionId.isEmpty) return null;
      _impressionIds[key] = impressionId;
      return impressionId;
    } catch (_) {
      return null;
    } finally {
      _inflightImpressions.remove(key);
    }
  }

  Future<void> recordClick({
    required AppAdSlot slot,
    required String screenName,
  }) async {
    final impressionId = await recordImpression(
      slot: slot,
      screenName: screenName,
    );
    if (impressionId == null || impressionId.isEmpty) return;

    try {
      final request = await _httpClient.postUrl(_uri('/v1/ads/clicks'));
      _applyHeaders(request);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'impressionId': impressionId}));
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // swallow; tracking must not break UI
    }
  }

  void _applyHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final authToken = AuthStore.instance.session.value?.authToken.trim() ?? '';
    if (authToken.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    }
  }
}
