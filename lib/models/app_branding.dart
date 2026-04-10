class AppBranding {
  final String logoType;
  final String logoText;
  final String? logoImageUrl;
  final String? splashImageUrl;
  final String? loginHeroImageUrl;
  final String homeTabLabel;
  final String savedTabLabel;
  final String myTabLabel;
  final String savedPageTitle;
  final String myPageTitle;
  final String homeSubtitle;
  final String savedSubtitle;
  final String mySubtitle;
  final String loginPageTitle;
  final String loginSubtitle;
  final String loginBenefitsTitle;
  final String loginBenefitsBody;
  final String savedEmptyTitle;
  final String savedEmptyBody;
  final String recentSavedTitle;
  final String recentSavedEmptyBody;
  final String myBenefitsTitle;
  final String myBenefitsBody;
  final String drawerGuestTitle;
  final String drawerGuestBody;
  final String saveCompleteTitle;
  final String saveCompleteSubtitle;

  const AppBranding({
    required this.logoType,
    required this.logoText,
    required this.logoImageUrl,
    required this.splashImageUrl,
    required this.loginHeroImageUrl,
    required this.homeTabLabel,
    required this.savedTabLabel,
    required this.myTabLabel,
    required this.savedPageTitle,
    required this.myPageTitle,
    required this.homeSubtitle,
    required this.savedSubtitle,
    required this.mySubtitle,
    required this.loginPageTitle,
    required this.loginSubtitle,
    required this.loginBenefitsTitle,
    required this.loginBenefitsBody,
    required this.savedEmptyTitle,
    required this.savedEmptyBody,
    required this.recentSavedTitle,
    required this.recentSavedEmptyBody,
    required this.myBenefitsTitle,
    required this.myBenefitsBody,
    required this.drawerGuestTitle,
    required this.drawerGuestBody,
    required this.saveCompleteTitle,
    required this.saveCompleteSubtitle,
  });

  static const fallback = AppBranding(
    logoType: 'text',
    logoText: 'Cartly',
    logoImageUrl: null,
    splashImageUrl: null,
    loginHeroImageUrl: null,
    homeTabLabel: 'Home',
    savedTabLabel: 'Saved',
    myTabLabel: 'My',
    savedPageTitle: 'Saved carts',
    myPageTitle: 'My account',
    homeSubtitle: '지금 카트 총액을 확인해',
    savedSubtitle: '저장한 카트를 다시 봐',
    mySubtitle: '기록을 남기려면 로그인',
    loginPageTitle: '계정 시작',
    loginSubtitle: '저장과 기록을 이어가려면 로그인',
    loginBenefitsTitle: '왜 계정을 만들까',
    loginBenefitsBody: '• 저장한 카트 보기\n• 다음 결제 전에 다시 확인\n• 더 저렴한 대안 추천',
    savedEmptyTitle: '아직 저장된 카트가 없어요',
    savedEmptyBody: 'Home에서 저장하면 여기서 다시 볼 수 있어.',
    recentSavedTitle: '최근 저장 카트',
    recentSavedEmptyBody: '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
    myBenefitsTitle: '계정이 있으면 좋은 점',
    myBenefitsBody: '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
    drawerGuestTitle: '아직 로그인하지 않았어요',
    drawerGuestBody: '저장한 카트와 스캔 기록을 이어가려면 로그인해.',
    saveCompleteTitle: '카트 저장 완료',
    saveCompleteSubtitle: '다음 결제 전에 다시 볼 수 있어',
  );

  factory AppBranding.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};

    String stringValue(String key, String fallbackValue) {
      final value = (data[key] as String?)?.trim();
      return value != null && value.isNotEmpty ? value : fallbackValue;
    }

    String? nullableStringValue(String key) {
      final value = (data[key] as String?)?.trim();
      return value != null && value.isNotEmpty ? value : null;
    }

    return AppBranding(
      logoType: stringValue('logoType', fallback.logoType),
      logoText: stringValue('logoText', fallback.logoText),
      logoImageUrl: nullableStringValue('logoImageUrl'),
      splashImageUrl: nullableStringValue('splashImageUrl'),
      loginHeroImageUrl: nullableStringValue('loginHeroImageUrl'),
      homeTabLabel: stringValue('homeTabLabel', fallback.homeTabLabel),
      savedTabLabel: stringValue('savedTabLabel', fallback.savedTabLabel),
      myTabLabel: stringValue('myTabLabel', fallback.myTabLabel),
      savedPageTitle: stringValue('savedPageTitle', fallback.savedPageTitle),
      myPageTitle: stringValue('myPageTitle', fallback.myPageTitle),
      homeSubtitle: stringValue('homeSubtitle', fallback.homeSubtitle),
      savedSubtitle: stringValue('savedSubtitle', fallback.savedSubtitle),
      mySubtitle: stringValue('mySubtitle', fallback.mySubtitle),
      loginPageTitle: stringValue('loginPageTitle', fallback.loginPageTitle),
      loginSubtitle: stringValue('loginSubtitle', fallback.loginSubtitle),
      loginBenefitsTitle: stringValue('loginBenefitsTitle', fallback.loginBenefitsTitle),
      loginBenefitsBody: stringValue('loginBenefitsBody', fallback.loginBenefitsBody),
      savedEmptyTitle: stringValue('savedEmptyTitle', fallback.savedEmptyTitle),
      savedEmptyBody: stringValue('savedEmptyBody', fallback.savedEmptyBody),
      recentSavedTitle: stringValue('recentSavedTitle', fallback.recentSavedTitle),
      recentSavedEmptyBody: stringValue('recentSavedEmptyBody', fallback.recentSavedEmptyBody),
      myBenefitsTitle: stringValue('myBenefitsTitle', fallback.myBenefitsTitle),
      myBenefitsBody: stringValue('myBenefitsBody', fallback.myBenefitsBody),
      drawerGuestTitle: stringValue('drawerGuestTitle', fallback.drawerGuestTitle),
      drawerGuestBody: stringValue('drawerGuestBody', fallback.drawerGuestBody),
      saveCompleteTitle: stringValue('saveCompleteTitle', fallback.saveCompleteTitle),
      saveCompleteSubtitle: stringValue('saveCompleteSubtitle', fallback.saveCompleteSubtitle),
    );
  }
}
