import json
from copy import deepcopy
from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

APP_COPY_KEY = 'app_copy'


DEFAULT_APP_COPY: Dict[str, Any] = {
    'common': {
        'save': '저장',
        'cancel': '취소',
        'edit': '수정',
        'done': '완료',
        'delete': '삭제',
        'retry': '다시 시도',
        'confirm': '확인',
        'loading': '불러오는 중...',
        'empty': '아직 데이터가 없어요',
    },
    'home': {
        'subtitle': '지금 담은 상품과 합계를 한눈에 확인해보세요',
        'recentScanTitle': '최근 스캔',
        'recentScanSubtitle': '방금 읽은 상품이에요',
        'addSectionTitle': '새 상품 추가',
        'addSectionSubtitle': '스캔하거나 직접 담아보세요',
        'currentCartTitle': '현재 카트',
        'currentCartSubtitle': '지금 담은 상품과 합계를 확인해보세요',
        'currentCartEmpty': '아직 담은 상품이 없어요',
        'addToCurrentCartDone': '현재 카트에 담았어요',
        'addToCurrentCartButton': '현재 카트에 담기',
        'saveCartButton': '카트 저장',
        'cartTotalLabel': '현재 카트 합계',
        'continueScanAction': '계속 스캔하기',
        'recentSavedAction': '지난 카트 보기',
        'exploreEntryTitle': '탐색에서 다음 판단 이어가기',
        'exploreEntryBody': '비교 후보와 대안을 한 번에 보고 결정해보세요',
    },
    'help': {
        'tabLabel': '탐색',
        'pageTitle': '탐색',
        'subtitle': '지금 필요한 비교만 모아 보여드릴게요',
    },
    'saved': {
        'pageTitle': '지난 카트',
        'subtitle': '저장한 장보기 기록을 다시 확인해보세요',
        'emptyTitle': '아직 저장된 카트가 없어요',
        'emptyBody': '홈에서 카트를 저장하면 여기서 다시 볼 수 있어요.',
        'recentTitle': '최근 저장한 카트',
        'recentEmptyBody': '아직 저장한 카트가 없어요. 카트를 저장하면 다음 장보기 전에 다시 꺼내보실 수 있어요.',
        'adFallbackTitle': '함께 보면 좋은 혜택',
        'adFallbackMessage': '지난 카트를 다시 보는 흐름을 해치지 않는 선에서 꼭 맞는 혜택만 보여드릴게요.',
        'adSecondaryFallbackTitle': '비슷한 상품 혜택',
        'adSecondaryFallbackMessage': '기록을 보는 흐름은 그대로 두고, 필요한 혜택만 가볍게 보여드릴게요.',
    },
    'my': {
        'pageTitle': '마이',
        'subtitle': '계정과 지난 카트를 한곳에서 관리해보세요',
        'benefitsTitle': '계정을 연결하면 이런 점이 좋아요',
        'benefitsBody': '• 지난 카트를 계속 보실 수 있어요\n• 최근 스캔 결과를 이어서 확인하실 수 있어요\n• 다음 장보기 전에 다시 비교하실 수 있어요',
        'memberBody': '계정 정보와 지난 장보기 기록을 여기서 함께 관리하실 수 있어요.',
        'guestTitle': '아직 로그인하지 않으셨어요',
        'guestBody': '저장한 카트와 스캔 기록을 이어서 보시려면 로그인해 주세요.',
        'guestModeLabel': '게스트로 사용 중이에요',
        'guestSignupAction': '회원가입하기',
        'loginAction': '로그인 / 회원가입',
        'logoutAction': '로그아웃',
        'linkedDoneMessage': '계정이 연결되었어요',
        'logoutDoneMessage': '로그아웃되었어요',
        'savedSectionTitle': '지난 카트',
        'savedSectionMemberSubtitle': '저장해둔 지난 카트를 여기서 다시 확인해보세요',
        'savedSectionGuestSubtitle': '게스트로 저장한 카트도 여기서 함께 확인하실 수 있어요',
        'adFallbackTitle': '회원 전용 혜택 준비 중',
        'adFallbackMessage': '마이에서는 계정과 잘 맞는 혜택만 보여드릴 예정이에요.',
        'complianceTitle': '개인정보 및 문의',
        'complianceBody': '개인정보 처리방침과 문의 이메일을 여기서 바로 확인하실 수 있어요.',
        'privacyPolicyLabel': '개인정보 처리방침',
        'privacyPolicyUrl': 'https://scan-api.seoa-nas.com/privacy',
        'supportEmailLabel': '문의 이메일',
        'supportEmail': '',
        'supportPhoneLabel': '고객센터 연락처',
        'supportPhone': '',
        'supportHoursLabel': '응답 안내',
        'supportHours': '',
        'businessInfoLabel': '운영 정보',
        'businessInfo': '',
        'supportNote': '문의는 아래 이메일로 보내주세요.',
    },
    'login': {
        'pageTitle': '로그인',
        'subtitle': '저장한 카트와 스캔 기록을 이어서 보시려면 로그인해 주세요',
        'benefitsTitle': '로그인하면 더 편해져요',
        'benefitsBody': '• 저장한 카트를 계속 보실 수 있어요\n• 다음 장보기 전에 다시 확인하실 수 있어요\n• 더 나은 대안을 비교해보실 수 있어요',
        'mode': {
            'login': '로그인',
            'signup': '회원가입',
            'reset': '비밀번호 찾기',
        },
        'nameFieldLabel': '이름',
        'emailFieldLabel': '이메일',
        'emailLocalFieldLabel': '이메일 아이디',
        'emailDomainFieldLabel': '도메인',
        'emailCustomDomainOption': '직접입력',
        'emailCustomDomainFieldLabel': '직접 입력 도메인',
        'passwordFieldLabel': '비밀번호',
        'passwordConfirmFieldLabel': '비밀번호 확인',
        'codeFieldLabel': '인증 코드',
        'forgotPasswordAction': '비밀번호를 잊으셨나요?',
        'invalidPasswordMessage': '비밀번호를 확인해 주세요',
        'existingEmailTitle': '이미 가입된 이메일입니다',
        'existingEmailBody': '이미 가입된 이메일입니다. 로그인하시거나 비밀번호를 재설정해 주세요.',
        'existingEmailLoginAction': '로그인하기',
        'existingEmailResetAction': '비밀번호 재설정',
        'forgotPasswordPromptTitle': '비밀번호를 잊으셨나요?',
        'forgotPasswordPromptBody': '비밀번호 입력을 여러 번 실패했습니다. 비밀번호 재설정으로 이동하시겠어요?',
        'forgotPasswordPromptStay': '다시 입력하기',
        'forgotPasswordPromptReset': '비밀번호 재설정',
        'sendingCode': '전송 중입니다...',
        'resendCode': '재전송',
        'sendCode': '코드 전송',
        'submitting': '처리 중입니다...',
        'continueAsGuest': '게스트로 계속하기',
        'login': {
            'submit': '로그인',
        },
        'signup': {
            'submit': '회원가입 완료',
            'codeSent': '이메일 인증 코드를 보내드렸습니다',
            'codeVerified': '이메일 인증이 완료되었습니다',
            'verifyCodeAction': '인증 코드 확인',
            'verifyingCode': '인증 확인 중입니다...',
            'verifiedBadge': '인증 완료',
        },
        'reset': {
            'newPasswordLabel': '새 비밀번호',
            'submit': '비밀번호 재설정',
            'codeSent': '비밀번호 재설정 코드를 보내드렸습니다',
            'backToLogin': '로그인으로 돌아가기',
        },
        'validation': {
            'emailRequired': '이메일을 입력해 주세요',
            'emailPasswordRequired': '이메일과 비밀번호를 입력해 주세요',
            'signupFieldsRequired': '이름과 인증 코드를 모두 입력해 주세요',
            'nameRequired': '이름을 입력해 주세요',
            'signupCodeVerifyRequired': '이메일 인증을 먼저 완료해 주세요',
            'passwordTooShort': '비밀번호는 8자 이상이어야 합니다',
            'passwordMismatch': '비밀번호 확인이 일치하지 않습니다',
            'codeRequired': '인증 코드를 입력해 주세요',
        },
    },
    'saveComplete': {
        'title': '카트를 저장했어요',
        'subtitle': '다음 장보기 때 다시 꺼내보실 수 있어요',
        'adFallbackTitle': '더 나은 대안 보기',
        'adFallbackMessage': '결제 전에 가볍게 비교해보실 수 있는 선택지를 보여드릴게요.',
    },
    'receiptCompare': {
        'contextBody': '영수증과 저장한 카트를 나란히 확인해보세요.',
        'entryAction': '영수증 비교하기',
        'savedCartOnlyBadge': '저장 카트 전용',
    },
    'publicSite': {
        'eyebrow': 'Cartly · private beta',
        'heroTitle': '장보기를 기록하고, 같은 구매 의도 안에서 더 나은 선택을 찾는 앱',
        'heroBody': 'Cartly는 스캔, 현재 카트, 저장된 장보기 기록을 바탕으로 사용자가 이미 사려던 상품과 같은 의도의 대체안을 다시 검토할 수 있게 도와줍니다.',
        'primaryCtaLabel': '작동 방식 보기',
        'secondaryCtaLabel': '개인정보 안내',
        'heroPoints': '상품 스캔 및 검토\n현재 카트와 저장된 장보기 기록 관리\n같은 구매 의도(same-intent) 기준 대체안 탐색\n사용자 탭 이후에만 외부 파트너 링크 열기',
        'enabledSections': 'hero,flow,status,partnerReview,linkPlacement',
        'sectionOrder': 'hero,flow,status,partnerReview,linkPlacement',
        'flowTitle': '사용자 흐름',
        'flowBody': '아래 흐름은 실제 앱에서 파트너 오퍼가 어떻게 맥락 안에서 노출되는지 설명하기 위한 개요입니다.',
        'statusTitle': '현재 운영 상태',
        'statusPoints': 'iOS private beta(TestFlight) 운영 중\nOCR 스캔, 카트 저장, 반복 구매 맥락 정리 기능 포함\nExplore 탭은 same-intent alternative 중심으로 고도화 중',
        'partnerReviewTitle': '파트너 검토 참고',
        'partnerReviewPoints': '무작위 광고 피드가 아니라 장보기 의사결정 보조 흐름 안에 배치됩니다.\n사용자 액션 없이 외부 링크를 자동 실행하지 않습니다.\n제품 맥락과 구매 의도를 유지하는 대체안만 다룹니다.',
        'linkPlacementTitle': '파트너 링크가 붙는 위치',
        'linkPlacementBody': 'Cartly는 무관한 크로스셀 피드 대신, 사용자가 이미 사려던 상품과 같은 구매 의도를 유지하는 대체안만 Explore 영역에서 보여주도록 설계되어 있습니다.',
        'linkPlacementPoints': '최근 스캔 후 아직 확정하지 않은 상품\n현재 카트에 담긴 핵심 구매 후보\n반복 구매 가능성이 높은 저장 카트 품목',
        'privacyTitle': '개인정보 및 외부 링크 안내',
        'privacyIntro': 'Cartly는 사용자가 직접 추가하거나 스캔한 장보기 상품 정보를 바탕으로 현재 카트, 저장된 장보기 기록, 그리고 같은 구매 의도를 유지하는 대체안 탐색 흐름을 제공합니다.',
        'privacyCollectionTitle': '수집 및 사용',
        'privacyCollectionPoints': '상품명, 가격, 수량, 저장 카트 제목 등 장보기 기록\n스캔 기능 사용 시 업로드한 이미지와 인식 결과\n앱 기능 개선과 사용자 경험 향상을 위한 최소 운영 로그',
        'privacyExternalTitle': '외부 링크',
        'privacyExternalBody': '외부 쇼핑 링크는 사용자가 Explore 영역에서 특정 대체안을 선택했을 때만 열립니다. 자동 리디렉션이나 무관한 광고성 이동을 기본 동작으로 사용하지 않습니다.',
        'privacyStatusTitle': '현재 상태',
        'privacyStatusBody': 'Cartly는 현재 private beta 단계에서 제품 흐름을 다듬고 있습니다. 파트너 링크는 같은 구매 의도 안에서의 대체안 검토를 돕는 용도로만 사용됩니다.',
        'privacyBackAction': '메인 페이지로 돌아가기',
    },
    'cartDetail': {
        'titleSuffix': '카트',
        'edit': '수정',
        'done': '완료',
        'deleteDialogTitle': '이 카트를 삭제할까요?',
        'deleteDialogBody': '삭제하면 되돌릴 수 없어요.',
        'deleteConfirm': '삭제',
        'deleteCancel': '취소',
        'empty': '카트가 비었어요',
        'itemAdded': '상품을 추가했어요',
        'savedSnapshotDone': '새 저장본으로 기록했어요',
        'nameLabel': '상품명',
        'priceLabel': '가격',
        'apply': '적용',
        'totalLabel': '총 합계',
        'saveButton': '저장하기',
        'saving': '저장 중…',
        'validation': {
            'namePriceRequired': '상품명/가격을 확인해주세요',
            'nameRequired': '상품명이 비어있어요',
            'priceQuantityRequired': '가격/수량을 확인해주세요',
        },
    },
    'scan': {
        'captureButton': '가격표 인식하기',
        'uploadButton': '이미지 파일을 업로드 하세요',
        'manualAddAction': '직접 추가하기',
        'recognizedTitle': '인식 결과',
        'manualAddTitle': '직접 추가하기',
        'cameraFallbackMac': 'macOS에선 현재 실시간 카메라 스캔 대신 이미지 파일 업로드로 OCR을 진행해.',
        'cameraFallbackWindows': 'Windows에선 현재 실시간 카메라 스캔 대신 이미지 파일 업로드로 OCR을 진행해.',
        'cameraFallbackLinux': 'Linux에선 현재 실시간 카메라 스캔 대신 이미지 파일 업로드로 OCR을 진행해.',
        'cameraFallbackDefault': '카메라를 지금 사용할 수 없어. 이미지 파일 업로드로 OCR을 진행해.',
        'uploading': '업로드 중...',
        'queued': '대기 중...',
        'processing': '분석 중...',
        'resultPreparing': '결과 정리 중...',
        'failed': '인식에 실패했어요',
        'timeout': '분석이 조금 지연되고 있어요. 잠시 후 다시 시도해봐요',
        'resultEmpty': '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요',
        'processingError': '분석 처리 중 오류가 났어요',
        'retakeAction': '다시 찍기',
        'recognizeAction': '인식',
        'recognizing': '인식 중...',
        'cameraPreparing': '카메라 준비 중...',
        'sourceLabel': 'source',
        'skuLabel': 'sku',
        'rawTextPrefix': '원문',
        'priceHint': '가격(숫자)',
        'confidence': {
            'high': '신뢰 높음',
            'medium': '확인 권장',
            'low': '확인 필요',
            'none': '신뢰도 없음',
        },
        'review': {
            'default': '인식 결과를 확인한 뒤 카트에 담아주세요.',
            'high': '신뢰도가 높은 결과예요. 빠르게 확인하고 담아주세요.',
            'medium': '한 번 확인하고 담는 걸 권장해요.',
            'low': '확인 필요 결과예요. 수정하거나 다시 찍는 게 좋아요.',
        },
        'validation': {
            'invalidImagePath': '선택한 파일 경로를 읽지 못했어요',
            'namePriceRequired': '상품명/가격을 확인해주세요',
            'captureFailed': '촬영/OCR에 실패했어요. 다시 시도해 주세요',
        },
    },
}


