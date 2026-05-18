class AppBranding {
  static const defaultLogoImageUrl =
      'https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg';
  static const defaultSplashImageUrl =
      'https://scan-api.seoa-nas.com/assets/branding/cartly_splash_default.png';

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
    logoType: 'image',
    logoText: 'Cartly',
    logoImageUrl: defaultLogoImageUrl,
    splashImageUrl: defaultSplashImageUrl,
    loginHeroImageUrl: null,
    homeTabLabel: '홈',
    helpTabLabel: '탐색',
    myTabLabel: '마이페이지',
  );

  factory AppBranding.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    final fallback = AppBranding.fallback;
    final tabs = data['tabs'];
    final tabsMap = tabs is Map
        ? Map<String, dynamic>.from(tabs)
        : const <String, dynamic>{};

    String stringValue(String key, String fallbackValue) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return fallbackValue;
    }

    String nestedTabValue(String key, String legacyKey, String fallbackValue) {
      final nested = tabsMap[key];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
      return stringValue(legacyKey, fallbackValue);
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
      homeTabLabel: nestedTabValue(
        'home',
        'homeTabLabel',
        fallback.homeTabLabel,
      ),
      helpTabLabel: nestedTabValue(
        'help',
        'helpTabLabel',
        fallback.helpTabLabel,
      ),
      myTabLabel: nestedTabValue('my', 'myTabLabel', fallback.myTabLabel),
    );
  }
}
