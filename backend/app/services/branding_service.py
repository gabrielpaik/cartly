import json
from datetime import datetime
from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

DEFAULT_BRANDING: Dict[str, Any] = {
    'logoType': 'text',
    'logoText': 'Cartly',
    'logoImageUrl': None,
    'splashImageUrl': None,
    'loginHeroImageUrl': None,
    'homeTabLabel': 'Home',
    'helpTabLabel': '도움',
    'savedTabLabel': 'Saved',
    'myTabLabel': 'My',
    'homePageTitle': 'Cartly',
    'helpPageTitle': 'Shopping help',
    'savedPageTitle': 'Saved carts',
    'myPageTitle': 'My account',
    'homeSubtitle': '지금 카트 총액을 확인해',
    'helpSubtitle': '운영 부담이 큰 피드형 쇼핑 탭 대신, 정말 도움이 되는 기능부터 붙일 예정이야',
    'homeRecentScanTitle': '최근 스캔',
    'homeRecentScanSubtitle': '방금 읽은 결과',
    'homeAddSectionTitle': '새 상품 추가',
    'homeAddSectionSubtitle': '스캔하거나 바로 담기',
    'homeCurrentCartTitle': '현재 카트',
    'homeCurrentCartSubtitle': '결제 전 합계를 확인해',
    'homeCurrentCartEmpty': '아직 담은 상품이 없어요',
    'homeAddToCurrentCartDone': '현재 카트에 담았어요',
    'homeAddToCurrentCartButton': '현재 카트에 담기',
    'homeSaveCartButton': '카트 저장',
    'homeCartTotalLabel': '현재 카트 합계',
    'homeContinueScanAction': '계속 스캔하기',
    'homeRecentSavedAction': 'Saved 보기',
    'savedSubtitle': '저장한 카트를 다시 봐',
    'mySubtitle': '기록을 남기려면 로그인',
    'loginPageTitle': '계정 시작',
    'loginSubtitle': '저장과 기록을 이어가려면 로그인',
    'loginBenefitsTitle': '왜 계정을 만들까요',
    'loginBenefitsBody': '• 저장한 카트를 볼 수 있습니다\n• 다음 결제 전에 다시 확인할 수 있습니다\n• 더 저렴한 대안을 추천받을 수 있습니다',
    'loginModeLogin': '로그인',
    'loginModeSignup': '회원가입',
    'loginModeReset': '비밀번호 찾기',
    'loginNameFieldLabel': '이름',
    'loginEmailFieldLabel': '이메일',
    'loginEmailLocalFieldLabel': '이메일 아이디',
    'loginEmailDomainFieldLabel': '도메인',
    'loginEmailCustomDomainOption': '직접입력',
    'loginEmailCustomDomainFieldLabel': '직접 입력 도메인',
    'loginPasswordFieldLabel': '비밀번호',
    'loginPasswordConfirmFieldLabel': '비밀번호 확인',
    'loginCodeFieldLabel': '인증 코드',
    'loginForgotPasswordAction': '비밀번호를 잊으셨나요?',
    'loginInvalidPasswordMessage': '비밀번호를 확인해 주세요',
    'loginExistingEmailTitle': '이미 가입된 이메일입니다',
    'loginExistingEmailBody': '이미 가입된 이메일입니다. 로그인하시거나 비밀번호를 재설정해 주세요.',
    'loginExistingEmailLoginAction': '로그인하기',
    'loginExistingEmailResetAction': '비밀번호 재설정',
    'loginForgotPasswordPromptTitle': '비밀번호를 잊으셨나요?',
    'loginForgotPasswordPromptBody': '비밀번호 입력을 여러 번 실패했습니다. 비밀번호 재설정으로 이동하시겠어요?',
    'loginForgotPasswordPromptStay': '다시 입력하기',
    'loginForgotPasswordPromptReset': '비밀번호 재설정',
    'loginNewPasswordLabel': '새 비밀번호',
    'loginSendingCode': '전송 중입니다...',
    'loginResendCode': '재전송',
    'loginSendCode': '코드 전송',
    'loginSubmitting': '처리 중입니다...',
    'loginSignupSubmit': '회원가입 완료',
    'loginResetSubmit': '비밀번호 재설정',
    'loginLoginSubmit': '로그인',
    'loginContinueAsGuest': '게스트로 계속하기',
    'loginSignupCodeSent': '이메일 인증 코드를 보내드렸습니다',
    'loginSignupCodeVerified': '이메일 인증이 완료되었습니다',
    'loginSignupVerifyCodeAction': '인증 코드 확인',
    'loginSignupVerifyingCode': '인증 확인 중입니다...',
    'loginSignupVerifiedBadge': '인증 완료',
    'loginResetCodeSent': '비밀번호 재설정 코드를 보내드렸습니다',
    'loginResetBackToLogin': '로그인으로 돌아가기',
    'loginValidationEmailRequired': '이메일을 입력해 주세요',
    'loginValidationEmailPasswordRequired': '이메일과 비밀번호를 입력해 주세요',
    'loginValidationSignupFieldsRequired': '이름과 인증 코드를 모두 입력해 주세요',
    'loginValidationNameRequired': '이름을 입력해 주세요',
    'loginValidationSignupCodeVerifyRequired': '이메일 인증을 먼저 완료해 주세요',
    'loginValidationPasswordTooShort': '비밀번호는 8자 이상이어야 합니다',
    'loginValidationPasswordMismatch': '비밀번호 확인이 일치하지 않습니다',
    'loginValidationCodeRequired': '인증 코드를 입력해 주세요',
    'savedEmptyTitle': '아직 저장된 카트가 없어요',
    'savedEmptyBody': 'Home에서 저장하면 여기서 다시 볼 수 있어.',
    'recentSavedTitle': '최근 저장 카트',
    'recentSavedEmptyBody': '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
    'myBenefitsTitle': '계정이 있으면 좋은 점',
    'myBenefitsBody': '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
    'myGuestModeLabel': '게스트로 사용 중이에요',
    'myLoginAction': '로그인 / 회원가입',
    'myLogoutAction': '로그아웃',
    'myLinkedDoneMessage': '계정을 연결했어요',
    'myLogoutDoneMessage': '로그아웃했어요',
    'drawerGuestTitle': '아직 로그인하지 않았어요',
    'drawerGuestBody': '저장한 카트와 스캔 기록을 이어가려면 로그인해.',
    'saveCompleteTitle': '카트 저장 완료',
    'saveCompleteSubtitle': '다음 결제 전에 다시 볼 수 있어',
    'scanCaptureButton': '가격표 인식하기',
    'scanUploadButton': '이미지 파일을 업로드 하세요',
    'scanManualAddAction': '직접 추가하기',
    'scanRecognizedTitle': '인식 결과',
    'scanManualAddTitle': '직접 추가하기',
    'scanUploading': '업로드 중...',
    'scanQueued': '대기 중...',
    'scanProcessing': '분석 중...',
    'scanResultPreparing': '결과 정리 중...',
    'scanFailed': '인식에 실패했어요',
    'scanTimeout': '분석이 조금 지연되고 있어요. 잠시 후 다시 시도해봐요',
    'scanResultEmpty': '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요',
    'scanProcessingError': '분석 처리 중 오류가 났어요',
    'scanRetakeAction': '다시 찍기',
    'scanRecognizeAction': '인식',
    'scanRecognizing': '인식 중...',
}

