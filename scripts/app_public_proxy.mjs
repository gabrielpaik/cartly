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
])
const dynamicLandingRoutes = new Set(['/', '/partners', '/partners/'])
const dynamicPrivacyRoutes = new Set(['/privacy', '/privacy/'])
const allowedPrefixes = [
  '/v1/auth/',
  '/v1/scan/',
  '/v1/carts/',
  '/v1/receipts/',
  '/v1/events/',
  '/v1/ads/',
  '/v1/push/',
  '/assets/branding/',
  '/assets/ads/',
]

const fallbackAppConfig = {
  branding: {
    logoType: 'text',
    logoText: 'Cartly',
    logoImageUrl: null,
    splashImageUrl: null,
    loginHeroImageUrl: null,
  },
  copy: {
    publicSite: {
      eyebrow: 'Cartly · private beta',
      heroTitle: '장보기를 기록하고, 같은 구매 의도 안에서 더 나은 선택을 찾는 앱',
      heroBody: 'Cartly는 스캔, 현재 카트, 저장된 장보기 기록을 바탕으로 사용자가 이미 사려던 상품과 같은 의도의 대체안을 다시 검토할 수 있게 도와줍니다.',
      primaryCtaLabel: '작동 방식 보기',
      secondaryCtaLabel: '개인정보 안내',
      heroPoints: '상품 스캔 및 검토\n현재 카트와 저장된 장보기 기록 관리\n같은 구매 의도(same-intent) 기준 대체안 탐색\n사용자 탭 이후에만 외부 파트너 링크 열기',
      enabledSections: 'hero,flow,status,partnerReview,linkPlacement',
      sectionOrder: 'hero,flow,status,partnerReview,linkPlacement',
      flowTitle: '사용자 흐름',
      flowBody: '아래 흐름은 실제 앱에서 파트너 오퍼가 어떻게 맥락 안에서 노출되는지 설명하기 위한 개요입니다.',
      statusTitle: '현재 운영 상태',
      statusPoints: 'iOS private beta(TestFlight) 운영 중\nOCR 스캔, 카트 저장, 반복 구매 맥락 정리 기능 포함\nExplore 탭은 same-intent alternative 중심으로 고도화 중',
      partnerReviewTitle: '파트너 검토 참고',
      partnerReviewPoints: '무작위 광고 피드가 아니라 장보기 의사결정 보조 흐름 안에 배치됩니다.\n사용자 액션 없이 외부 링크를 자동 실행하지 않습니다.\n제품 맥락과 구매 의도를 유지하는 대체안만 다룹니다.',
      linkPlacementTitle: '파트너 링크가 붙는 위치',
      linkPlacementBody: 'Cartly는 무관한 크로스셀 피드 대신, 사용자가 이미 사려던 상품과 같은 구매 의도를 유지하는 대체안만 Explore 영역에서 보여주도록 설계되어 있습니다.',
      linkPlacementPoints: '최근 스캔 후 아직 확정하지 않은 상품\n현재 카트에 담긴 핵심 구매 후보\n반복 구매 가능성이 높은 저장 카트 품목',
      privacyTitle: '개인정보 및 외부 링크 안내',
      privacyIntro: 'Cartly는 사용자가 직접 추가하거나 스캔한 장보기 상품 정보를 바탕으로 현재 카트, 저장된 장보기 기록, 그리고 같은 구매 의도를 유지하는 대체안 탐색 흐름을 제공합니다.',
      privacyCollectionTitle: '수집 및 사용',
      privacyCollectionPoints: '상품명, 가격, 수량, 저장 카트 제목 등 장보기 기록\n스캔 기능 사용 시 업로드한 이미지와 인식 결과\n앱 기능 개선과 사용자 경험 향상을 위한 최소 운영 로그',
      privacyExternalTitle: '외부 링크',
      privacyExternalBody: '외부 쇼핑 링크는 사용자가 Explore 영역에서 특정 대체안을 선택했을 때만 열립니다. 자동 리디렉션이나 무관한 광고성 이동을 기본 동작으로 사용하지 않습니다.',
      privacyStatusTitle: '현재 상태',
      privacyStatusBody: 'Cartly는 현재 private beta 단계에서 제품 흐름을 다듬고 있습니다. 파트너 링크는 같은 구매 의도 안에서의 대체안 검토를 돕는 용도로만 사용됩니다.',
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

function heroImageUrl(branding) {
  return branding.loginHeroImageUrl || branding.splashImageUrl || branding.logoImageUrl || '/site-media/intro.png'
}

function renderBranding(branding) {
  if (branding.logoType === 'image' && branding.logoImageUrl) {
    return `<img class="hero-brand-mark" src="${escapeHtml(branding.logoImageUrl)}" alt="${escapeHtml(branding.logoText || 'Cartly')}" />`
  }
  if (branding.logoType === 'text_image' && branding.logoImageUrl) {
    return `<div class="hero-brand-row"><img class="hero-brand-mark" src="${escapeHtml(branding.logoImageUrl)}" alt="${escapeHtml(branding.logoText || 'Cartly')}" /><span class="hero-brand-text">${escapeHtml(branding.logoText || 'Cartly')}</span></div>`
  }
  return `<div class="hero-brand-text">${escapeHtml(branding.logoText || 'Cartly')}</div>`
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

function renderLandingSection(sectionId, publicSite) {
  if (sectionId === 'hero') {
    return ''
  }

  if (sectionId === 'flow') {
    return `<section class="grid two" id="section-flow">
        <article class="card">
          <h2>${escapeHtml(publicSite.flowTitle)}</h2>
          <p>${escapeHtml(publicSite.flowBody)}</p>
          <ol class="steps">
            <li><strong>Scan</strong> 상품을 촬영하거나 직접 추가합니다.</li>
            <li><strong>Review</strong> 인식 결과를 검토하고 현재 카트에 담습니다.</li>
            <li><strong>Explore</strong> 같은 상품군 안에서 다시 볼 후보와 대체안을 모읍니다.</li>
            <li><strong>Save</strong> 장보기 결과를 저장해 다음 구매 의사결정에 활용합니다.</li>
          </ol>
        </article>
      </section>`
  }

  if (sectionId === 'status') {
    return `<section class="grid two" id="section-status">
        <article class="card">
          <h2>${escapeHtml(publicSite.statusTitle)}</h2>
          <ul class="bullet-list">${renderBulletList(publicSite.statusPoints)}</ul>
        </article>
      </section>`
  }

  if (sectionId === 'partnerReview') {
    return `<section class="grid two" id="section-partner-review">
        <article class="card emphasis">
          <h2>${escapeHtml(publicSite.partnerReviewTitle)}</h2>
          <ul class="bullet-list">${renderBulletList(publicSite.partnerReviewPoints)}</ul>
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
      </section>`
  }

  return ''
}

function buildLandingHtml(config) {
  const { branding, publicSite } = config
  const sectionPlan = buildLandingSectionPlan(publicSite)
  const showHero = sectionPlan.includes('hero')
  const firstContentSection = sectionPlan.find((sectionId) => sectionId !== 'hero')
  const primaryCtaTarget = firstContentSection ? `#section-${firstContentSection === 'partnerReview' ? 'partner-review' : firstContentSection === 'linkPlacement' ? 'link-placement' : firstContentSection}` : '/privacy'
  const renderedSections = sectionPlan.map((sectionId) => renderLandingSection(sectionId, publicSite)).join('\n')
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
      ${showHero ? `<section class="hero" id="section-hero">
        <div class="hero-copy">
          <div class="eyebrow">${escapeHtml(publicSite.eyebrow)}</div>
          ${renderBranding(branding)}
          <h1>${escapeHtml(publicSite.heroTitle)}</h1>
          <p class="lede">${escapeHtml(publicSite.heroBody)}</p>
          <div class="cta-row">
            <a class="button primary" href="${escapeHtml(primaryCtaTarget)}">${escapeHtml(publicSite.primaryCtaLabel)}</a>
            <a class="button secondary" href="/privacy">${escapeHtml(publicSite.secondaryCtaLabel)}</a>
          </div>
          <ul class="hero-points">${renderBulletList(publicSite.heroPoints)}</ul>
        </div>
        <div class="hero-visual card">
          <img src="${escapeHtml(heroImageUrl(branding))}" alt="${escapeHtml(branding.logoText || 'Cartly')} grocery shopping visual" />
          <div class="caption">현재는 iOS private beta 기반으로 제품 흐름을 다듬고 있습니다.</div>
        </div>
      </section>` : ''}

      ${renderedSections}

      <footer class="footer">
        <div>
          <strong>${escapeHtml(branding.logoText || 'Cartly')}</strong>
          <span>smart grocery planning and same-intent alternative discovery</span>
        </div>
        <div class="footer-note">파트너 검토 및 서비스 문의는 계정 등록 채널을 통해 응답합니다.</div>
      </footer>
    </main>
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
        <p><a class="button secondary" href="/">${escapeHtml(publicSite.privacyBackAction)}</a></p>
      </section>
    </main>
  </body>
</html>`
}

async function tryServePublicSite(pathname, res, method) {
  if (dynamicLandingRoutes.has(pathname) || dynamicPrivacyRoutes.has(pathname)) {
    const config = await fetchAppConfig()
    const html = dynamicLandingRoutes.has(pathname) ? buildLandingHtml(config) : buildPrivacyHtml(config)
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
      'cache-control': pathname === '/site-media/intro.png' ? 'public, max-age=3600' : 'no-cache',
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