BRANDING_COPY_FIELD_MAP = {
    ('home', 'pageTitle'): 'homePageTitle',
    ('home', 'subtitle'): 'homeSubtitle',
    ('home', 'recentScanTitle'): 'homeRecentScanTitle',
    ('home', 'recentScanSubtitle'): 'homeRecentScanSubtitle',
    ('home', 'addSectionTitle'): 'homeAddSectionTitle',
    ('home', 'addSectionSubtitle'): 'homeAddSectionSubtitle',
    ('home', 'currentCartTitle'): 'homeCurrentCartTitle',
    ('home', 'currentCartSubtitle'): 'homeCurrentCartSubtitle',
    ('home', 'currentCartEmpty'): 'homeCurrentCartEmpty',
    ('home', 'addToCurrentCartDone'): 'homeAddToCurrentCartDone',
    ('home', 'addToCurrentCartButton'): 'homeAddToCurrentCartButton',
    ('home', 'saveCartButton'): 'homeSaveCartButton',
    ('home', 'cartTotalLabel'): 'homeCartTotalLabel',
    ('home', 'continueScanAction'): 'homeContinueScanAction',
    ('home', 'recentSavedAction'): 'homeRecentSavedAction',
    ('home', 'exploreEntryTitle'): 'homeExploreEntryTitle',
    ('home', 'exploreEntryBody'): 'homeExploreEntryBody',
    ('help', 'tabLabel'): 'helpTabLabel',
    ('help', 'pageTitle'): 'helpPageTitle',
    ('help', 'subtitle'): 'helpSubtitle',
    ('saved', 'pageTitle'): 'savedPageTitle',
    ('saved', 'subtitle'): 'savedSubtitle',
    ('saved', 'emptyTitle'): 'savedEmptyTitle',
    ('saved', 'emptyBody'): 'savedEmptyBody',
    ('saved', 'recentTitle'): 'recentSavedTitle',
    ('saved', 'recentEmptyBody'): 'recentSavedEmptyBody',
    ('saved', 'adFallbackTitle'): 'savedAdFallbackTitle',
    ('saved', 'adFallbackMessage'): 'savedAdFallbackMessage',
    ('saved', 'adSecondaryFallbackTitle'): 'savedAdSecondaryFallbackTitle',
    ('saved', 'adSecondaryFallbackMessage'): 'savedAdSecondaryFallbackMessage',
    ('my', 'pageTitle'): 'myPageTitle',
    ('my', 'subtitle'): 'mySubtitle',
    ('my', 'benefitsTitle'): 'myBenefitsTitle',
    ('my', 'benefitsBody'): 'myBenefitsBody',
    ('my', 'memberBody'): 'myMemberBody',
    ('my', 'guestModeLabel'): 'myGuestModeLabel',
    ('my', 'guestSignupAction'): 'myGuestSignupAction',
    ('my', 'loginAction'): 'myLoginAction',
    ('my', 'logoutAction'): 'myLogoutAction',
    ('my', 'linkedDoneMessage'): 'myLinkedDoneMessage',
    ('my', 'logoutDoneMessage'): 'myLogoutDoneMessage',
    ('my', 'savedSectionTitle'): 'mySavedSectionTitle',
    ('my', 'savedSectionMemberSubtitle'): 'mySavedSectionMemberSubtitle',
    ('my', 'savedSectionGuestSubtitle'): 'mySavedSectionGuestSubtitle',
    ('my', 'adFallbackTitle'): 'myAdFallbackTitle',
    ('my', 'adFallbackMessage'): 'myAdFallbackMessage',
    ('my', 'complianceTitle'): 'myComplianceTitle',
    ('my', 'complianceBody'): 'myComplianceBody',
    ('my', 'privacyPolicyLabel'): 'myPrivacyPolicyLabel',
    ('my', 'privacyPolicyUrl'): 'myPrivacyPolicyUrl',
    ('my', 'supportEmailLabel'): 'mySupportEmailLabel',
    ('my', 'supportEmail'): 'mySupportEmail',
    ('my', 'supportPhoneLabel'): 'mySupportPhoneLabel',
    ('my', 'supportPhone'): 'mySupportPhone',
    ('my', 'supportHoursLabel'): 'mySupportHoursLabel',
    ('my', 'supportHours'): 'mySupportHours',
    ('my', 'businessInfoLabel'): 'myBusinessInfoLabel',
    ('my', 'businessInfo'): 'myBusinessInfo',
    ('my', 'supportNote'): 'mySupportNote',
    ('my', 'guestTitle'): 'drawerGuestTitle',
    ('my', 'guestBody'): 'drawerGuestBody',
    ('login', 'pageTitle'): 'loginPageTitle',
    ('login', 'subtitle'): 'loginSubtitle',
    ('login', 'benefitsTitle'): 'loginBenefitsTitle',
    ('login', 'benefitsBody'): 'loginBenefitsBody',
    ('login', 'nameFieldLabel'): 'loginNameFieldLabel',
    ('login', 'emailFieldLabel'): 'loginEmailFieldLabel',
    ('login', 'emailLocalFieldLabel'): 'loginEmailLocalFieldLabel',
    ('login', 'emailDomainFieldLabel'): 'loginEmailDomainFieldLabel',
    ('login', 'emailCustomDomainOption'): 'loginEmailCustomDomainOption',
    ('login', 'emailCustomDomainFieldLabel'): 'loginEmailCustomDomainFieldLabel',
    ('login', 'passwordFieldLabel'): 'loginPasswordFieldLabel',
    ('login', 'passwordConfirmFieldLabel'): 'loginPasswordConfirmFieldLabel',
    ('login', 'codeFieldLabel'): 'loginCodeFieldLabel',
    ('login', 'forgotPasswordAction'): 'loginForgotPasswordAction',
    ('login', 'invalidPasswordMessage'): 'loginInvalidPasswordMessage',
    ('login', 'existingEmailTitle'): 'loginExistingEmailTitle',
    ('login', 'existingEmailBody'): 'loginExistingEmailBody',
    ('login', 'existingEmailLoginAction'): 'loginExistingEmailLoginAction',
    ('login', 'existingEmailResetAction'): 'loginExistingEmailResetAction',
    ('login', 'forgotPasswordPromptTitle'): 'loginForgotPasswordPromptTitle',
    ('login', 'forgotPasswordPromptBody'): 'loginForgotPasswordPromptBody',
    ('login', 'forgotPasswordPromptStay'): 'loginForgotPasswordPromptStay',
    ('login', 'forgotPasswordPromptReset'): 'loginForgotPasswordPromptReset',
    ('login', 'sendingCode'): 'loginSendingCode',
    ('login', 'resendCode'): 'loginResendCode',
    ('login', 'sendCode'): 'loginSendCode',
    ('login', 'submitting'): 'loginSubmitting',
    ('login', 'continueAsGuest'): 'loginContinueAsGuest',
    ('login', 'mode.login'): 'loginModeLogin',
    ('login', 'mode.signup'): 'loginModeSignup',
    ('login', 'mode.reset'): 'loginModeReset',
    ('login', 'login.submit'): 'loginLoginSubmit',
    ('login', 'signup.submit'): 'loginSignupSubmit',
    ('login', 'signup.codeSent'): 'loginSignupCodeSent',
    ('login', 'signup.codeVerified'): 'loginSignupCodeVerified',
    ('login', 'signup.verifyCodeAction'): 'loginSignupVerifyCodeAction',
    ('login', 'signup.verifyingCode'): 'loginSignupVerifyingCode',
    ('login', 'signup.verifiedBadge'): 'loginSignupVerifiedBadge',
    ('login', 'reset.newPasswordLabel'): 'loginNewPasswordLabel',
    ('login', 'reset.submit'): 'loginResetSubmit',
    ('login', 'reset.codeSent'): 'loginResetCodeSent',
    ('login', 'reset.backToLogin'): 'loginResetBackToLogin',
    ('login', 'validation.emailRequired'): 'loginValidationEmailRequired',
    ('login', 'validation.emailPasswordRequired'): 'loginValidationEmailPasswordRequired',
    ('login', 'validation.signupFieldsRequired'): 'loginValidationSignupFieldsRequired',
    ('login', 'validation.nameRequired'): 'loginValidationNameRequired',
    ('login', 'validation.signupCodeVerifyRequired'): 'loginValidationSignupCodeVerifyRequired',
    ('login', 'validation.passwordTooShort'): 'loginValidationPasswordTooShort',
    ('login', 'validation.passwordMismatch'): 'loginValidationPasswordMismatch',
    ('login', 'validation.codeRequired'): 'loginValidationCodeRequired',
    ('saveComplete', 'title'): 'saveCompleteTitle',
    ('saveComplete', 'subtitle'): 'saveCompleteSubtitle',
    ('saveComplete', 'adFallbackTitle'): 'saveCompleteAdFallbackTitle',
    ('saveComplete', 'adFallbackMessage'): 'saveCompleteAdFallbackMessage',
    ('saveComplete', 'viewSavedAction'): 'saveCompleteViewSavedAction',
    ('common', 'cancel'): 'commonCancel',
    ('common', 'confirm'): 'commonConfirm',
    ('common', 'edit'): 'commonEdit',
    ('common', 'loading'): 'commonLoading',
    ('cartDetail', 'titleSuffix'): 'cartDetailTitleSuffix',
    ('cartDetail', 'edit'): 'cartDetailEdit',
    ('cartDetail', 'done'): 'cartDetailDone',
    ('cartDetail', 'deleteDialogTitle'): 'cartDetailDeleteDialogTitle',
    ('cartDetail', 'deleteDialogBody'): 'cartDetailDeleteDialogBody',
    ('cartDetail', 'deleteConfirm'): 'cartDetailDeleteConfirm',
    ('cartDetail', 'deleteCancel'): 'cartDetailDeleteCancel',
    ('cartDetail', 'empty'): 'cartDetailEmpty',
    ('cartDetail', 'itemAdded'): 'cartDetailItemAdded',
    ('cartDetail', 'savedSnapshotDone'): 'cartDetailSavedSnapshotDone',
    ('cartDetail', 'nameLabel'): 'cartDetailNameLabel',
    ('cartDetail', 'priceLabel'): 'cartDetailPriceLabel',
    ('cartDetail', 'apply'): 'cartDetailApply',
    ('cartDetail', 'totalLabel'): 'cartDetailTotalLabel',
    ('cartDetail', 'saveButton'): 'cartDetailSaveButton',
    ('cartDetail', 'saving'): 'cartDetailSaving',
    ('cartDetail', 'validation.namePriceRequired'): 'cartDetailValidationNamePriceRequired',
    ('cartDetail', 'validation.nameRequired'): 'cartDetailValidationNameRequired',
    ('cartDetail', 'validation.priceQuantityRequired'): 'cartDetailValidationPriceQuantityRequired',
    ('receiptCompare', 'contextBody'): 'receiptCompareContextBody',
    ('receiptCompare', 'entryAction'): 'receiptCompareEntryAction',
    ('receiptCompare', 'savedCartOnlyBadge'): 'receiptCompareSavedCartOnlyBadge',
    ('publicSite', 'eyebrow'): 'publicSiteEyebrow',
    ('publicSite', 'heroTitle'): 'publicSiteHeroTitle',
    ('publicSite', 'heroBody'): 'publicSiteHeroBody',
    ('publicSite', 'primaryCtaLabel'): 'publicSitePrimaryCtaLabel',
    ('publicSite', 'secondaryCtaLabel'): 'publicSiteSecondaryCtaLabel',
    ('publicSite', 'heroPoints'): 'publicSiteHeroPoints',
    ('publicSite', 'enabledSections'): 'publicSiteEnabledSections',
    ('publicSite', 'sectionOrder'): 'publicSiteSectionOrder',
    ('publicSite', 'flowTitle'): 'publicSiteFlowTitle',
    ('publicSite', 'flowBody'): 'publicSiteFlowBody',
    ('publicSite', 'statusTitle'): 'publicSiteStatusTitle',
    ('publicSite', 'statusPoints'): 'publicSiteStatusPoints',
    ('publicSite', 'partnerReviewTitle'): 'publicSitePartnerReviewTitle',
    ('publicSite', 'partnerReviewPoints'): 'publicSitePartnerReviewPoints',
    ('publicSite', 'linkPlacementTitle'): 'publicSiteLinkPlacementTitle',
    ('publicSite', 'linkPlacementBody'): 'publicSiteLinkPlacementBody',
    ('publicSite', 'linkPlacementPoints'): 'publicSiteLinkPlacementPoints',
    ('publicSite', 'privacyTitle'): 'publicSitePrivacyTitle',
    ('publicSite', 'privacyIntro'): 'publicSitePrivacyIntro',
    ('publicSite', 'privacyCollectionTitle'): 'publicSitePrivacyCollectionTitle',
    ('publicSite', 'privacyCollectionPoints'): 'publicSitePrivacyCollectionPoints',
    ('publicSite', 'privacyExternalTitle'): 'publicSitePrivacyExternalTitle',
    ('publicSite', 'privacyExternalBody'): 'publicSitePrivacyExternalBody',
    ('publicSite', 'privacyStatusTitle'): 'publicSitePrivacyStatusTitle',
    ('publicSite', 'privacyStatusBody'): 'publicSitePrivacyStatusBody',
    ('publicSite', 'privacyBackAction'): 'publicSitePrivacyBackAction',
    ('scan', 'captureButton'): 'scanCaptureButton',
    ('scan', 'uploadButton'): 'scanUploadButton',
    ('scan', 'manualAddAction'): 'scanManualAddAction',
    ('scan', 'recognizedTitle'): 'scanRecognizedTitle',
    ('scan', 'manualAddTitle'): 'scanManualAddTitle',
    ('scan', 'uploading'): 'scanUploading',
    ('scan', 'queued'): 'scanQueued',
    ('scan', 'processing'): 'scanProcessing',
    ('scan', 'resultPreparing'): 'scanResultPreparing',
    ('scan', 'failed'): 'scanFailed',
    ('scan', 'timeout'): 'scanTimeout',
    ('scan', 'resultEmpty'): 'scanResultEmpty',
    ('scan', 'processingError'): 'scanProcessingError',
    ('scan', 'retakeAction'): 'scanRetakeAction',
    ('scan', 'recognizeAction'): 'scanRecognizeAction',
    ('scan', 'recognizing'): 'scanRecognizing',
}