VALID_LOGO_TYPES = {'text', 'image', 'text_image'}


def _normalize_branding(payload: Dict[str, Any]) -> Dict[str, Any]:
    merged = DEFAULT_BRANDING.copy()
    merged.update(payload or {})

    logo_type = str(merged.get('logoType') or DEFAULT_BRANDING['logoType']).strip().lower()
    if logo_type not in VALID_LOGO_TYPES:
        logo_type = DEFAULT_BRANDING['logoType']
    merged['logoType'] = logo_type

    for key in ['logoImageUrl', 'splashImageUrl', 'loginHeroImageUrl']:
        value = merged.get(key)
        if isinstance(value, str):
            value = value.strip()
        merged[key] = value or None

    return merged


def get_branding(db: OrmSession) -> Dict[str, Any]:
    row = db.get(AppSetting, 'branding')
    if row is None:
        return DEFAULT_BRANDING.copy()
    try:
        data = json.loads(row.value_json)
    except Exception:
        return DEFAULT_BRANDING.copy()
    return _normalize_branding(data or {})



def save_branding(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    merged = _normalize_branding(payload)
    row = db.get(AppSetting, 'branding')
    if row is None:
        row = AppSetting(key='branding', value_json=json.dumps(merged, ensure_ascii=False), updated_at=datetime.utcnow())
        db.add(row)
    else:
        row.value_json = json.dumps(merged, ensure_ascii=False)
        row.updated_at = datetime.utcnow()
    db.commit()
    return merged
