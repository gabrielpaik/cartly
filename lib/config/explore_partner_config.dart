class ExplorePartnerConfig {
  final bool coupangPartnersEnabled;
  final String coupangBridgeBaseUrl;

  const ExplorePartnerConfig({
    required this.coupangPartnersEnabled,
    required this.coupangBridgeBaseUrl,
  });

  static const current = ExplorePartnerConfig(
    coupangPartnersEnabled: bool.fromEnvironment(
      'CARTLY_COUPANG_PARTNERS_ENABLED',
      defaultValue: false,
    ),
    coupangBridgeBaseUrl: String.fromEnvironment(
      'CARTLY_COUPANG_PARTNERS_BRIDGE_BASE_URL',
      defaultValue: '',
    ),
  );

  String? get normalizedBridgeBaseUrl {
    final trimmed = coupangBridgeBaseUrl.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}
