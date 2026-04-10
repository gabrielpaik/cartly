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
        'subtitle': '지금 카트 총액을 확인해',
        'recentScanTitle': '최근 스캔',
        'recentScanSubtitle': '방금 읽은 결과',
        'addSectionTitle': '새 상품 추가',
        'addSectionSubtitle': '스캔하거나 바로 담기',
        'currentCartTitle': '현재 카트',
        'currentCartSubtitle': '결제 전 합계를 확인해',
        'currentCartEmpty': '아직 담은 상품이 없어요',
        'addToCurrentCartDone': '현재 카트에 담았어요',
        'addToCurrentCartButton': '현재 카트에 담기',
        'saveCartButton': '카트 저장',
        'cartTotalLabel': '현재 카트 합계',
        'continueScanAction': '계속 스캔하기',
        'recentSavedAction': 'Saved 보기',
    },
    'saved': {
        'pageTitle': 'Saved carts',
        'subtitle': '저장한 카트를 다시 봐',
        'emptyTitle': '아직 저장된 카트가 없어요',
        'emptyBody': 'Home에서 저장하면 여기서 다시 볼 수 있어.',
        'recentTitle': '최근 저장 카트',
        'recentEmptyBody': '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
        'adFallbackTitle': '오늘의 혜택 추천',
        'adFallbackMessage': '저장 카트 확인을 방해하지 않는 위치에 작고 자연스러운 혜택 슬롯을 둬요.',
        'adSecondaryFallbackTitle': '비슷한 상품 프로모션',
        'adSecondaryFallbackMessage': '히스토리를 보는 흐름은 유지하고, 목록 사이에만 낮은 밀도로 노출해요.',
    },
    'my': {
        'pageTitle': 'My account',
        'subtitle': '기록을 남기려면 로그인',
        'benefitsTitle': '계정이 있으면 좋은 점',
        'benefitsBody': '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
        'guestTitle': '아직 로그인하지 않았어요',
        'guestBody': '저장한 카트와 스캔 기록을 이어가려면 로그인해.',
        'guestModeLabel': '게스트로 사용 중이에요',
        'loginAction': '로그인 / 회원가입',
        'logoutAction': '로그아웃',
        'linkedDoneMessage': '계정을 연결했어요',
        'logoutDoneMessage': '로그아웃했어요',
        'adFallbackTitle': '회원 전용 혜택 예고',
        'adFallbackMessage': 'My 화면에서는 계정 가치와 맞물린 부드러운 프로모션만 보여주는 게 좋아요.',
    },
    'login': {
        'pageTitle': '계정 시작',
        'subtitle': '저장과 기록을 이어가려면 로그인',
        'benefitsTitle': '왜 계정을 만들까요',
        'benefitsBody': '• 저장한 카트를 볼 수 있습니다\n• 다음 결제 전에 다시 확인할 수 있습니다\n• 더 저렴한 대안을 추천받을 수 있습니다',
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
        'title': '카트 저장 완료',
        'subtitle': '다음 결제 전에 다시 볼 수 있어',
        'adFallbackTitle': '더 저렴한 대안 보기',
        'adFallbackMessage': '결제 전에 더 나은 선택을 추천해.',
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
    ('saved', 'pageTitle'): 'savedPageTitle',
    ('saved', 'subtitle'): 'savedSubtitle',
    ('saved', 'emptyTitle'): 'savedEmptyTitle',
    ('saved', 'emptyBody'): 'savedEmptyBody',
    ('saved', 'recentTitle'): 'recentSavedTitle',
    ('saved', 'recentEmptyBody'): 'recentSavedEmptyBody',
    ('my', 'pageTitle'): 'myPageTitle',
    ('my', 'subtitle'): 'mySubtitle',
    ('my', 'benefitsTitle'): 'myBenefitsTitle',
    ('my', 'benefitsBody'): 'myBenefitsBody',
    ('my', 'guestModeLabel'): 'myGuestModeLabel',
    ('my', 'loginAction'): 'myLoginAction',
    ('my', 'logoutAction'): 'myLogoutAction',
    ('my', 'linkedDoneMessage'): 'myLinkedDoneMessage',
    ('my', 'logoutDoneMessage'): 'myLogoutDoneMessage',
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
