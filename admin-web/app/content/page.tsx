'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { fetchJsonSafe, isUnauthorizedError, postFormData, putJson } from '../../lib/api'
import { mockContentSettings } from '../../lib/mock'
import { CARTLY_PUBLIC_APP_BASE_URL } from '../../lib/publicUrlConfig'

type ContentSettings = typeof mockContentSettings

type UploadResponse = {
  ok: boolean
  data?: {
    fileName: string
    url: string
    contentType: string
    size: number
  }
  error?: {
    code: string
    message: string
  }
}

type ContentSchedule = {
  pending: boolean
  publishAt: string | null
  updatedAt: string | null
  payload?: ContentSettings | null
}

type FieldConfig = {
  key: keyof ContentSettings
  label: string
  kind?: 'text' | 'textarea' | 'number'
}

const LOGO_TYPE_OPTIONS = [
  { value: 'text', label: '텍스트' },
  { value: 'image', label: '이미지' },
  { value: 'text_image', label: '텍스트 + 이미지' },
] as const

function buildGroups(t: (key: string, fallback?: string) => string): Array<{ title: string; description: string; fields: FieldConfig[] }> {
  return [
    {
      title: t('admin.content.groups.branding.title', '기본 브랜딩'),
      description: t('admin.content.groups.branding.desc', '로고 모드와 탭 라벨'),
      fields: [
        { key: 'logoText', label: t('admin.content.fields.logoText', '로고 텍스트') },
        { key: 'homeTabLabel', label: t('admin.content.fields.homeTabLabel', 'Home 탭 라벨') },
        { key: 'helpTabLabel', label: t('admin.content.fields.helpTabLabel', '도움 탭 라벨') },
        { key: 'myTabLabel', label: t('admin.content.fields.myTabLabel', 'My 탭 라벨') },
      ],
    },
    {
      title: t('admin.content.groups.home.title', 'Home 카피'),
      description: t('admin.content.groups.home.desc', '홈 화면 문구와 카트 섹션 카피'),
      fields: [
        { key: 'homePageTitle', label: t('admin.content.fields.homePageTitle', 'Home 페이지 제목') },
        { key: 'homeSubtitle', label: t('admin.content.fields.homeSubtitle', 'Home subtitle') },
        { key: 'homeRecentScanTitle', label: t('admin.content.fields.homeRecentScanTitle', '최근 스캔 제목') },
        { key: 'homeRecentScanSubtitle', label: t('admin.content.fields.homeRecentScanSubtitle', '최근 스캔 설명') },
        { key: 'homeAddSectionTitle', label: t('admin.content.fields.homeAddSectionTitle', '추가 섹션 제목') },
        { key: 'homeAddSectionSubtitle', label: t('admin.content.fields.homeAddSectionSubtitle', '추가 섹션 설명') },
        { key: 'homeCurrentCartTitle', label: t('admin.content.fields.homeCurrentCartTitle', '현재 카트 제목') },
        { key: 'homeCurrentCartSubtitle', label: t('admin.content.fields.homeCurrentCartSubtitle', '현재 카트 설명') },
        { key: 'homeCurrentCartEmpty', label: t('admin.content.fields.homeCurrentCartEmpty', '현재 카트 empty 문구'), kind: 'textarea' },
        { key: 'homeAddToCurrentCartDone', label: t('admin.content.fields.homeAddToCurrentCartDone', '카트 담기 완료 문구') },
        { key: 'homeAddToCurrentCartButton', label: t('admin.content.fields.homeAddToCurrentCartButton', '카트 담기 버튼') },
        { key: 'homeSaveCartButton', label: t('admin.content.fields.homeSaveCartButton', '카트 저장 버튼') },
        { key: 'homeCartTotalLabel', label: t('admin.content.fields.homeCartTotalLabel', '카트 합계 라벨') },
        { key: 'homeContinueScanAction', label: t('admin.content.fields.homeContinueScanAction', '계속 스캔 버튼') },
        { key: 'homeRecentSavedAction', label: t('admin.content.fields.homeRecentSavedAction', '지난 카트 보기 버튼') },
        { key: 'homeExploreEntryTitle', label: t('admin.content.fields.homeExploreEntryTitle', '탐색 유도 타이틀') },
        { key: 'homeExploreEntryBody', label: t('admin.content.fields.homeExploreEntryBody', '탐색 유도 설명'), kind: 'textarea' },
      ],
    },
    {
      title: t('admin.content.groups.help.title', 'Explore / Help 기본 카피'),
      description: t('admin.content.groups.help.desc', 'Explore 진입 상단 기본 문구'),
      fields: [
        { key: 'helpPageTitle', label: t('admin.content.fields.helpPageTitle', '도움 페이지 제목') },
        { key: 'helpSubtitle', label: t('admin.content.fields.helpSubtitle', '도움 subtitle'), kind: 'textarea' },
      ],
    },
    {
      title: t('admin.content.groups.saved.title', '지난 카트 카피'),
      description: t('admin.content.groups.saved.desc', 'My 내부 지난 카트 문구'),
      fields: [
        { key: 'savedPageTitle', label: t('admin.content.fields.savedPageTitle', '지난 카트 섹션 제목') },
        { key: 'savedSubtitle', label: t('admin.content.fields.savedSubtitle', '지난 카트 설명') },
        { key: 'savedEmptyTitle', label: t('admin.content.fields.savedEmptyTitle', '지난 카트 empty 제목') },
        { key: 'savedEmptyBody', label: t('admin.content.fields.savedEmptyBody', '지난 카트 empty 설명'), kind: 'textarea' },
        { key: 'recentSavedTitle', label: t('admin.content.fields.recentSavedTitle', '최근 저장 카트 제목') },
        { key: 'recentSavedEmptyBody', label: t('admin.content.fields.recentSavedEmptyBody', '최근 저장 카트 empty 설명'), kind: 'textarea' },
        { key: 'savedAdFallbackTitle', label: t('admin.content.fields.savedAdFallbackTitle', '지난 카트 혜택 제목') },
        { key: 'savedAdFallbackMessage', label: t('admin.content.fields.savedAdFallbackMessage', '지난 카트 혜택 설명'), kind: 'textarea' },
        { key: 'savedAdSecondaryFallbackTitle', label: t('admin.content.fields.savedAdSecondaryFallbackTitle', '보조 혜택 제목') },
        { key: 'savedAdSecondaryFallbackMessage', label: t('admin.content.fields.savedAdSecondaryFallbackMessage', '보조 혜택 설명'), kind: 'textarea' },
      ],
    },
    {
      title: t('admin.content.groups.myLogin.title', 'My / 로그인 카피'),
      description: t('admin.content.groups.myLogin.desc', '로그인과 My 화면 문구'),
      fields: [
        { key: 'myPageTitle', label: t('admin.content.fields.myPageTitle', 'My 페이지 제목') },
        { key: 'mySubtitle', label: t('admin.content.fields.mySubtitle', 'My subtitle') },
        { key: 'myBenefitsTitle', label: t('admin.content.fields.myBenefitsTitle', 'My benefits 제목') },
        { key: 'myBenefitsBody', label: t('admin.content.fields.myBenefitsBody', 'My benefits 설명'), kind: 'textarea' },
        { key: 'myMemberBody', label: t('admin.content.fields.myMemberBody', '회원 상태 안내 문구'), kind: 'textarea' },
        { key: 'myGuestModeLabel', label: t('admin.content.fields.myGuestModeLabel', '게스트 모드 라벨') },
        { key: 'myGuestSignupAction', label: t('admin.content.fields.myGuestSignupAction', '게스트 회원가입 버튼') },
        { key: 'myLoginAction', label: t('admin.content.fields.myLoginAction', '로그인 버튼') },
        { key: 'myLogoutAction', label: t('admin.content.fields.myLogoutAction', '로그아웃 버튼') },
        { key: 'myLinkedDoneMessage', label: t('admin.content.fields.myLinkedDoneMessage', '계정 연결 완료 문구') },
        { key: 'myLogoutDoneMessage', label: t('admin.content.fields.myLogoutDoneMessage', '로그아웃 완료 문구') },
        { key: 'mySavedSectionTitle', label: t('admin.content.fields.mySavedSectionTitle', 'My 지난 카트 섹션 제목') },
        { key: 'mySavedSectionMemberSubtitle', label: t('admin.content.fields.mySavedSectionMemberSubtitle', '회원 지난 카트 설명'), kind: 'textarea' },
        { key: 'mySavedSectionGuestSubtitle', label: t('admin.content.fields.mySavedSectionGuestSubtitle', '게스트 지난 카트 설명'), kind: 'textarea' },
        { key: 'myAdFallbackTitle', label: t('admin.content.fields.myAdFallbackTitle', 'My 혜택 제목') },
        { key: 'myAdFallbackMessage', label: t('admin.content.fields.myAdFallbackMessage', 'My 혜택 설명'), kind: 'textarea' },
        { key: 'myComplianceTitle', label: t('admin.content.fields.myComplianceTitle', '개인정보/문의 섹션 제목') },
        { key: 'myComplianceBody', label: t('admin.content.fields.myComplianceBody', '개인정보/문의 섹션 설명'), kind: 'textarea' },
        { key: 'myPrivacyPolicyLabel', label: t('admin.content.fields.myPrivacyPolicyLabel', '개인정보 처리방침 버튼명') },
        { key: 'myPrivacyPolicyUrl', label: t('admin.content.fields.myPrivacyPolicyUrl', '개인정보 처리방침 URL') },
        { key: 'mySupportEmailLabel', label: t('admin.content.fields.mySupportEmailLabel', '고객센터 이메일 라벨') },
        { key: 'mySupportEmail', label: t('admin.content.fields.mySupportEmail', '고객센터 이메일') },
        { key: 'mySupportPhoneLabel', label: t('admin.content.fields.mySupportPhoneLabel', '고객센터 연락처 라벨') },
        { key: 'mySupportPhone', label: t('admin.content.fields.mySupportPhone', '고객센터 연락처') },
        { key: 'mySupportHoursLabel', label: t('admin.content.fields.mySupportHoursLabel', '응답 안내 라벨') },
        { key: 'mySupportHours', label: t('admin.content.fields.mySupportHours', '응답 안내') },
        { key: 'myBusinessInfoLabel', label: t('admin.content.fields.myBusinessInfoLabel', '운영 정보 라벨') },
        { key: 'myBusinessInfo', label: t('admin.content.fields.myBusinessInfo', '운영 정보'), kind: 'textarea' },
        { key: 'mySupportNote', label: t('admin.content.fields.mySupportNote', '추가 안내 문구'), kind: 'textarea' },
        { key: 'loginPageTitle', label: t('admin.content.fields.loginPageTitle', '로그인 페이지 제목') },
        { key: 'loginSubtitle', label: t('admin.content.fields.loginSubtitle', 'Login subtitle') },
        { key: 'loginBenefitsTitle', label: t('admin.content.fields.loginBenefitsTitle', '로그인 benefits 제목') },
        { key: 'loginBenefitsBody', label: t('admin.content.fields.loginBenefitsBody', '로그인 benefits 설명'), kind: 'textarea' },
        { key: 'loginModeLogin', label: t('admin.content.fields.loginModeLogin', '로그인 탭 라벨') },
        { key: 'loginModeSignup', label: t('admin.content.fields.loginModeSignup', '회원가입 탭 라벨') },
        { key: 'loginModeReset', label: t('admin.content.fields.loginModeReset', '비밀번호 찾기 탭 라벨') },
        { key: 'loginNameFieldLabel', label: t('admin.content.fields.loginNameFieldLabel', '이름 필드 라벨') },
        { key: 'loginEmailFieldLabel', label: t('admin.content.fields.loginEmailFieldLabel', '이메일 필드 라벨') },
        { key: 'loginEmailLocalFieldLabel', label: t('admin.content.fields.loginEmailLocalFieldLabel', '이메일 아이디 필드 라벨') },
        { key: 'loginEmailDomainFieldLabel', label: t('admin.content.fields.loginEmailDomainFieldLabel', '이메일 도메인 필드 라벨') },
        { key: 'loginEmailCustomDomainOption', label: t('admin.content.fields.loginEmailCustomDomainOption', '직접입력 도메인 옵션') },
        { key: 'loginEmailCustomDomainFieldLabel', label: t('admin.content.fields.loginEmailCustomDomainFieldLabel', '직접입력 도메인 라벨') },
        { key: 'loginPasswordFieldLabel', label: t('admin.content.fields.loginPasswordFieldLabel', '비밀번호 필드 라벨') },
        { key: 'loginPasswordConfirmFieldLabel', label: t('admin.content.fields.loginPasswordConfirmFieldLabel', '비밀번호 확인 라벨') },
        { key: 'loginCodeFieldLabel', label: t('admin.content.fields.loginCodeFieldLabel', '인증 코드 라벨') },
        { key: 'loginForgotPasswordAction', label: t('admin.content.fields.loginForgotPasswordAction', '비밀번호 찾기 링크') },
        { key: 'loginInvalidPasswordMessage', label: t('admin.content.fields.loginInvalidPasswordMessage', '잘못된 비밀번호 문구'), kind: 'textarea' },
        { key: 'loginExistingEmailTitle', label: t('admin.content.fields.loginExistingEmailTitle', '기존 이메일 안내 제목') },
        { key: 'loginExistingEmailBody', label: t('admin.content.fields.loginExistingEmailBody', '기존 이메일 안내 본문'), kind: 'textarea' },
        { key: 'loginExistingEmailLoginAction', label: t('admin.content.fields.loginExistingEmailLoginAction', '기존 이메일 로그인 액션') },
        { key: 'loginExistingEmailResetAction', label: t('admin.content.fields.loginExistingEmailResetAction', '기존 이메일 재설정 액션') },
        { key: 'loginForgotPasswordPromptTitle', label: t('admin.content.fields.loginForgotPasswordPromptTitle', '비밀번호 분실 팝업 제목') },
        { key: 'loginForgotPasswordPromptBody', label: t('admin.content.fields.loginForgotPasswordPromptBody', '비밀번호 분실 팝업 본문'), kind: 'textarea' },
        { key: 'loginForgotPasswordPromptStay', label: t('admin.content.fields.loginForgotPasswordPromptStay', '비밀번호 분실 팝업 유지 액션') },
        { key: 'loginForgotPasswordPromptReset', label: t('admin.content.fields.loginForgotPasswordPromptReset', '비밀번호 분실 팝업 재설정 액션') },
        { key: 'loginNewPasswordLabel', label: t('admin.content.fields.loginNewPasswordLabel', '새 비밀번호 라벨') },
        { key: 'loginSendingCode', label: t('admin.content.fields.loginSendingCode', '코드 전송 중 문구') },
        { key: 'loginResendCode', label: t('admin.content.fields.loginResendCode', '코드 재전송 버튼') },
        { key: 'loginSendCode', label: t('admin.content.fields.loginSendCode', '코드 전송 버튼') },
        { key: 'loginSubmitting', label: t('admin.content.fields.loginSubmitting', '처리 중 문구') },
        { key: 'loginSignupSubmit', label: t('admin.content.fields.loginSignupSubmit', '회원가입 완료 버튼') },
        { key: 'loginResetSubmit', label: t('admin.content.fields.loginResetSubmit', '비밀번호 재설정 버튼') },
        { key: 'loginLoginSubmit', label: t('admin.content.fields.loginLoginSubmit', '로그인 버튼') },
        { key: 'loginContinueAsGuest', label: t('admin.content.fields.loginContinueAsGuest', '게스트 계속하기 버튼') },
        { key: 'loginSignupCodeSent', label: t('admin.content.fields.loginSignupCodeSent', '회원가입 코드 발송 문구'), kind: 'textarea' },
        { key: 'loginSignupCodeVerified', label: t('admin.content.fields.loginSignupCodeVerified', '회원가입 코드 인증 완료 문구'), kind: 'textarea' },
        { key: 'loginSignupVerifyCodeAction', label: t('admin.content.fields.loginSignupVerifyCodeAction', '회원가입 코드 확인 버튼') },
        { key: 'loginSignupVerifyingCode', label: t('admin.content.fields.loginSignupVerifyingCode', '회원가입 코드 확인 중 문구') },
        { key: 'loginSignupVerifiedBadge', label: t('admin.content.fields.loginSignupVerifiedBadge', '회원가입 인증 완료 배지') },
        { key: 'loginResetCodeSent', label: t('admin.content.fields.loginResetCodeSent', '비밀번호 재설정 코드 발송 문구'), kind: 'textarea' },
        { key: 'loginResetBackToLogin', label: t('admin.content.fields.loginResetBackToLogin', '로그인으로 돌아가기 버튼') },
        { key: 'loginValidationEmailRequired', label: t('admin.content.fields.loginValidationEmailRequired', '이메일 필수 문구') },
        { key: 'loginValidationEmailPasswordRequired', label: t('admin.content.fields.loginValidationEmailPasswordRequired', '이메일/비밀번호 필수 문구'), kind: 'textarea' },
        { key: 'loginValidationSignupFieldsRequired', label: t('admin.content.fields.loginValidationSignupFieldsRequired', '회원가입 필수 문구'), kind: 'textarea' },
        { key: 'loginValidationNameRequired', label: t('admin.content.fields.loginValidationNameRequired', '이름 필수 문구') },
        { key: 'loginValidationSignupCodeVerifyRequired', label: t('admin.content.fields.loginValidationSignupCodeVerifyRequired', '회원가입 코드 인증 필수 문구'), kind: 'textarea' },
        { key: 'loginValidationPasswordTooShort', label: t('admin.content.fields.loginValidationPasswordTooShort', '비밀번호 길이 문구') },
        { key: 'loginValidationPasswordMismatch', label: t('admin.content.fields.loginValidationPasswordMismatch', '비밀번호 불일치 문구') },
        { key: 'loginValidationCodeRequired', label: t('admin.content.fields.loginValidationCodeRequired', '코드 필수 문구') },
        { key: 'drawerGuestTitle', label: t('admin.content.fields.drawerGuestTitle', 'Drawer guest 제목') },
        { key: 'drawerGuestBody', label: t('admin.content.fields.drawerGuestBody', 'Drawer guest 설명'), kind: 'textarea' },
      ],
    },
    {
      title: t('admin.content.groups.detail.title', '상세 / 비교 카피'),
      description: t('admin.content.groups.detail.desc', '카트 상세, 영수증 비교, 공통 액션 문구'),
      fields: [
        { key: 'commonCancel', label: t('admin.content.fields.commonCancel', '공통 취소 버튼') },
        { key: 'commonConfirm', label: t('admin.content.fields.commonConfirm', '공통 확인 버튼') },
        { key: 'commonEdit', label: t('admin.content.fields.commonEdit', '공통 수정 버튼') },
        { key: 'commonLoading', label: t('admin.content.fields.commonLoading', '공통 로딩 문구') },
        { key: 'cartDetailTitleSuffix', label: t('admin.content.fields.cartDetailTitleSuffix', '카트 상세 제목 접미사') },
        { key: 'cartDetailEdit', label: t('admin.content.fields.cartDetailEdit', '카트 상세 수정 버튼') },
        { key: 'cartDetailDone', label: t('admin.content.fields.cartDetailDone', '카트 상세 완료 버튼') },
        { key: 'cartDetailDeleteDialogTitle', label: t('admin.content.fields.cartDetailDeleteDialogTitle', '카트 삭제 팝업 제목') },
        { key: 'cartDetailDeleteDialogBody', label: t('admin.content.fields.cartDetailDeleteDialogBody', '카트 삭제 팝업 설명'), kind: 'textarea' },
        { key: 'cartDetailDeleteConfirm', label: t('admin.content.fields.cartDetailDeleteConfirm', '카트 삭제 확인 버튼') },
        { key: 'cartDetailDeleteCancel', label: t('admin.content.fields.cartDetailDeleteCancel', '카트 삭제 취소 버튼') },
        { key: 'cartDetailEmpty', label: t('admin.content.fields.cartDetailEmpty', '카트 상세 empty 문구') },
        { key: 'cartDetailItemAdded', label: t('admin.content.fields.cartDetailItemAdded', '상품 추가 완료 문구') },
        { key: 'cartDetailSavedSnapshotDone', label: t('admin.content.fields.cartDetailSavedSnapshotDone', '저장본 기록 완료 문구') },
        { key: 'cartDetailNameLabel', label: t('admin.content.fields.cartDetailNameLabel', '상품명 라벨') },
        { key: 'cartDetailPriceLabel', label: t('admin.content.fields.cartDetailPriceLabel', '가격 라벨') },
        { key: 'cartDetailApply', label: t('admin.content.fields.cartDetailApply', '적용 버튼') },
        { key: 'cartDetailTotalLabel', label: t('admin.content.fields.cartDetailTotalLabel', '총합 라벨') },
        { key: 'cartDetailSaveButton', label: t('admin.content.fields.cartDetailSaveButton', '저장 버튼') },
        { key: 'cartDetailSaving', label: t('admin.content.fields.cartDetailSaving', '저장 중 문구') },
        { key: 'cartDetailValidationNamePriceRequired', label: t('admin.content.fields.cartDetailValidationNamePriceRequired', '상품명/가격 확인 문구'), kind: 'textarea' },
        { key: 'cartDetailValidationNameRequired', label: t('admin.content.fields.cartDetailValidationNameRequired', '상품명 필수 문구') },
        { key: 'cartDetailValidationPriceQuantityRequired', label: t('admin.content.fields.cartDetailValidationPriceQuantityRequired', '가격/수량 확인 문구'), kind: 'textarea' },
        { key: 'receiptCompareContextBody', label: t('admin.content.fields.receiptCompareContextBody', '영수증 비교 안내 문구'), kind: 'textarea' },
        { key: 'receiptCompareEntryAction', label: t('admin.content.fields.receiptCompareEntryAction', '영수증 비교 진입 버튼') },
        { key: 'receiptCompareSavedCartOnlyBadge', label: t('admin.content.fields.receiptCompareSavedCartOnlyBadge', '영수증 비교 저장 카트 전용 배지') },
        { key: 'receiptReminderDelayMinutes', label: t('admin.content.fields.receiptReminderDelayMinutes', '영수증 리마인더 지연(분)'), kind: 'number' },
      ],
    },
    {
      title: t('admin.content.groups.publicSite.title', '공개 랜딩 카피'),
      description: t('admin.content.groups.publicSite.desc', 'scan-api 공개 랜딩과 privacy 문구'),
      fields: [
        { key: 'publicSiteEyebrow', label: t('admin.content.fields.publicSiteEyebrow', '랜딩 eyebrow') },
        { key: 'publicSiteHeroTitle', label: t('admin.content.fields.publicSiteHeroTitle', '랜딩 메인 제목'), kind: 'textarea' },
        { key: 'publicSiteHeroBody', label: t('admin.content.fields.publicSiteHeroBody', '랜딩 소개 문구'), kind: 'textarea' },
        { key: 'publicSitePrimaryCtaLabel', label: t('admin.content.fields.publicSitePrimaryCtaLabel', '랜딩 1차 CTA') },
        { key: 'publicSiteSecondaryCtaLabel', label: t('admin.content.fields.publicSiteSecondaryCtaLabel', '랜딩 2차 CTA') },
        { key: 'publicSiteHeroPoints', label: t('admin.content.fields.publicSiteHeroPoints', '랜딩 핵심 포인트'), kind: 'textarea' },
        { key: 'publicSiteEnabledSections', label: t('admin.content.fields.publicSiteEnabledSections', '표시할 섹션 목록') },
        { key: 'publicSiteSectionOrder', label: t('admin.content.fields.publicSiteSectionOrder', '섹션 순서') },
        { key: 'publicSiteFlowTitle', label: t('admin.content.fields.publicSiteFlowTitle', '랜딩 흐름 제목') },
        { key: 'publicSiteFlowBody', label: t('admin.content.fields.publicSiteFlowBody', '랜딩 흐름 설명'), kind: 'textarea' },
        { key: 'publicSiteStatusTitle', label: t('admin.content.fields.publicSiteStatusTitle', '운영 상태 제목') },
        { key: 'publicSiteStatusPoints', label: t('admin.content.fields.publicSiteStatusPoints', '운영 상태 포인트'), kind: 'textarea' },
        { key: 'publicSitePartnerReviewTitle', label: t('admin.content.fields.publicSitePartnerReviewTitle', '파트너 검토 제목') },
        { key: 'publicSitePartnerReviewPoints', label: t('admin.content.fields.publicSitePartnerReviewPoints', '파트너 검토 포인트'), kind: 'textarea' },
        { key: 'publicSiteLinkPlacementTitle', label: t('admin.content.fields.publicSiteLinkPlacementTitle', '링크 위치 섹션 제목') },
        { key: 'publicSiteLinkPlacementBody', label: t('admin.content.fields.publicSiteLinkPlacementBody', '링크 위치 섹션 설명'), kind: 'textarea' },
        { key: 'publicSiteLinkPlacementPoints', label: t('admin.content.fields.publicSiteLinkPlacementPoints', '링크 위치 포인트'), kind: 'textarea' },
        { key: 'publicSitePrivacyTitle', label: t('admin.content.fields.publicSitePrivacyTitle', 'Privacy 제목') },
        { key: 'publicSitePrivacyIntro', label: t('admin.content.fields.publicSitePrivacyIntro', 'Privacy 소개'), kind: 'textarea' },
        { key: 'publicSitePrivacyCollectionTitle', label: t('admin.content.fields.publicSitePrivacyCollectionTitle', 'Privacy 수집 제목') },
        { key: 'publicSitePrivacyCollectionPoints', label: t('admin.content.fields.publicSitePrivacyCollectionPoints', 'Privacy 수집 항목'), kind: 'textarea' },
        { key: 'publicSitePrivacyExternalTitle', label: t('admin.content.fields.publicSitePrivacyExternalTitle', 'Privacy 외부 링크 제목') },
        { key: 'publicSitePrivacyExternalBody', label: t('admin.content.fields.publicSitePrivacyExternalBody', 'Privacy 외부 링크 설명'), kind: 'textarea' },
        { key: 'publicSitePrivacyStatusTitle', label: t('admin.content.fields.publicSitePrivacyStatusTitle', 'Privacy 현재 상태 제목') },
        { key: 'publicSitePrivacyStatusBody', label: t('admin.content.fields.publicSitePrivacyStatusBody', 'Privacy 현재 상태 설명'), kind: 'textarea' },
        { key: 'publicSitePrivacyBackAction', label: t('admin.content.fields.publicSitePrivacyBackAction', 'Privacy 돌아가기 버튼') },
      ],
    },
    {
      title: t('admin.content.groups.scan.title', '스캔 카피'),
      description: t('admin.content.groups.scan.desc', '스캔/인식 흐름 문구'),
      fields: [
        { key: 'scanCaptureButton', label: t('admin.content.fields.scanCaptureButton', '가격표 인식 버튼') },
        { key: 'scanUploadButton', label: t('admin.content.fields.scanUploadButton', '이미지 업로드 버튼') },
        { key: 'scanManualAddAction', label: t('admin.content.fields.scanManualAddAction', '직접 추가 버튼') },
        { key: 'scanRecognizedTitle', label: t('admin.content.fields.scanRecognizedTitle', '인식 결과 제목') },
        { key: 'scanManualAddTitle', label: t('admin.content.fields.scanManualAddTitle', '직접 추가 제목') },
        { key: 'scanUploading', label: t('admin.content.fields.scanUploading', '업로드 중 문구') },
        { key: 'scanQueued', label: t('admin.content.fields.scanQueued', '대기 중 문구') },
        { key: 'scanProcessing', label: t('admin.content.fields.scanProcessing', '분석 중 문구') },
        { key: 'scanResultPreparing', label: t('admin.content.fields.scanResultPreparing', '결과 정리 문구') },
        { key: 'scanFailed', label: t('admin.content.fields.scanFailed', '인식 실패 문구') },
        { key: 'scanTimeout', label: t('admin.content.fields.scanTimeout', '분석 지연 문구'), kind: 'textarea' },
        { key: 'scanResultEmpty', label: t('admin.content.fields.scanResultEmpty', '인식 결과 없음 문구'), kind: 'textarea' },
        { key: 'scanProcessingError', label: t('admin.content.fields.scanProcessingError', '처리 오류 문구'), kind: 'textarea' },
        { key: 'scanRetakeAction', label: t('admin.content.fields.scanRetakeAction', '다시 찍기 버튼') },
        { key: 'scanRecognizeAction', label: t('admin.content.fields.scanRecognizeAction', '인식 버튼') },
        { key: 'scanRecognizing', label: t('admin.content.fields.scanRecognizing', '인식 중 문구') },
      ],
    },
    {
      title: t('admin.content.groups.saveComplete.title', '저장 완료 카피'),
      description: t('admin.content.groups.saveComplete.desc', '저장 완료 문구'),
      fields: [
        { key: 'saveCompleteTitle', label: t('admin.content.fields.saveCompleteTitle', '저장 완료 제목') },
        { key: 'saveCompleteSubtitle', label: t('admin.content.fields.saveCompleteSubtitle', '저장 완료 부제'), kind: 'textarea' },
        { key: 'saveCompleteAdFallbackTitle', label: t('admin.content.fields.saveCompleteAdFallbackTitle', '저장 완료 혜택 제목') },
        { key: 'saveCompleteAdFallbackMessage', label: t('admin.content.fields.saveCompleteAdFallbackMessage', '저장 완료 혜택 설명'), kind: 'textarea' },
        { key: 'saveCompleteViewSavedAction', label: t('admin.content.fields.saveCompleteViewSavedAction', '지난 카트 보기 버튼') },
      ],
    },
  ]
}

