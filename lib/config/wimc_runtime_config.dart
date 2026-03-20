class WimcRuntimeConfig {
  final bool useRemoteScan;
  final String remoteBaseUrl;

  const WimcRuntimeConfig({
    required this.useRemoteScan,
    required this.remoteBaseUrl,
  });

  static const current = WimcRuntimeConfig(
    useRemoteScan: false,
    remoteBaseUrl: 'http://YOUR-NAS-API:8000',
  );
}
