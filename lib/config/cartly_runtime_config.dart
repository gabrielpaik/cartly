import '../services/api_base.dart';

class CartlyRuntimeConfig {
  final String remoteBaseUrl;
  final String? remoteAuthToken;

  const CartlyRuntimeConfig({required this.remoteBaseUrl, this.remoteAuthToken});

  static const current = CartlyRuntimeConfig(
    remoteBaseUrl: String.fromEnvironment(
      'CARTLY_REMOTE_BASE_URL',
      defaultValue: String.fromEnvironment(
        'WIMC_REMOTE_BASE_URL',
        defaultValue: '',
      ),
    ),
    remoteAuthToken: String.fromEnvironment(
      'CARTLY_REMOTE_AUTH_TOKEN',
      defaultValue: String.fromEnvironment(
        'WIMC_REMOTE_AUTH_TOKEN',
        defaultValue: '',
      ),
    ),
  );

  String get normalizedRemoteBaseUrl {
    final trimmed = remoteBaseUrl.trim();
    final base = trimmed.isEmpty ? getCartlyApiBaseUrl() : trimmed;
    if (base.endsWith('/')) {
      return base.substring(0, base.length - 1);
    }
    return base;
  }

  String? get effectiveRemoteAuthToken {
    final trimmed = remoteAuthToken?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
