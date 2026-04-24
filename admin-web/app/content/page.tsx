'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'

import PageHeader from '../../components/PageHeader'
import { useAdminCopy } from '../../components/AdminCopyProvider'
import { fetchJsonSafe, isUnauthorizedError, postFormData, putJson } from '../../lib/api'
import { mockContentSettings } from '../../lib/mock'

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

type FieldConfig = {
  key: keyof ContentSettings
  label: string
  kind?: 'text' | 'textarea'
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
      ],
    },
    {
      title: t('admin.content.groups.help.title', '도움 탭 카피'),
      description: t('admin.content.groups.help.desc', '중간 도움 탭 문구'),
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
        { key: 'myGuestModeLabel', label: t('admin.content.fields.myGuestModeLabel', '게스트 모드 라벨') },
        { key: 'myLoginAction', label: t('admin.content.fields.myLoginAction', '로그인 버튼') },
        { key: 'myLogoutAction', label: t('admin.content.fields.myLogoutAction', '로그아웃 버튼') },
        { key: 'myLinkedDoneMessage', label: t('admin.content.fields.myLinkedDoneMessage', '계정 연결 완료 문구') },
        { key: 'myLogoutDoneMessage', label: t('admin.content.fields.myLogoutDoneMessage', '로그아웃 완료 문구') },
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
        { key: 'saveCompleteViewSavedAction', label: t('admin.content.fields.saveCompleteViewSavedAction', '지난 카트 보기 버튼') },
      ],
    },
  ]
}

