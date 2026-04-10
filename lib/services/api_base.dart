import 'dart:io';

String getWimcApiBaseUrl() {
  const env = String.fromEnvironment(
    'WIMC_APP_CONFIG_BASE_URL',
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
