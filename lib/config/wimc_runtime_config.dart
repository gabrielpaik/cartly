import '../services/api_base.dart';

class WimcRuntimeConfig {
  final String remoteBaseUrl;
  final String? remoteAuthToken;

  const WimcRuntimeConfig({required this.remoteBaseUrl, this.remoteAuthToken});

  static const current = WimcRuntimeConfig(
    remoteBaseUrl: String.fromEnvironment(
      'WIMC_REMOTE_BASE_URL',
      defaultValue: '',
    ),
    remoteAuthToken: String.fromEnvironment(
      'WIMC_REMOTE_AUTH_TOKEN',
      defaultValue: '',
    ),
  );

  String get normalizedRemoteBaseUrl {
    final trimmed = remoteBaseUrl.trim();
    final base = trimmed.isEmpty ? getWimcApiBaseUrl() : trimmed;
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
