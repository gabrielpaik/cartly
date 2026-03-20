class WimcRuntimeConfig {
  final bool useRemoteScan;
  final String remoteBaseUrl;
  final String? remoteAuthToken;

  const WimcRuntimeConfig({
    required this.useRemoteScan,
    required this.remoteBaseUrl,
    this.remoteAuthToken,
  });

  static const current = WimcRuntimeConfig(
    useRemoteScan: bool.fromEnvironment('WIMC_USE_REMOTE_SCAN', defaultValue: false),
    remoteBaseUrl: String.fromEnvironment(
      'WIMC_REMOTE_BASE_URL',
      defaultValue: 'http://YOUR-NAS-API:8000',
    ),
    remoteAuthToken: String.fromEnvironment('WIMC_REMOTE_AUTH_TOKEN', defaultValue: ''),
  );

  String get normalizedRemoteBaseUrl {
    final trimmed = remoteBaseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String? get effectiveRemoteAuthToken {
    final trimmed = remoteAuthToken?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