def _deep_merge(base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
    result = deepcopy(base)
    for key, value in (override or {}).items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = value
    return result



def _normalize_copy(payload: Dict[str, Any]) -> Dict[str, Any]:
    return _deep_merge(DEFAULT_APP_COPY, payload or {})



def _set_nested_value(target: Dict[str, Any], path: str, value: Any) -> None:
    keys = path.split('.')
    node = target
    for key in keys[:-1]:
        child = node.get(key)
        if not isinstance(child, dict):
            child = {}
            node[key] = child
        node = child
    node[keys[-1]] = value



def _copy_from_branding(branding: Dict[str, Any]) -> Dict[str, Any]:
    result = deepcopy(DEFAULT_APP_COPY)
    for (section, field), branding_key in BRANDING_COPY_FIELD_MAP.items():
        value = branding.get(branding_key)
        if isinstance(value, str) and value.strip():
            section_node = result.setdefault(section, {})
            if not isinstance(section_node, dict):
                section_node = {}
                result[section] = section_node
            _set_nested_value(section_node, field, value)
    return result



def get_app_copy(db: OrmSession, branding: Dict[str, Any]) -> Dict[str, Any]:
    fallback = _copy_from_branding(branding)
    row = db.get(AppSetting, APP_COPY_KEY)
    if row is None:
        return fallback
    try:
        payload = json.loads(row.value_json or '{}') or {}
    except Exception:
        return fallback
    if not isinstance(payload, dict):
        return fallback
    return _deep_merge(fallback, payload)


COPY_FIELD_TO_PATH = {
    branding_key: (section, *field.split('.'))
    for (section, field), branding_key in BRANDING_COPY_FIELD_MAP.items()
}
COPY_FIELD_KEYS = frozenset(COPY_FIELD_TO_PATH.keys())


def _read_nested_value(source: Dict[str, Any], path: tuple[str, ...]) -> Any:
    node: Any = source
    for key in path:
        if not isinstance(node, dict):
            return None
        node = node.get(key)
    return node


def flatten_app_copy(payload: Dict[str, Any]) -> Dict[str, Any]:
    flat: Dict[str, Any] = {}
    for field_key, path in COPY_FIELD_TO_PATH.items():
        value = _read_nested_value(payload, path)
        if value is not None:
            flat[field_key] = value
    return flat


def save_app_copy(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    normalized = _normalize_copy(payload)
    row = db.get(AppSetting, APP_COPY_KEY)
    if row is None:
        row = AppSetting(
            key=APP_COPY_KEY,
            value_json=json.dumps(normalized, ensure_ascii=False),
        )
        db.add(row)
    else:
        row.value_json = json.dumps(normalized, ensure_ascii=False)
        db.add(row)
    db.commit()
    db.refresh(row)
    return normalized


def save_flat_app_copy(
    db: OrmSession,
    flat_payload: Dict[str, Any],
    *,
    branding: Dict[str, Any],
) -> Dict[str, Any]:
    current = get_app_copy(db, branding)
    merged = deepcopy(current)
    for field_key, path in COPY_FIELD_TO_PATH.items():
        if field_key not in flat_payload:
            continue
        _set_nested_value(merged, '.'.join(path), flat_payload[field_key])
    return save_app_copy(db, merged)