export default function ContentPage() {
  const router = useRouter()
  const { t } = useAdminCopy()
  const [form, setForm] = useState<ContentSettings>(mockContentSettings)
  const [saving, setSaving] = useState(false)
  const [usingFallback, setUsingFallback] = useState(true)
  const [fallbackMessage, setFallbackMessage] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [uploading, setUploading] = useState<'logo' | 'splash' | 'loginHero' | null>(null)
  const [previewScreen, setPreviewScreen] = useState<'home' | 'help' | 'my' | 'login'>('home')
  const [previewMemberMode, setPreviewMemberMode] = useState(false)
  const [previewSrc, setPreviewSrc] = useState('')
  const [publicPreviewPath, setPublicPreviewPath] = useState<'/' | '/privacy'>('/')
  const [publicPreviewSrc, setPublicPreviewSrc] = useState('')
  const [savedSnapshot, setSavedSnapshot] = useState(() => JSON.stringify(mockContentSettings))
  const [lastSavedAt, setLastSavedAt] = useState<string | null>(null)
  const [publishAtDraft, setPublishAtDraft] = useState('')
  const [scheduleMeta, setScheduleMeta] = useState<ContentSchedule>({ pending: false, publishAt: null, updatedAt: null, payload: null })
  const [activeSection, setActiveSection] = useState<'brand' | 'app' | 'account' | 'public'>('brand')
  const [appCopyTab, setAppCopyTab] = useState<'home' | 'help' | 'saved' | 'scan' | 'detail' | 'saveComplete'>('home')
  const [accountTab, setAccountTab] = useState<'my' | 'login' | 'guest'>('my')
  const [publicTab, setPublicTab] = useState<'landing' | 'privacy'>('landing')
  const [previewSurface, setPreviewSurface] = useState<'app' | 'site'>('app')
  const previewPopupRef = useRef<Window | null>(null)
  const groups = buildGroups(t)
  const groupMap = useMemo(() => ({
    branding: groups[0],
    home: groups[1],
    help: groups[2],
    saved: groups[3],
    myLogin: groups[4],
    detail: groups[5],
    publicSite: groups[6],
    scan: groups[7],
    saveComplete: groups[8],
  }), [groups])
  const totalFields = groups.reduce((sum, group) => sum + group.fields.length, 0)
  const formSnapshot = useMemo(() => JSON.stringify(form), [form])
  const isDirty = formSnapshot !== savedSnapshot
  const contentActionState = usingFallback ? 'fallback blocked' : saving ? 'saving' : isDirty ? 'unsaved changes' : 'saved'
  const contentActionStateLabel = usingFallback ? 'fallback' : saving ? '저장중' : isDirty ? '수정됨' : '저장됨'
  const lastSavedLabel = useMemo(() => (lastSavedAt ? new Date(lastSavedAt).toLocaleString('ko-KR') : null), [lastSavedAt])
  const scheduleLabel = scheduleMeta.publishAt ?? null
  const accountFieldGroups = useMemo(() => ({
    my: groupMap.myLogin.fields.filter((field) => String(field.key).startsWith('my')),
    login: groupMap.myLogin.fields.filter((field) => String(field.key).startsWith('login')),
    guest: groupMap.myLogin.fields.filter((field) => String(field.key).startsWith('drawerGuest')),
  }), [groupMap])
  const publicSiteFieldGroups = useMemo(() => ({
    landing: groupMap.publicSite.fields.filter((field) => !String(field.key).startsWith('publicSitePrivacy')),
    privacy: groupMap.publicSite.fields.filter((field) => String(field.key).startsWith('publicSitePrivacy')),
  }), [groupMap])

  function buildAppPreviewSrc() {
    return `/app-preview/index.html?v=${Date.now()}`
  }

  function refreshAppPreview() {
    const nextSrc = buildAppPreviewSrc()
    setPreviewSrc(nextSrc)
    const existing = previewPopupRef.current
    if (previewSurface === 'app' && existing && !existing.closed) {
      existing.location.href = nextSrc
      window.setTimeout(() => postPreviewPayload(existing), 500)
    }
    return nextSrc
  }

  function formatPublishNow() {
    const now = new Date()
    const pad = (value: number) => String(value).padStart(2, '0')
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
  }

  function parsePublishAt(value: string) {
    const normalized = value.trim().replace(' ', 'T')
    const parsed = new Date(normalized)
    if (Number.isNaN(parsed.getTime())) return null
    return parsed
  }

  function isFuturePublishAt(value: string) {
    const parsed = parsePublishAt(value)
    if (!parsed) return false
    return parsed.getTime() > Date.now()
  }

  async function loadSchedule(liveContent?: ContentSettings) {
    try {
      const response = await fetchJsonSafe<{ ok: boolean; data: ContentSchedule }>('/admin/content/schedule', {
        ok: true,
        data: { pending: false, publishAt: null, updatedAt: null, payload: null },
      })
      const schedule = response.data.data
      setScheduleMeta(schedule)
      if (schedule.pending && schedule.publishAt) {
        setPublishAtDraft(schedule.publishAt)
        if (schedule.payload) {
          setForm(schedule.payload)
          setSavedSnapshot(JSON.stringify(schedule.payload))
        } else if (liveContent) {
          setForm(liveContent)
          setSavedSnapshot(JSON.stringify(liveContent))
        }
      } else {
        if (liveContent) {
          setForm(liveContent)
          setSavedSnapshot(JSON.stringify(liveContent))
        }
        setPublishAtDraft(formatPublishNow())
      }
      return schedule
    } catch {
      if (liveContent) {
        setForm(liveContent)
        setSavedSnapshot(JSON.stringify(liveContent))
      }
      const emptySchedule = { pending: false, publishAt: null, updatedAt: null, payload: null }
      setScheduleMeta(emptySchedule)
      setPublishAtDraft(formatPublishNow())
      return emptySchedule
    }
  }

  function refreshPublicPreview(path: '/' | '/privacy' = publicPreviewPath) {
    const nextSrc = `${CARTLY_PUBLIC_APP_BASE_URL}${path}?previewTs=${Date.now()}`
    setPublicPreviewPath(path)
    setPublicPreviewSrc(nextSrc)
    const existing = previewPopupRef.current
    if (previewSurface === 'site' && existing && !existing.closed) {
      existing.location.href = nextSrc
    }
  }

  async function reloadContentData() {
    const res = await fetchJsonSafe<{ ok: boolean; data: ContentSettings }>('/admin/content', { ok: true, data: mockContentSettings })
    setUsingFallback(res.usingFallback)
    setFallbackMessage(res.fallbackMessage)
    await loadSchedule(res.data.data)
  }

  useEffect(() => {
    refreshAppPreview()
    refreshPublicPreview('/')
  }, [])

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const res = await fetchJsonSafe<{ ok: boolean; data: ContentSettings }>('/admin/content', { ok: true, data: mockContentSettings })
        if (cancelled) return
        setUsingFallback(res.usingFallback)
        setFallbackMessage(res.fallbackMessage)
        await loadSchedule(res.data.data)
      } catch (err) {
        if (isUnauthorizedError(err)) {
          router.replace('/login?reason=expired')
          return
        }
        if (!cancelled) setMessage(err instanceof Error ? err.message : t('admin.content.loadFailed', '콘텐츠 설정을 불러오지 못했어'))
      }
    })()
    return () => {
      cancelled = true
    }
  }, [router, t])

  function update<K extends keyof ContentSettings>(key: K, value: ContentSettings[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  function renderFieldControl(field: FieldConfig, variant: 'default' | 'sheet' = 'default') {
    const rawValue = form[field.key]
    const value = String(rawValue ?? '')
    const inputClassName = variant === 'sheet' ? 'textInput contentSheetInput' : 'textInput'
    const textareaClassName = variant === 'sheet' ? 'textInput contentSheetTextarea' : 'textInput'

    if (field.kind === 'textarea') {
      return (
        <textarea
          className={textareaClassName}
          rows={variant === 'sheet' ? 2 : 3}
          value={value}
          onChange={(e) => update(field.key, e.target.value as ContentSettings[typeof field.key])}
        />
      )
    }

    if (field.kind === 'number') {
      return (
        <input
          className={inputClassName}
          type="number"
          min={1}
          step={1}
          value={value}
          onChange={(e) => update(field.key, Number.parseInt(e.target.value || '0', 10) as ContentSettings[typeof field.key])}
        />
      )
    }

    return <input className={inputClassName} value={value} onChange={(e) => update(field.key, e.target.value as ContentSettings[typeof field.key])} />
  }

  function renderField(field: FieldConfig) {
    return (
      <label className="field" key={String(field.key)}>
        <div className="fieldLabel">{field.label}</div>
        {renderFieldControl(field)}
      </label>
    )
  }

  function renderFieldSheet(fields: FieldConfig[]) {
    return (
      <div className="tableWrap contentSheetWrap">
        <table className="dataTable contentSheetTable">
          <colgroup>
            <col style={{ width: '32%' }} />
            <col style={{ width: '68%' }} />
          </colgroup>
          <thead>
            <tr>
              <th>항목</th>
              <th>값</th>
            </tr>
          </thead>
          <tbody>
            {fields.map((field) => (
              <tr key={String(field.key)}>
                <td data-label="항목">
                  <div className="contentSheetItemCell">
                    <div className="contentSheetItemLabel">{field.label}</div>
                    <div className="contentSheetItemKey">{String(field.key)}</div>
                  </div>
                </td>
                <td data-label="값">{renderFieldControl(field, 'sheet')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    )
  }

  function postPreviewPayload(target?: Window | null) {
    const nextTarget = target ?? previewPopupRef.current
    nextTarget?.postMessage(
      {
        type: 'branding-preview',
        payload: {
          ...form,
          __previewScreen: previewScreen,
          __previewMemberMode: previewMemberMode,
        },
      },
      '*',
    )
  }

  function openPreviewPopup() {
    if (previewSurface === 'app') {
      const nextSrc = previewSrc || refreshAppPreview()
      const existing = previewPopupRef.current
      if (existing && !existing.closed) {
        existing.location.href = nextSrc
        existing.focus()
        window.setTimeout(() => postPreviewPayload(existing), 500)
        return
      }
      const next = window.open(nextSrc, 'cartly-content-preview', 'popup=yes,width=480,height=920,resizable=yes,scrollbars=yes')
      if (!next) {
        setMessage('브라우저가 preview popup을 막았어. 팝업 허용 후 다시 눌러줘.')
        return
      }
      previewPopupRef.current = next
      next.focus()
      window.setTimeout(() => postPreviewPayload(next), 500)
      return
    }

    const nextSrc = publicPreviewSrc || `${CARTLY_PUBLIC_APP_BASE_URL}${publicPreviewPath}`
    const existing = previewPopupRef.current
    if (existing && !existing.closed) {
      existing.location.href = nextSrc
      existing.focus()
      return
    }
    const next = window.open(nextSrc, 'cartly-content-preview', 'popup=yes,width=1280,height=920,resizable=yes,scrollbars=yes')
    if (!next) {
      setMessage('브라우저가 preview popup을 막았어. 팝업 허용 후 다시 눌러줘.')
      return
    }
    previewPopupRef.current = next
    next.focus()
  }

  useEffect(() => {
    if (previewSurface !== 'app') return
    if (!previewPopupRef.current || previewPopupRef.current.closed) return
    postPreviewPayload(previewPopupRef.current)
  }, [form, previewScreen, previewMemberMode, previewSurface])

  async function onSave() {
    if (usingFallback) {
      setMessage(t('admin.content.fallbackActionBlocked', 'fallback/mock 데이터를 보고 있는 동안에는 저장을 막아둘게'))
      return
    }

    if (!parsePublishAt(publishAtDraft)) {
      setMessage('저장 시각은 YYYY-MM-DD HH:MM:SS 형식으로 넣어줘')
      return
    }

    setSaving(true)
    setMessage(null)
    try {
      await putJson<{ ok: boolean; data: ContentSettings }>('/admin/content', { ...form, _publishAt: publishAtDraft })
      setSavedSnapshot(formSnapshot)
      setLastSavedAt(new Date().toISOString())
      const nextSchedule = await loadSchedule(form)
      refreshPublicPreview(publicPreviewPath)
      setMessage(nextSchedule.pending && nextSchedule.publishAt ? `콘텐츠 예약 저장 완료 (${nextSchedule.publishAt})` : t('admin.content.saveDone', '콘텐츠 설정 저장 완료'))
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setMessage(err instanceof Error ? err.message : t('admin.content.saveFailed', '콘텐츠 설정 저장 실패'))
    } finally {
      setSaving(false)
    }
  }

  async function onAssetUpload(kind: 'logo' | 'splash' | 'loginHero', file: File) {
    if (usingFallback) {
      setMessage(t('admin.content.fallbackUploadBlocked', 'fallback/mock 데이터를 보고 있는 동안에는 자산 업로드도 막아둘게'))
      return
    }

    setUploading(kind)
    setMessage(null)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const uploadPath =
        kind === 'logo'
          ? '/admin/branding/logo'
          : kind === 'splash'
              ? '/admin/branding/splash'
              : '/admin/branding/login-hero'
      const res = await postFormData<UploadResponse>(uploadPath, formData)
      if (!res.ok || !res.data) {
        setMessage(res.error?.message ?? t('admin.content.uploadFailed', '이미지 업로드 실패'))
      } else {
        if (kind === 'logo') update('logoImageUrl', res.data.url)
        else if (kind === 'splash') update('splashImageUrl', res.data.url)
        else update('loginHeroImageUrl', res.data.url)
        refreshPublicPreview(publicPreviewPath)
        setMessage(
          kind === 'logo'
            ? t('admin.content.upload.logoDone', '로고 업로드 완료')
            : kind === 'splash'
                ? t('admin.content.upload.splashDone', '스플래시 이미지 업로드 완료')
                : t('admin.content.upload.loginHeroDone', '로그인 이미지 업로드 완료'),
        )
      }
    } catch (err) {
      if (isUnauthorizedError(err)) {
        router.replace('/login?reason=expired')
        return
      }
      setMessage(err instanceof Error ? err.message : t('admin.content.uploadFailed', '이미지 업로드 실패'))
    } finally {
      setUploading(null)
    }
  }

  const activeAppGroup = {
    home: groupMap.home,
    help: groupMap.help,
    saved: groupMap.saved,
    scan: groupMap.scan,
    detail: groupMap.detail,
    saveComplete: groupMap.saveComplete,
  }[appCopyTab]

  const requestedSection = (() => {
    const value = typeof window !== 'undefined'
      ? new URLSearchParams(window.location.search).get('section')
      : null
    return value === 'brand' || value === 'app' || value === 'account' || value === 'public' ? value : null
  })()

  useEffect(() => {
    if (requestedSection && requestedSection !== activeSection) {
      setActiveSection(requestedSection)
    }
  }, [activeSection, requestedSection])

  const currentSectionTitle = {
    brand: groupMap.branding.title,
    app: 'App copy',
    account: 'Account & login',
    public: 'Public site',
  }[activeSection]
  const previewTargetValue = previewSurface === 'app'
    ? `app:${previewScreen}:${previewMemberMode ? 'member' : 'guest'}`
    : publicPreviewPath === '/privacy'
      ? 'site:privacy'
      : 'site:landing'

  return (
    <div className="contentCompactPage">
      <PageHeader
        badge={usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.content.title', 'Content')}
        description={t('admin.content.desc', '앱 문구와 로고 관리')}
        actions={(
          <div className="contentHeaderActionStrip">
            <div className="contentHeaderActionGroup contentHeaderActionGroupPreview">
              <div className="contentHeaderActionRow">
                <button type="button" className="primaryBtn pageActionBtn pageActionBtnPrimary exploreHeaderActionBtn" onClick={openPreviewPopup}>Preview</button>
                <button
                  type="button"
                  className="ghostBtn pageActionBtn exploreHeaderIconBtn"
                  onClick={() => {
                    if (previewSurface === 'app') {
                      refreshAppPreview()
                      return
                    }
                    refreshPublicPreview(publicPreviewPath)
                  }}
                  aria-label="Preview 다시 보내기"
                  title="Preview 다시 보내기"
                >
                  ↻
                </button>
              </div>
              <label className="contentHeaderMiniField">
                <span>미리보기 상태</span>
                <select
                  className="textInput contentHeaderTargetSelect"
                  value={previewTargetValue}
                  onChange={(e) => {
                    const value = e.target.value
                    if (value === 'app:home:guest') {
                      setPreviewSurface('app')
                      setPreviewScreen('home')
                      setPreviewMemberMode(false)
                      return
                    }
                    if (value === 'app:home:member') {
                      setPreviewSurface('app')
                      setPreviewScreen('home')
                      setPreviewMemberMode(true)
                      return
                    }
                    if (value === 'app:help:guest') {
                      setPreviewSurface('app')
                      setPreviewScreen('help')
                      setPreviewMemberMode(false)
                      return
                    }
                    if (value === 'app:help:member') {
                      setPreviewSurface('app')
                      setPreviewScreen('help')
                      setPreviewMemberMode(true)
                      return
                    }
                    if (value === 'app:my:guest') {
                      setPreviewSurface('app')
                      setPreviewScreen('my')
                      setPreviewMemberMode(false)
                      return
                    }
                    if (value === 'app:my:member') {
                      setPreviewSurface('app')
                      setPreviewScreen('my')
                      setPreviewMemberMode(true)
                      return
                    }
                    if (value === 'app:login:guest') {
                      setPreviewSurface('app')
                      setPreviewScreen('login')
                      setPreviewMemberMode(false)
                      return
                    }
                    if (value === 'app:login:member') {
                      setPreviewSurface('app')
                      setPreviewScreen('login')
                      setPreviewMemberMode(true)
                      return
                    }
                    setPreviewSurface('site')
                    refreshPublicPreview(value === 'site:privacy' ? '/privacy' : '/')
                  }}
                >
                  <option value="app:home:guest">Home · Guest</option>
                  <option value="app:home:member">Home · Member</option>
                  <option value="app:help:guest">도움 · Guest</option>
                  <option value="app:help:member">도움 · Member</option>
                  <option value="app:my:guest">My · Guest</option>
                  <option value="app:my:member">My · Member</option>
                  <option value="app:login:guest">Login · Guest</option>
                  <option value="app:login:member">Login · Member</option>
                  <option value="site:landing">Site · Landing</option>
                  <option value="site:privacy">Site · Privacy</option>
                </select>
              </label>
            </div>
            <span className="contentHeaderActionDivider" aria-hidden="true" />
            <div className="contentHeaderActionGroup contentHeaderActionGroupSave">
              <div className="contentHeaderActionRow">
                <button className="primaryBtn pageActionBtn pageActionBtnPrimary exploreHeaderActionBtn contentHeaderSaveBtn" disabled={saving || usingFallback || !isDirty} onClick={() => void onSave()}>
                  {saving ? '저장중' : t('admin.content.save', '저장')}
                </button>
                <button type="button" className="ghostBtn pageActionBtn exploreCompactGhostBtn" onClick={() => setPublishAtDraft(formatPublishNow())}>Today</button>
              </div>
              <label className="contentHeaderMiniField">
                <span>적용 시각</span>
                <input className="textInput contentHeaderActionInput" value={publishAtDraft} onChange={(e) => setPublishAtDraft(e.target.value)} placeholder="2026-04-28 10:30:00" />
              </label>
            </div>
            <span className="contentHeaderActionDivider" aria-hidden="true" />
            <div className="contentHeaderActionGroup">
              <button
                className="ghostBtn pageActionBtn exploreHeaderActionBtn"
                type="button"
                onClick={() => void reloadContentData()}
                disabled={saving}
              >
                {saving ? 'DATA...' : 'DATA'}
              </button>
            </div>
          </div>
        )}
      />

      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.content.warning.fallbackTitle', 'Live content config unavailable.')}</strong>{' '}
          {t('admin.content.warning.fallbackBody', '지금 form 값은 fallback/mock data일 수 있어서 저장 액션을 잠깐 막아두고 있어요.')}
          {fallbackMessage ? ` (${fallbackMessage})` : ''}
        </div>
      ) : null}

      {message ? <div className="saveMessage" style={{ marginBottom: 12 }}>{message}</div> : null}
      <div className="section sectionGrid">
        <div className="card exploreDenseCard exploreSheetCard contentSheetWorkspaceCard">
          <div className="sectionHeader contentSheetHeader" style={{ marginBottom: 10 }}>
            <h2 className="panelTitle" style={{ marginBottom: 0 }}>{currentSectionTitle}</h2>
            <span className="metaPill">fields {totalFields}</span>
          </div>

          {activeSection === 'brand' ? (
            <div className="sectionGrid contentSheetStack">
              <div className="contentSheetSectionTitleRow">
                <strong>기본 브랜딩</strong>
              </div>
              {renderFieldSheet(groupMap.branding.fields)}

              <div className="contentSheetSectionTitleRow">
                <strong>브랜드 자산</strong>
              </div>
              <div className="contentAssetGrid">
                <label className="field contentAssetMiniField">
                  <div className="fieldLabel">{t('admin.content.fields.logoType', '로고 타입')}</div>
                  <select className="textInput contentSheetInput" value={form.logoType} onChange={(e) => update('logoType', e.target.value as ContentSettings['logoType'])}>
                    {LOGO_TYPE_OPTIONS.map((option) => (
                      <option key={option.value} value={option.value}>{option.label}</option>
                    ))}
                  </select>
                </label>

                <label className="field contentAssetMiniField">
                  <div className="fieldLabel">{t('admin.content.fields.logoUpload', '로고 업로드')}</div>
                  <label className="uploadBox contentAssetUploadBox">
                    <input type="file" accept=".png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml" className="hiddenInput" onChange={(e) => { const file = e.target.files?.[0]; if (file) void onAssetUpload('logo', file) }} />
                    <div className="uploadTitle">{t('admin.content.fields.logoUploadSelect', '로고 파일 선택')}</div>
                    <div className="uploadDesc">{uploading === 'logo' ? t('admin.content.uploading', '업로드 중...') : t('admin.content.fields.logoUploadDesc', '직접 업로드해서 바로 연결')}</div>
                  </label>
                  {form.logoImageUrl ? <div className="saveMessage">{t('admin.content.fields.connected', '연결됨:')} {form.logoImageUrl}</div> : null}
                </label>

                <label className="field contentAssetMiniField">
                  <div className="fieldLabel">{t('admin.content.fields.splashUpload', '스플래시 이미지 업로드')}</div>
                  <label className="uploadBox contentAssetUploadBox">
                    <input type="file" accept=".png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp" className="hiddenInput" onChange={(e) => { const file = e.target.files?.[0]; if (file) void onAssetUpload('splash', file) }} />
                    <div className="uploadTitle">{t('admin.content.fields.splashUploadSelect', '스플래시 파일 선택')}</div>
                    <div className="uploadDesc">{uploading === 'splash' ? t('admin.content.uploading', '업로드 중...') : t('admin.content.fields.splashUploadDesc', '앱 시작 화면용 이미지 등록')}</div>
                  </label>
                  {form.splashImageUrl ? <div className="saveMessage">{t('admin.content.fields.connected', '연결됨:')} {form.splashImageUrl}</div> : null}
                </label>

                <label className="field contentAssetMiniField">
                  <div className="fieldLabel">{t('admin.content.fields.loginHeroUpload', '로그인 이미지 업로드')}</div>
                  <label className="uploadBox contentAssetUploadBox">
                    <input type="file" accept=".png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp" className="hiddenInput" onChange={(e) => { const file = e.target.files?.[0]; if (file) void onAssetUpload('loginHero', file) }} />
                    <div className="uploadTitle">{t('admin.content.fields.loginHeroUploadSelect', '로그인 이미지 파일 선택')}</div>
                    <div className="uploadDesc">{uploading === 'loginHero' ? t('admin.content.uploading', '업로드 중...') : t('admin.content.fields.loginHeroUploadDesc', '로그인 화면 상단 이미지 등록')}</div>
                  </label>
                  {form.loginHeroImageUrl ? <div className="saveMessage">{t('admin.content.fields.connected', '연결됨:')} {form.loginHeroImageUrl}</div> : null}
                </label>
              </div>
            </div>
          ) : null}

          {activeSection === 'app' ? (
            <div className="sectionGrid contentSheetStack">
              <div className="editorSubtabRow contentSheetSubtabs">
                {([
                  ['home', groupMap.home.title],
                  ['help', 'Explore / Help'],
                  ['saved', groupMap.saved.title],
                  ['scan', groupMap.scan.title],
                  ['detail', groupMap.detail.title],
                  ['saveComplete', groupMap.saveComplete.title],
                ] as const).map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    className={`editorSubtab ${appCopyTab === key ? 'active' : ''}`}
                    onClick={() => setAppCopyTab(key)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <div className="contentSheetSectionTitleRow">
                <strong>{activeAppGroup.title}</strong>
                <div className="compactMetaRow">
                  {appCopyTab === 'help' ? <span className="metaPill">Explore base copy</span> : null}
                  {appCopyTab === 'help' ? <span className="metaPill">Decision Copy는 Explore</span> : null}
                  <span className="metaPill">fields {activeAppGroup.fields.length}</span>
                </div>
              </div>
              {renderFieldSheet(activeAppGroup.fields)}
            </div>
          ) : null}

          {activeSection === 'account' ? (
            <div className="sectionGrid contentSheetStack">
              <div className="editorSubtabRow contentSheetSubtabs">
                {([
                  ['my', 'My'],
                  ['login', 'Login'],
                  ['guest', 'Guest drawer'],
                ] as const).map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    className={`editorSubtab ${accountTab === key ? 'active' : ''}`}
                    onClick={() => setAccountTab(key)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <div className="contentSheetSectionTitleRow">
                <strong>{accountTab === 'my' ? 'My copy' : accountTab === 'login' ? 'Login copy' : 'Guest drawer copy'}</strong>
                <span className="metaPill">fields {accountFieldGroups[accountTab].length}</span>
              </div>
              {renderFieldSheet(accountFieldGroups[accountTab])}
            </div>
          ) : null}

          {activeSection === 'public' ? (
            <div className="sectionGrid contentSheetStack">
              <div className="editorSubtabRow contentSheetSubtabs">
                {([
                  ['landing', 'Landing'],
                  ['privacy', 'Privacy'],
                ] as const).map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    className={`editorSubtab ${publicTab === key ? 'active' : ''}`}
                    onClick={() => setPublicTab(key)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <div className="contentSheetSectionTitleRow">
                <strong>{publicTab === 'landing' ? 'Landing copy' : 'Privacy copy'}</strong>
                <span className="metaPill">fields {publicSiteFieldGroups[publicTab].length}</span>
              </div>
              {renderFieldSheet(publicSiteFieldGroups[publicTab])}
            </div>
          ) : null}
        </div>

      </div>
    </div>
  )
}
