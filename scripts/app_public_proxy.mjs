import fs from 'node:fs/promises'
import http from 'node:http'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const port = Number(process.env.APP_PUBLIC_PROXY_PORT || '3100')
const host = process.env.APP_PUBLIC_PROXY_HOST || '127.0.0.1'
const backendBase = (process.env.APP_PUBLIC_PROXY_BACKEND_BASE || process.env.CARTLY_API_BASE || process.env.CARTLY_API_BASE || 'http://127.0.0.1:8011').replace(/\/$/, '')
const scriptsDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.dirname(scriptsDir)
const publicSiteDir = path.join(scriptsDir, 'public-site')

const allowedExact = new Set(['/v1/app-config', '/v1/carts', '/v1/receipts', '/health'])
const publicAssetRoutes = new Map([
  ['/site.css', path.join(publicSiteDir, 'site.css')],
  ['/site-media/intro.png', path.join(repoRoot, 'assets/images/intro.png')],
  ['/site-media/home.png', path.join(repoRoot, 'assets/images/public-site/home.png')],
  ['/site-media/explore.png', path.join(repoRoot, 'assets/images/public-site/explore.png')],
  ['/site-media/scan.svg', path.join(repoRoot, 'assets/images/public-site/scan.svg')],
  ['/site-media/scan-real-v2.jpg', path.join(repoRoot, 'assets/images/public-site/scan-real-v2.jpg')],
  ['/site-media/my.png', path.join(repoRoot, 'assets/images/public-site/my.png')],
  ['/site-media/login.png', path.join(repoRoot, 'assets/images/public-site/login.png')],
  ['/site-media/ipad-home.png', path.join(repoRoot, 'assets/images/public-site/ipad-home.png')],
  ['/site-media/app-icon.png', path.join(repoRoot, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')],
])
const dynamicLandingRoutes = new Set(['/', '/partners', '/partners/'])
const dynamicPrivacyRoutes = new Set(['/privacy', '/privacy/'])
const dynamicSupportRoutes = new Set(['/support', '/support/'])
const supportEmail = 'scancart.wimc@gmail.com'
const businessEmail = 'gabriel.paik@gmail.com'
const currentAppVersionLabel = '앱 버전 1.0.4 (25)'
const defaultLogoImageUrl = 'https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg'
const defaultSplashImageUrl = 'https://scan-api.seoa-nas.com/assets/branding/cartly_splash_default.png'
const fallbackLogoUrl = '/assets/branding/cartly_logo_vectorized.svg'
const fallbackAppIconUrl = '/site-media/app-icon.png'
const supportUrl = 'https://scan-api.seoa-nas.com/support'
const allowedPrefixes = [
  '/v1/auth/',
  '/v1/scan/',
  '/v1/carts/',
  '/v1/receipts/',
  '/v1/events/',
  '/v1/ads/',
  '/v1/push/',
  '/v1/households/',
  '/assets/branding/',
  '/assets/ads/',
]

const fallbackAppConfig = {
  branding: {
    logoType: 'image',
    logoText: 'Cartly',
    logoImageUrl: defaultLogoImageUrl,
    splashImageUrl: defaultSplashImageUrl,
    loginHeroImageUrl: null,
  },
  copy: {
    publicSite: {
      eyebrow: `Cartly · ${currentAppVersionLabel}`,
      heroTitle: '장보기 기록과 대체안 탐색',
      heroBody: '스캔한 상품, 현재 카트, 저장한 기록을 한 흐름으로 정리합니다.',
      primaryCtaLabel: '흐름 보기',
      secondaryCtaLabel: '개인정보',
      heroPoints: '상품 스캔과 카트 정리\n저장 기록 관리\n같은 구매 의도 기준 후보 다시 보기',
      enabledSections: 'hero,flow,status,partnerReview,linkPlacement',
      sectionOrder: 'hero,flow,status,partnerReview,linkPlacement',
      flowTitle: '핵심 흐름',
      flowBody: '스캔, 카트 검토, 저장, 다시 비교를 한 흐름으로 잇습니다.',
      statusTitle: '지원 범위',
      statusPoints: `${currentAppVersionLabel}\niPhone 중심 제공, iPad 사용 가능\nOCR 스캔, 현재 카트, 저장 카트, 영수증 연동`,
      partnerReviewTitle: '외부 링크 원칙',
      partnerReviewPoints: '장보기 판단 맥락 안에서만 노출됩니다.\n사용자 선택 없이 외부 링크를 열지 않습니다.\n같은 구매 의도를 유지하는 후보만 다룹니다.',
      linkPlacementTitle: '후보를 다시 보는 위치',
      linkPlacementBody: '이미 검토한 상품과 가까운 맥락에서만 다시 보여줍니다.',
      linkPlacementPoints: '최근 스캔 후 미확정 상품\n현재 카트의 핵심 후보\n저장 기록에서 다시 볼 품목',
      privacyTitle: '개인정보 및 외부 링크 안내',
      privacyIntro: '상품 정보, 저장 기록, 현재 위치 또는 대략적 지역 정보를 바탕으로 장보기 판단과 근처 마트 할인정보 확인을 돕습니다.',
      privacyCollectionTitle: '수집 및 사용',
      privacyCollectionPoints: '상품명, 가격, 수량, 저장 카트 제목 등 장보기 기록\n스캔 이미지와 인식 결과\n현재 위치 또는 대략적 지역 정보(근처 마트 할인정보 확인 목적)\n품질 개선을 위한 최소 운영 로그',
      privacyExternalTitle: '외부 링크',
      privacyExternalBody: '외부 쇼핑 링크는 Explore에서 특정 후보를 선택했을 때만 열립니다. 자동 리디렉션은 사용하지 않습니다.',
      privacyStatusTitle: '현재 상태',
      privacyStatusBody: `현재 안내는 ${currentAppVersionLabel} 기준입니다. 외부 링크는 비교와 검토를 돕는 경우에만 사용됩니다.`,
      privacyBackAction: '메인 페이지로 돌아가기',
    },
  },
}

function isAllowedPath(pathname) {
  if (allowedExact.has(pathname)) return true
  return allowedPrefixes.some((prefix) => pathname.startsWith(prefix))
}

function contentTypeFor(filePath) {
  const ext = path.extname(filePath).toLowerCase()
  if (ext === '.html') return 'text/html; charset=utf-8'
  if (ext === '.css') return 'text/css; charset=utf-8'
  if (ext === '.png') return 'image/png'
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg'
  if (ext === '.webp') return 'image/webp'
  if (ext === '.svg') return 'image/svg+xml; charset=utf-8'
  return 'application/octet-stream'
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function splitLines(value) {
  return String(value ?? '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
}

function pickPublicSiteConfig(appConfig) {
  const branding = appConfig?.branding ?? fallbackAppConfig.branding
  const publicSite = appConfig?.copy?.publicSite ?? fallbackAppConfig.copy.publicSite
  return {
    branding: {
      logoType: branding.logoType ?? fallbackAppConfig.branding.logoType,
      logoText: branding.logoText ?? fallbackAppConfig.branding.logoText,
      logoImageUrl: branding.logoImageUrl ?? fallbackAppConfig.branding.logoImageUrl,
      splashImageUrl: branding.splashImageUrl ?? fallbackAppConfig.branding.splashImageUrl,
      loginHeroImageUrl: branding.loginHeroImageUrl ?? fallbackAppConfig.branding.loginHeroImageUrl,
    },
    publicSite: {
      ...fallbackAppConfig.copy.publicSite,
      ...publicSite,
    },
  }
}

async function fetchAppConfig() {
  try {
    const upstream = await fetch(`${backendBase}/v1/app-config`, {
      headers: { accept: 'application/json' },
      signal: AbortSignal.timeout(1500),
    })
    if (!upstream.ok) {
      throw new Error(`app-config status ${upstream.status}`)
    }
    const payload = await upstream.json()
    return pickPublicSiteConfig(payload?.data)
  } catch (error) {
    console.warn('[app-public-proxy] app-config fallback', error)
    return pickPublicSiteConfig(fallbackAppConfig)
  }
}

function renderBulletList(lines) {
  return splitLines(lines)
    .map((line) => `<li>${escapeHtml(line)}</li>`)
    .join('')
}

function siteLogoUrl(branding) {
  return branding.logoImageUrl || fallbackLogoUrl
}

function siteAppIconUrl() {
  return fallbackAppIconUrl
}

function heroImageUrl(branding) {
  return branding.loginHeroImageUrl || branding.splashImageUrl || '/site-media/home.png'
}

function renderBranding(branding, mode = 'hero') {
  const logoUrl = siteLogoUrl(branding)
  const appIconUrl = siteAppIconUrl()
  const logoImage = logoUrl ? `<img class="brand-wordmark" src="${escapeHtml(logoUrl)}" alt="${escapeHtml(branding.logoText || 'Cartly')}" />` : `<span class="brand-name">${escapeHtml(branding.logoText || 'Cartly')}</span>`

  if (mode === 'header') {
    const mark = appIconUrl ? `<img class="brand-app-icon" src="${escapeHtml(appIconUrl)}" alt="${escapeHtml(branding.logoText || 'Cartly')} app icon" />` : ''
    return `<div class="brand-lockup">${mark}${logoImage}</div>`
  }

  if (mode === 'footer') {
    const mark = appIconUrl ? `<img class="brand-app-icon footer-app-icon" src="${escapeHtml(appIconUrl)}" alt="${escapeHtml(branding.logoText || 'Cartly')} app icon" />` : ''
    return `<div class="brand-lockup footer-brand-lockup">${mark}${logoImage}</div>`
  }

  const heroMark = appIconUrl ? `<img class="hero-brand-mark" src="${escapeHtml(appIconUrl)}" alt="${escapeHtml(branding.logoText || 'Cartly')} app icon" />` : ''
  return `<div class="hero-brand-row">${heroMark}${logoImage}</div>`
}

const landingSectionIds = ['hero', 'flow', 'status', 'partnerReview', 'linkPlacement']

function parseSectionList(value, fallback) {
  const requested = String(value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .filter((item) => landingSectionIds.includes(item))
  return requested.length > 0 ? requested : fallback
}

function buildLandingSectionPlan(publicSite) {
  const enabled = parseSectionList(publicSite.enabledSections, landingSectionIds)
  const order = parseSectionList(publicSite.sectionOrder, landingSectionIds)
  const orderedVisible = order.filter((sectionId) => enabled.includes(sectionId))
  const remainder = enabled.filter((sectionId) => !orderedVisible.includes(sectionId))
  return [...orderedVisible, ...remainder]
}

function renderScreenshotGallery() {
  return `<section class="grid" id="section-screenshots">
      <article class="card">
        <h2>실제 서비스 화면</h2>
        <p>현재 서비스 화면입니다. 스캔, 카트 검토, Explore 흐름을 확인할 수 있습니다.</p>
        <div class="shot-grid">
          <figure class="shot">
            <img src="/site-media/home.png" alt="Cartly iPhone home screen" />
            <figcaption>홈과 카트 중심 화면. 최근 장보기 맥락과 저장 흐름을 한곳에 모읍니다.</figcaption>
          </figure>
          <figure class="shot">
            <img src="/site-media/explore.png" alt="Cartly iPhone explore screen" />
            <figcaption>Explore 화면. 같은 구매 의도 안에서 다시 볼 대체안을 정리합니다.</figcaption>
          </figure>
        </div>
        <p class="inline-note">iPad는 별도 메인 비주얼 없이도 사용할 수 있는 수준으로 지원합니다.</p>
      </article>
    </section>`
}

function renderLandingSection(sectionId, publicSite) {
  if (sectionId === 'hero') {
    return ''
  }

  if (sectionId === 'flow') {
    return `<section class="grid two" id="section-flow">
        <article class="card emphasis">
          <h2>${escapeHtml(publicSite.flowTitle)}</h2>
          <p>${escapeHtml(publicSite.flowBody)}</p>
          <ol class="steps">
            <li><strong>Scan</strong> 상품을 촬영하거나 직접 추가합니다.</li>
            <li><strong>Review</strong> 인식 결과를 확인하고 현재 카트에 담습니다.</li>
            <li><strong>Explore</strong> 같은 상품군 안에서 다시 볼 후보와 대체안을 정리합니다.</li>
            <li><strong>Save</strong> 장보기 결과를 저장해 다음 구매 판단에 이어서 활용합니다.</li>
          </ol>
        </article>
        <article class="card">
          <h2>왜 이 흐름이 중요한가</h2>
          <div class="metric"><strong>1</strong><span>상품 스캔부터 저장까지 한 흐름 안에서 이어집니다.</span></div>
          <div class="metric"><strong>2</strong><span>대체안은 무관한 광고 피드가 아니라 기존 구매 의도에 맞춰 정리됩니다.</span></div>
          <div class="metric"><strong>3</strong><span>외부 이동은 사용자가 직접 선택한 경우에만 발생합니다.</span></div>
        </article>
      </section>
      ${renderScreenshotGallery()}`
  }

  if (sectionId === 'status') {
    return `<section class="grid two" id="section-status">
        <article class="card">
          <h2>${escapeHtml(publicSite.statusTitle)}</h2>
          <ul class="bullet-list">${renderBulletList(publicSite.statusPoints)}</ul>
        </article>
        <article class="card">
          <h2>현재 제품 톤</h2>
          <p>Cartly는 장보기 전체를 자동으로 대신 결정하는 서비스가 아니라, 이미 진행 중인 구매 판단을 더 잘 정리하도록 돕는 개인용 도구에 가깝습니다.</p>
        </article>
      </section>`
  }

  if (sectionId === 'partnerReview') {
    return `<section class="grid two" id="section-partner-review">
        <article class="card emphasis">
          <h2>${escapeHtml(publicSite.partnerReviewTitle)}</h2>
          <ul class="bullet-list">${renderBulletList(publicSite.partnerReviewPoints)}</ul>
        </article>
        <article class="card">
          <h2>검토 기준</h2>
          <p>링크 배치는 사용자가 이미 보고 있는 상품, 카트, 저장 기록과의 관련성을 기준으로 제한합니다. 제품 소개에서도 그 범위를 넘는 표현은 사용하지 않습니다.</p>
        </article>
      </section>`
  }

  if (sectionId === 'linkPlacement') {
    return `<section class="grid two" id="section-link-placement">
        <article class="card">
          <h2>${escapeHtml(publicSite.linkPlacementTitle)}</h2>
          <p>${escapeHtml(publicSite.linkPlacementBody)}</p>
          <ul class="bullet-list">${renderBulletList(publicSite.linkPlacementPoints)}</ul>
        </article>
        <article class="card">
          <h2>지원 및 문의</h2>
          <p>서비스 사용, 계정 문제, 개인정보 문의는 아래 메일로 받고 있습니다.</p>
          <p><strong>고객 지원 · <a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a></strong></p>
          <p><strong>비즈니스 제안 · <a href="mailto:${escapeHtml(businessEmail)}">${escapeHtml(businessEmail)}</a></strong></p>
          <p><a class="button secondary" href="${escapeHtml(supportUrl)}">지원 페이지</a></p>
        </article>
      </section>`
  }

  return ''
}

function buildLandingHtml(config) {
  const { branding, publicSite } = config
  const featureItems = [
    {
      id: 'scan',
      label: '상품 스캔',
      image: '/site-media/scan-real-v2.jpg',
      title: '상품 스캔',
      body: '촬영하거나 직접 추가한 상품을 현재 카트 흐름으로 바로 이어갑니다.',
    },
    {
      id: 'current',
      label: '현재 카트',
      image: '/site-media/home.png',
      title: '현재 카트',
      body: '지금 담은 상품과 합계를 바로 확인하고 저장 여부를 판단합니다.',
    },
    {
      id: 'saved',
      label: '저장한 장보기 기록',
      image: '/site-media/my.png',
      title: '저장한 장보기 기록',
      body: '지난 장보기 기록을 다시 열어 다음 구매 판단에 이어서 활용합니다.',
    },
    {
      id: 'explore',
      label: '대체안 다시 보기',
      image: '/site-media/explore.png',
      title: '대체안 다시 보기',
      body: '같은 구매 의도 안에서 다시 볼 후보를 모읍니다.',
    },
    {
      id: 'account',
      label: '내 정보와 가족공유',
      image: '/site-media/my.png',
      title: '내 정보와 가족공유',
      body: '회원 관리와 가족공유 상태를 한 화면에서 확인합니다.',
    },
    {
      id: 'login',
      label: '로그인과 회원 시작',
      image: '/site-media/login.png',
      title: '로그인과 회원 시작',
      body: '게스트 시작과 회원 전환 흐름을 현재 앱 화면 기준으로 보여줍니다.',
    },
  ]
  const initialFeature = featureItems[0]
  const footerLogo = siteLogoUrl(branding)
    ? `<img class="brand-wordmark footer-wordmark" src="${escapeHtml(siteLogoUrl(branding))}" alt="${escapeHtml(branding.logoText || 'Cartly')}" />`
    : `<strong class="footer-brand-text">${escapeHtml(branding.logoText || 'Cartly')}</strong>`
  const featureButtons = featureItems
    .map(
      (item, index) => `<button class="feature-tab${index === 0 ? ' active' : ''}" type="button" data-feature-id="${escapeHtml(item.id)}" data-feature-image="${escapeHtml(item.image)}" data-feature-title="${escapeHtml(item.title)}" data-feature-body="${escapeHtml(item.body)}">${escapeHtml(item.label)}</button>`,
    )
    .join('')
  const featureThumbs = featureItems
    .map(
      (item, index) => `<button class="feature-thumb${index === 0 ? ' active' : ''}" type="button" data-feature-id="${escapeHtml(item.id)}" data-feature-image="${escapeHtml(item.image)}" data-feature-title="${escapeHtml(item.title)}" data-feature-body="${escapeHtml(item.body)}"><img src="${escapeHtml(item.image)}" alt="${escapeHtml(item.title)}" /><span>${escapeHtml(item.label)}</span></button>`,
    )
    .join('')
  return `<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(branding.logoText || 'Cartly')} | Smart grocery planning and same-intent alternatives</title>
    <meta name="description" content="${escapeHtml(publicSite.heroBody)}" />
    <link rel="stylesheet" href="/site.css" />
  </head>
  <body>
    <main class="page">
      <header class="topbar">
        ${renderBranding(branding, 'header')}
        <nav class="topnav">
          <a class="nav-link" href="/">소개</a>
          <a class="nav-link" href="/privacy">개인정보</a>
          <a class="nav-link" href="/support">지원</a>
        </nav>
      </header>

      <section class="hero" id="section-hero">
        <div class="hero-copy">
          <div class="eyebrow">${escapeHtml(publicSite.eyebrow)}</div>
          <h1>${escapeHtml(publicSite.heroTitle)}</h1>
          <p class="lede">${escapeHtml(publicSite.heroBody)}</p>
          <p class="hero-intro">Cartly는 장보기 기록, 현재 카트, 대체안 탐색을 한 흐름으로 이어 주는 개인 장보기 도구입니다. 스캔으로 시작해 저장과 재검토까지 끊기지 않게 연결합니다.</p>
          <div class="hero-pillar-grid">
            <div class="hero-pillar"><strong>현재 카트</strong><span>지금 담은 상품과 합계를 빠르게 확인</span></div>
            <div class="hero-pillar"><strong>저장 기록</strong><span>지난 장보기를 다시 열어 비교와 재사용</span></div>
            <div class="hero-pillar"><strong>대체안 탐색</strong><span>같은 구매 의도 안에서 다시 볼 후보 정리</span></div>
          </div>
          <div class="cta-row">
            <a class="button primary" href="#section-features">${escapeHtml(publicSite.primaryCtaLabel)}</a>
            <a class="button secondary" href="/privacy">${escapeHtml(publicSite.secondaryCtaLabel)}</a>
          </div>
          <div class="hero-meta">
            <div><strong>핵심 흐름</strong><span>Scan, Review, Save, Explore</span></div>
            <div><strong>지원 디바이스</strong><span>iPhone 중심 제공, iPad 사용 가능</span></div>
          </div>
          <div class="hero-scope">
            <strong>현재 지원 범위</strong>
            <ul class="scope-grid">
              <li>OCR 상품 스캔</li>
              <li>현재 카트 관리</li>
              <li>저장한 장보기 기록</li>
              <li>대체안 다시 보기</li>
              <li>영수증 반영</li>
              <li>회원, 게스트, 가족공유</li>
            </ul>
          </div>
        </div>
        <div class="hero-visual">
          <div class="visual-head">
            <strong>실제 앱 화면</strong>
            <span>기능을 누르면 대표 화면이 바뀝니다.</span>
          </div>
          <div class="feature-preview-shell">
            <div class="device-frame preview-frame">
              <img id="feature-preview-image" src="${escapeHtml(initialFeature.image)}" alt="${escapeHtml(initialFeature.title)}" />
            </div>
          </div>
          <div class="feature-tabs" id="section-features">${featureButtons}</div>
          <div class="feature-thumb-grid">${featureThumbs}</div>
          <div class="feature-summary">
            <strong id="feature-preview-title">${escapeHtml(initialFeature.title)}</strong>
            <p id="feature-preview-body">${escapeHtml(initialFeature.body)}</p>
          </div>
        </div>
      </section>

      <section class="content-section">
        <div class="section-kicker">Cartly가 하는 일</div>
        <h2>장보기 기록, 현재 카트, 대체안 검토를 한 흐름으로 연결합니다.</h2>
        <p>단순한 쇼핑 메모가 아니라, 장보기 판단의 앞뒤 맥락을 정리하는 구조로 설계했습니다. 현재 제공하는 기능만 설명하고, 외부 링크는 사용자가 직접 고른 경우에만 엽니다.</p>
      </section>

      <section class="content-section three-up">
        <div>
          <div class="section-kicker">기록</div>
          <p>스캔한 상품과 현재 카트, 저장한 장보기 기록이 분리되지 않고 한 흐름으로 이어집니다.</p>
        </div>
        <div>
          <div class="section-kicker">비교</div>
          <p>대체안은 무관한 광고 피드가 아니라, 이미 진행 중인 구매 의도 안에서 다시 검토할 후보로 정리됩니다.</p>
        </div>
        <div>
          <div class="section-kicker">재방문</div>
          <p>한 번 저장한 기록은 다음 장보기 판단의 출발점이 되어 반복 구매와 대체안 검토에 이어집니다.</p>
        </div>
      </section>

      <section class="content-section compact">
        <div>
          <div class="section-kicker">운영 원칙</div>
          <ul class="bullet-list compact-list">
            <li>현재 제공하는 실제 앱 기능만 소개합니다.</li>
            <li>외부 링크는 사용자가 직접 선택한 경우에만 엽니다.</li>
            <li>장보기 판단과 무관한 과장 표현은 사용하지 않습니다.</li>
          </ul>
        </div>
        <div>
          <div class="section-kicker">지원 및 문의</div>
          <div class="contact-lines">
            <p><strong>고객 지원</strong> <a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a></p>
            <p><strong>비즈니스 제안</strong> <a href="mailto:${escapeHtml(businessEmail)}">${escapeHtml(businessEmail)}</a></p>
            <p><strong>개인정보 안내</strong> <a href="/privacy">개인정보 페이지</a></p>
          </div>
        </div>
      </section>

      <footer class="footer footer-inline">
        <div class="footer-inline-row">
          ${footerLogo}
          <span class="footer-version">${escapeHtml(currentAppVersionLabel)}</span>
          <span class="footer-inline-copy">지원: <a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a> · 제안: <a href="mailto:${escapeHtml(businessEmail)}">${escapeHtml(businessEmail)}</a> · <a href="/support">지원 안내</a></span>
        </div>
      </footer>
    </main>
    <script>
      (() => {
        const tabs = Array.from(document.querySelectorAll('.feature-tab'))
        const thumbs = Array.from(document.querySelectorAll('.feature-thumb'))
        const image = document.getElementById('feature-preview-image')
        const title = document.getElementById('feature-preview-title')
        const body = document.getElementById('feature-preview-body')
        if (!tabs.length || !image || !title || !body) return
        const bindItem = (item) => {
          item.addEventListener('click', () => {
            tabs.forEach((tab) => tab.classList.remove('active'))
            thumbs.forEach((thumb) => thumb.classList.remove('active'))
            const id = item.dataset.featureId || ''
            tabs.forEach((tab) => {
              if ((tab.dataset.featureId || '') === id) tab.classList.add('active')
            })
            thumbs.forEach((thumb) => {
              if ((thumb.dataset.featureId || '') === id) thumb.classList.add('active')
            })
            image.setAttribute('src', item.dataset.featureImage || '')
            image.setAttribute('alt', item.dataset.featureTitle || 'Cartly preview')
            title.textContent = item.dataset.featureTitle || ''
            body.textContent = item.dataset.featureBody || ''
          })
        }
        tabs.forEach(bindItem)
        thumbs.forEach(bindItem)
      })()
    </script>
  </body>
</html>`
}

function buildPrivacyHtml(config) {
  const { branding, publicSite } = config
  return `<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(branding.logoText || 'Cartly')} Privacy</title>
    <link rel="stylesheet" href="/site.css" />
  </head>
  <body>
    <main class="page narrow">
      <header class="topbar">
        ${renderBranding(branding, 'header')}
        <nav class="topnav">
          <a class="nav-link" href="/">소개</a>
          <a class="nav-link" href="/privacy">개인정보</a>
          <a class="nav-link" href="/support">지원</a>
        </nav>
      </header>
      <section class="card legal">
        <div class="eyebrow">${escapeHtml(branding.logoText || 'Cartly')}</div>
        <h1>${escapeHtml(publicSite.privacyTitle)}</h1>
        <p>${escapeHtml(publicSite.privacyIntro)}</p>
        <h2>${escapeHtml(publicSite.privacyCollectionTitle)}</h2>
        <ul class="bullet-list">${renderBulletList(publicSite.privacyCollectionPoints)}</ul>
        <h2>${escapeHtml(publicSite.privacyExternalTitle)}</h2>
        <p>${escapeHtml(publicSite.privacyExternalBody)}</p>
        <h2>${escapeHtml(publicSite.privacyStatusTitle)}</h2>
        <p>${escapeHtml(publicSite.privacyStatusBody)}</p>
        <h2>문의</h2>
        <p>지원 문의: <a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a></p>
        <p>비즈니스 제안: <a href="mailto:${escapeHtml(businessEmail)}">${escapeHtml(businessEmail)}</a></p>
        <p><a class="button secondary" href="/">${escapeHtml(publicSite.privacyBackAction)}</a></p>
      </section>
    </main>
  </body>
</html>`
}

function buildSupportHtml(config) {
  const { branding } = config
  return `<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(branding.logoText || 'Cartly')} Support</title>
    <link rel="stylesheet" href="/site.css" />
  </head>
  <body>
    <main class="page narrow">
      <header class="topbar">
        ${renderBranding(branding, 'header')}
        <nav class="topnav">
          <a class="nav-link" href="/">소개</a>
          <a class="nav-link" href="/privacy">개인정보</a>
          <a class="nav-link" href="/support">지원</a>
        </nav>
      </header>
      <section class="card legal">
        <div class="eyebrow">${escapeHtml(branding.logoText || 'Cartly')}</div>
        <h1>지원 안내</h1>
        <p>계정, 로그인, 개인정보, 서비스 사용 관련 문의를 이메일로 받고 있습니다.</p>
        <p><strong>고객 지원 · <a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a></strong></p>
        <p><strong>비즈니스 제안 · <a href="mailto:${escapeHtml(businessEmail)}">${escapeHtml(businessEmail)}</a></strong></p>
        <p>제품 범위나 외부 링크 동작에 대한 질문도 같은 주소로 받을 수 있습니다.</p>
        <p><a class="button secondary" href="/">메인 페이지로 돌아가기</a></p>
      </section>
    </main>
  </body>
</html>`
}

async function tryServePublicSite(pathname, res, method) {
  if (dynamicLandingRoutes.has(pathname) || dynamicPrivacyRoutes.has(pathname) || dynamicSupportRoutes.has(pathname)) {
    const config = await fetchAppConfig()
    const html = dynamicLandingRoutes.has(pathname)
      ? buildLandingHtml(config)
      : dynamicPrivacyRoutes.has(pathname)
        ? buildPrivacyHtml(config)
        : buildSupportHtml(config)
    const body = Buffer.from(html)
    res.writeHead(200, {
      'content-type': 'text/html; charset=utf-8',
      'content-length': String(body.length),
      'cache-control': 'no-cache',
    })
    if (method === 'HEAD') {
      res.end()
      return true
    }
    res.end(body)
    return true
  }

  const filePath = publicAssetRoutes.get(pathname)
  if (!filePath) return false

  try {
    const body = await fs.readFile(filePath)
    res.writeHead(200, {
      'content-type': contentTypeFor(filePath),
      'content-length': String(body.length),
      'cache-control': pathname.startsWith('/site-media/') ? 'public, max-age=3600' : 'no-cache',
    })
    if (method === 'HEAD') {
      res.end()
      return true
    }
    res.end(body)
    return true
  } catch (error) {
    console.error('[app-public-proxy] public site read failure', error)
    writeJson(res, 500, {
      detail: {
        code: 'APP_PUBLIC_SITE_READ_FAILED',
        message: 'public landing asset를 읽지 못했어',
      },
    })
    return true
  }
}

function copyHeaders(req) {
  const headers = new Headers()
  const accept = req.headers.accept
  if (accept) headers.set('accept', Array.isArray(accept) ? accept.join(', ') : accept)

  const authorization = req.headers.authorization
  if (authorization) headers.set('authorization', Array.isArray(authorization) ? authorization.join(', ') : authorization)

  const contentType = req.headers['content-type']
  if (contentType) headers.set('content-type', Array.isArray(contentType) ? contentType.join(', ') : contentType)

  const userAgent = req.headers['user-agent']
  if (userAgent) headers.set('user-agent', Array.isArray(userAgent) ? userAgent.join(', ') : userAgent)

  const contentLength = req.headers['content-length']
  if (contentLength) headers.set('content-length', Array.isArray(contentLength) ? contentLength.join(', ') : contentLength)

  return headers
}

async function readBody(req) {
  if (req.method === 'GET' || req.method === 'HEAD') {
    return undefined
  }

  const chunks = []
  for await (const chunk of req) {
    chunks.push(chunk)
  }

  if (chunks.length === 0) {
    return undefined
  }

  return Buffer.concat(chunks)
}

function writeJson(res, statusCode, payload) {
  const body = Buffer.from(JSON.stringify(payload, null, 2))
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': String(body.length),
  })
  res.end(body)
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || `${host}:${port}`}`)
    if (await tryServePublicSite(url.pathname, res, req.method || 'GET')) {
      return
    }

    if (!isAllowedPath(url.pathname)) {
      return writeJson(res, 404, {
        detail: {
          code: 'APP_PUBLIC_ROUTE_NOT_FOUND',
          message: '허용되지 않은 public app route야',
        },
      })
    }

    const upstreamUrl = `${backendBase}${url.pathname}${url.search}`
    const upstream = await fetch(upstreamUrl, {
      method: req.method,
      headers: copyHeaders(req),
      body: await readBody(req),
    })

    const responseHeaders = {}
    const contentType = upstream.headers.get('content-type')
    if (contentType) responseHeaders['content-type'] = contentType

    const contentDisposition = upstream.headers.get('content-disposition')
    if (contentDisposition) responseHeaders['content-disposition'] = contentDisposition

    const cacheControl = upstream.headers.get('cache-control')
    if (cacheControl) responseHeaders['cache-control'] = cacheControl

    const body = Buffer.from(await upstream.arrayBuffer())
    responseHeaders['content-length'] = String(body.length)

    res.writeHead(upstream.status, responseHeaders)
    if (req.method === 'HEAD') {
      res.end()
      return
    }
    res.end(body)
  } catch (error) {
    console.error('[app-public-proxy] upstream failure', error)
    writeJson(res, 502, {
      detail: {
        code: 'APP_PUBLIC_UPSTREAM_UNAVAILABLE',
        message: 'public app API upstream에 연결하지 못했어',
      },
    })
  }
})

server.listen(port, host, () => {
  console.log(`[app-public-proxy] listening on http://${host}:${port} -> ${backendBase}`)
})
