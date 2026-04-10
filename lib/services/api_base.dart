import 'dart:io';

String getCartlyApiBaseUrl() {
  const cartlyEnv = String.fromEnvironment(
    'CARTLY_APP_CONFIG_BASE_URL',
    defaultValue: '',
  );
  if (cartlyEnv.trim().isNotEmpty) {
    return cartlyEnv.trim().replaceAll(RegExp(r'/$'), '');
  }

  const legacyEnv = String.fromEnvironment(
    'WIMC_APP_CONFIG_BASE_URL',
    defaultValue: '',
  );
  if (legacyEnv.trim().isNotEmpty) {
    return legacyEnv.trim().replaceAll(RegExp(r'/$'), '');
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8011';
  }
  return 'http://127.0.0.1:8011';
}
