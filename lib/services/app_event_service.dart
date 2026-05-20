import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'api_base.dart';
import 'auth_store.dart';

class AppEventService {
  AppEventService._();
  static final AppEventService instance = AppEventService._();

  final HttpClient _httpClient = HttpClient();
  final Set<String> _onceKeys = <String>{};
  String? _cachedAppVersion;

  Uri _uri(String path) => Uri.parse('${getCartlyApiBaseUrl()}$path');

  Future<void> track(
    String name, {
    String? screen,
    Map<String, Object?> props = const <String, Object?>{},
    String? onceKey,
  }) async {
    final normalizedOnceKey = onceKey?.trim();
    if (normalizedOnceKey != null && normalizedOnceKey.isNotEmpty) {
      if (_onceKeys.contains(normalizedOnceKey)) return;
      _onceKeys.add(normalizedOnceKey);
    }

    try {
      final request = await _httpClient.postUrl(_uri('/v1/events'));
      _applyHeaders(request);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'events': [
            {
              'name': name,
              'screen': screen,
              'props': _normalizeProps(props),
              'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
              'devicePlatform': Platform.isIOS
                  ? 'ios'
                  : Platform.isAndroid
                  ? 'android'
                  : Platform.operatingSystem,
              'deviceType': 'mobile',
              'osName': Platform.operatingSystem,
              'osVersion': Platform.operatingSystemVersion,
              'appVersion': await _resolveAppVersion(),
            },
          ],
        }),
      );
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // telemetry must not break app flows
    }
  }

  Map<String, Object?> _normalizeProps(Map<String, Object?> props) {
    final normalized = <String, Object?>{};
    props.forEach((key, value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        normalized[key] = value;
        return;
      }
      if (value is List || value is Map) {
        normalized[key] = value;
        return;
      }
      normalized[key] = value.toString();
    });
    return normalized;
  }

  Future<String> _resolveAppVersion() async {
    if (_cachedAppVersion != null && _cachedAppVersion!.isNotEmpty) {
      return _cachedAppVersion!;
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final build = packageInfo.buildNumber.trim();
      final version = packageInfo.version.trim();
      _cachedAppVersion = build.isEmpty ? version : '$version+$build';
      return _cachedAppVersion!;
    } catch (_) {
      _cachedAppVersion = 'unknown';
      return _cachedAppVersion!;
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
