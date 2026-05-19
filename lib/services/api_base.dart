import 'dart:io';

import 'package:flutter/foundation.dart';

const _cartlyPublicBaseUrl = 'https://scan-api.seoa-nas.com';

String _normalizedBase(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '' : trimmed.replaceAll(RegExp(r'/$'), '');
}

String getCartlyApiBaseUrl() {
  const remoteEnv = String.fromEnvironment(
    'CARTLY_REMOTE_BASE_URL',
    defaultValue: '',
  );
  final remoteBase = _normalizedBase(remoteEnv);
  if (remoteBase.isNotEmpty) {
    return remoteBase;
  }

  const appConfigEnv = String.fromEnvironment(
    'CARTLY_APP_CONFIG_BASE_URL',
    defaultValue: '',
  );
  final appConfigBase = _normalizedBase(appConfigEnv);
  if (appConfigBase.isNotEmpty) {
    return appConfigBase;
  }

  if (kReleaseMode) {
    return _cartlyPublicBaseUrl;
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8011';
  }
  return 'http://127.0.0.1:8011';
}
