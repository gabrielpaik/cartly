class AppBranding {
  final String logoType;
  final String logoText;
  final String? logoImageUrl;
  final String? splashImageUrl;
  final String? loginHeroImageUrl;
  final String homeTabLabel;
  final String helpTabLabel;
  final String myTabLabel;

  const AppBranding({
    required this.logoType,
    required this.logoText,
    this.logoImageUrl,
    this.splashImageUrl,
    this.loginHeroImageUrl,
    required this.homeTabLabel,
    required this.helpTabLabel,
    required this.myTabLabel,
  });

  static const fallback = AppBranding(
    logoType: 'text',
    logoText: 'Cartly',
    logoImageUrl: null,
    splashImageUrl: null,
    loginHeroImageUrl: null,
    homeTabLabel: 'Home',
    helpTabLabel: '도움',
    myTabLabel: 'My',
  );

  factory AppBranding.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    final fallback = AppBranding.fallback;

    String stringValue(String key, String fallbackValue) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return fallbackValue;
    }

    String? nullableString(String key) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return null;
    }

    return AppBranding(
      logoType: stringValue('logoType', fallback.logoType),
      logoText: stringValue('logoText', fallback.logoText),
      logoImageUrl: nullableString('logoImageUrl'),
      splashImageUrl: nullableString('splashImageUrl'),
      loginHeroImageUrl: nullableString('loginHeroImageUrl'),
      homeTabLabel: stringValue('homeTabLabel', fallback.homeTabLabel),
      helpTabLabel: stringValue('helpTabLabel', fallback.helpTabLabel),
      myTabLabel: stringValue('myTabLabel', fallback.myTabLabel),
    );
  }
}