function groupAnchorId(title: string, index: number) {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9가-힣]+/g, '-')
    .replace(/^-+|-+$/g, '')
  return `content-group-${index + 1}-${slug || 'section'}`
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
  const previewFrameRef = useRef<HTMLIFrameElement | null>(null)
  const groups = buildGroups(t)
  const groupNav = groups.map((group, index) => ({ ...group, id: groupAnchorId(group.title, index) }))
  const totalFields = groupNav.reduce((sum, group) => sum + group.fields.length, 0)

  useEffect(() => {
    setPreviewSrc(`/app-preview/index.html?v=${Date.now()}`)
  }, [])

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const res = await fetchJsonSafe<{ ok: boolean; data: ContentSettings }>('/admin/content', { ok: true, data: mockContentSettings })
        if (cancelled) return
        setForm(res.data.data)
        setUsingFallback(res.usingFallback)
        setFallbackMessage(res.fallbackMessage)
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

  function renderField(field: FieldConfig) {
    const value = String(form[field.key] ?? '')
    return (
      <label className="field" key={String(field.key)}>
        <div className="fieldLabel">{field.label}</div>
        {field.kind === 'textarea' ? (
          <textarea className="textInput" rows={3} value={value} onChange={(e) => update(field.key, e.target.value as ContentSettings[typeof field.key])} />
        ) : (
          <input className="textInput" value={value} onChange={(e) => update(field.key, e.target.value as ContentSettings[typeof field.key])} />
        )}
      </label>
    )
  }

  function postPreviewPayload() {
    previewFrameRef.current?.contentWindow?.postMessage(
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

  useEffect(() => {
    postPreviewPayload()
  }, [form, previewScreen, previewMemberMode])

  async function onSave() {
    if (usingFallback) {
      setMessage(t('admin.content.fallbackActionBlocked', 'fallback/mock 데이터를 보고 있는 동안에는 저장을 막아둘게'))
      return
    }

    setSaving(true)
    setMessage(null)
    try {
      await putJson<{ ok: boolean; data: ContentSettings }>('/admin/content', form)
      setMessage(t('admin.content.saveDone', '콘텐츠 설정 저장 완료'))
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

  return (
    <div>
      <PageHeader
        badge={usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : t('admin.common.badge.live', 'Live data')}
        title={t('admin.content.title', 'Content')}
        description={t('admin.content.desc', '앱 문구와 로고 관리')}
      />

      {usingFallback ? (
        <div className="loginError" style={{ marginBottom: 16, borderColor: '#b45309', background: '#fff7ed', color: '#9a3412' }}>
          <strong>{t('admin.content.warning.fallbackTitle', 'Live content config unavailable.')}</strong>{' '}
          {t('admin.content.warning.fallbackBody', '지금 form 값은 fallback/mock data일 수 있어서 저장 액션을 잠깐 막아두고 있어요.')}
          {fallbackMessage ? ` (${fallbackMessage})` : ''}
        </div>
      ) : null}

      <div className="metaRow" style={{ marginBottom: 16 }}>
        <span className="metaPill">{t('admin.content.meta.groups', 'groups')} {groupNav.length}</span>
        <span className="metaPill">{t('admin.content.meta.fields', 'fields')} {totalFields}</span>
        <span className="metaPill">{t('admin.content.meta.preview', 'preview')} {previewScreen} · {previewMemberMode ? 'member' : 'guest'}</span>
        <span className="metaPill">{usingFallback ? t('admin.common.badge.fallback', 'Fallback data') : t('admin.common.badge.live', 'Live data')}</span>
      </div>

      <div className="section sectionGrid twoCol">
        <div className="sectionGrid">
          <div className="card">
            <h2 className="panelTitle">{t('admin.content.quickJump.title', '빠른 이동 & 저장')}</h2>
            <p className="pageDesc" style={{ marginTop: 0, marginBottom: 16 }}>
              {t('admin.content.quickJump.desc', '긴 폼이라서 필요한 그룹으로 바로 이동하고, 현재 preview/save 상태를 같이 보자.')}
            </p>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
              {groupNav.map((group) => (
                <a key={group.id} className="ghostBtn ghostBtnSmall" href={`#${group.id}`}>
                  {group.title}
                </a>
              ))}
              <a className="ghostBtn ghostBtnSmall" href="#content-preview-card">
                {t('admin.content.quickJump.preview', '프리뷰로 이동')}
              </a>
            </div>
            <div className="metaRow" style={{ marginTop: 0, marginBottom: 16 }}>
              <span className="metaPill">{t('admin.content.quickJump.previewState', 'preview state')} {previewScreen} / {previewMemberMode ? 'member' : 'guest'}</span>
              <span className="metaPill">{saving ? t('admin.content.saving', '저장 중...') : t('admin.content.quickJump.ready', '편집 가능')}</span>
            </div>
            <div className="buttonRow" style={{ marginTop: 0 }}>
              <button className="primaryBtn" disabled={saving || usingFallback} onClick={() => void onSave()}>
                {saving ? t('admin.content.saving', '저장 중...') : t('admin.content.save', '저장')}
              </button>
              {message ? <div className="saveMessage">{message}</div> : null}
            </div>
          </div>

          <div className="card">
            <h2 className="panelTitle">{t('admin.content.assets.title', '브랜드 자산')}</h2>
            <div className="formGrid">
              <label className="field">
                <div className="fieldLabel">{t('admin.content.fields.logoType', '로고 타입')}</div>
                <select className="textInput" value={form.logoType} onChange={(e) => update('logoType', e.target.value as ContentSettings['logoType'])}>
                  {LOGO_TYPE_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>{option.label}</option>
                  ))}
                </select>
              </label>

              <label className="field">
                <div className="fieldLabel">{t('admin.content.fields.logoUpload', '로고 업로드')}</div>
                <label className="uploadBox">
                  <input type="file" accept=".png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml" className="hiddenInput" onChange={(e) => { const file = e.target.files?.[0]; if (file) void onAssetUpload('logo', file) }} />
                  <div className="uploadTitle">{t('admin.content.fields.logoUploadSelect', '로고 파일 선택')}</div>
                  <div className="uploadDesc">{uploading === 'logo' ? t('admin.content.uploading', '업로드 중...') : t('admin.content.fields.logoUploadDesc', '직접 업로드해서 바로 연결')}</div>
                </label>
                {form.logoImageUrl ? <div className="saveMessage">{t('admin.content.fields.connected', '연결됨:')} {form.logoImageUrl}</div> : null}
              </label>

              <label className="field">
                <div className="fieldLabel">{t('admin.content.fields.splashUpload', '스플래시 이미지 업로드')}</div>
                <label className="uploadBox">
                  <input type="file" accept=".png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp" className="hiddenInput" onChange={(e) => { const file = e.target.files?.[0]; if (file) void onAssetUpload('splash', file) }} />
                  <div className="uploadTitle">{t('admin.content.fields.splashUploadSelect', '스플래시 파일 선택')}</div>
                  <div className="uploadDesc">{uploading === 'splash' ? t('admin.content.uploading', '업로드 중...') : t('admin.content.fields.splashUploadDesc', '앱 시작 화면용 이미지 등록')}</div>
                </label>
                {form.splashImageUrl ? <div className="saveMessage">{t('admin.content.fields.connected', '연결됨:')} {form.splashImageUrl}</div> : null}
              </label>

              <label className="field">
                <div className="fieldLabel">{t('admin.content.fields.loginHeroUpload', '로그인 이미지 업로드')}</div>
                <label className="uploadBox">
                  <input type="file" accept=".png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp" className="hiddenInput" onChange={(e) => { const file = e.target.files?.[0]; if (file) void onAssetUpload('loginHero', file) }} />
                  <div className="uploadTitle">{t('admin.content.fields.loginHeroUploadSelect', '로그인 이미지 파일 선택')}</div>
                  <div className="uploadDesc">{uploading === 'loginHero' ? t('admin.content.uploading', '업로드 중...') : t('admin.content.fields.loginHeroUploadDesc', '로그인 화면 상단 이미지 등록')}</div>
                </label>
                {form.loginHeroImageUrl ? <div className="saveMessage">{t('admin.content.fields.connected', '연결됨:')} {form.loginHeroImageUrl}</div> : null}
              </label>
            </div>
          </div>

          {groupNav.map((group) => (
            <div className="card" key={group.id} id={group.id}>
              <div className="sectionHeader">
                <div>
                  <h2 className="panelTitle" style={{ marginBottom: 6 }}>{group.title}</h2>
                  <p className="pageDesc" style={{ marginTop: 0, marginBottom: 0 }}>{group.description}</p>
                </div>
                <span className="metaPill">{t('admin.content.group.fieldCount', 'fields')} {group.fields.length}</span>
              </div>
              <div className="formGrid">{group.fields.map(renderField)}</div>
            </div>
          ))}
        </div>

        <div className="sectionGrid">
          <div className="card" id="content-preview-card">
            <h2 className="panelTitle">{t('admin.content.preview.title', '프리뷰')}</h2>
            <div className="previewCard" style={{ display: 'grid', gap: 12 }}>
              <div className="previewSubtitle">
                {t('admin.content.preview.realApp', '실제 Flutter UI 기반 preview야. 편집 중인 값이 바로 반영돼.')}
              </div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {([
                  ['home', 'Home'],
                  ['help', '도움'],
                  ['my', 'My'],
                  ['login', 'Login'],
                ] as const).map(([value, label]) => (
                  <button
                    key={value}
                    type="button"
                    className="ghostBtn"
                    onClick={() => setPreviewScreen(value)}
                    style={{
                      background: previewScreen === value ? '#111827' : '#fff',
                      color: previewScreen === value ? '#fff' : '#111827',
                      borderColor: previewScreen === value ? '#111827' : 'rgba(15,23,42,0.12)',
                    }}
                  >
                    {label}
                  </button>
                ))}
                <button
                  type="button"
                  className="ghostBtn"
                  onClick={() => setPreviewMemberMode(false)}
                  style={{
                    background: !previewMemberMode ? '#e11d48' : '#fff',
                    color: !previewMemberMode ? '#fff' : '#e11d48',
                    borderColor: '#e11d48',
                  }}
                >
                  Guest
                </button>
                <button
                  type="button"
                  className="ghostBtn"
                  onClick={() => setPreviewMemberMode(true)}
                  style={{
                    background: previewMemberMode ? '#111827' : '#fff',
                    color: previewMemberMode ? '#fff' : '#111827',
                    borderColor: 'rgba(15,23,42,0.12)',
                  }}
                >
                  Member
                </button>
              </div>
              {previewSrc ? (
                <iframe
                  key={previewSrc}
                  ref={previewFrameRef}
                  title="Cartly app preview"
                  src={previewSrc}
                  onLoad={() => postPreviewPayload()}
                  style={{
                    width: '100%',
                    minHeight: 980,
                    border: '1px solid rgba(15,23,42,0.08)',
                    borderRadius: 24,
                    background: '#fff',
                  }}
                />
              ) : (
                <div
                  style={{
                    width: '100%',
                    minHeight: 980,
                    border: '1px solid rgba(15,23,42,0.08)',
                    borderRadius: 24,
                    background: '#fff',
                    display: 'grid',
                    placeItems: 'center',
                    color: '#64748b',
                    fontWeight: 700,
                  }}
                >
                  preview 불러오는 중...
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
