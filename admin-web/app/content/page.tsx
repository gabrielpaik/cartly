'use client'

import { useEffect, useState } from 'react'
import PageHeader from '../../components/PageHeader'
import { fetchJsonSafe, putJson } from '../../lib/api'
import { mockBranding } from '../../lib/mock'

type Branding = typeof mockBranding

export default function ContentPage() {
  const [form, setForm] = useState<Branding>(mockBranding)
  const [usingFallback, setUsingFallback] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    fetchJsonSafe<{ ok: boolean; data: Branding }>('/admin/branding', { ok: true, data: mockBranding }).then((res) => {
      setForm(res.data.data)
      setUsingFallback(res.usingFallback)
    })
  }, [])

  async function onSave() {
    setSaving(true)
    setMessage(null)
    try {
      await putJson('/admin/branding', form)
      setMessage('저장했어. 이제 앱은 이 값을 읽을 수 있는 구조로 맞춰가면 돼.')
      setUsingFallback(false)
    } catch (e) {
      setMessage('저장은 실패했어. backend 연결 상태를 다시 봐야 해.')
    } finally {
      setSaving(false)
    }
  }

  function field<K extends keyof Branding>(key: K, label: string, placeholder = '') {
    return (
      <label className="field" key={String(key)}>
        <div className="fieldLabel">{label}</div>
        <input
          className="textInput"
          value={form[key] ?? ''}
          placeholder={placeholder}
          onChange={(e) => setForm((prev) => ({ ...prev, [key]: e.target.value || null }))}
        />
      </label>
    )
  }

  return (
    <div>
      <PageHeader
        badge={usingFallback ? 'Fallback data' : 'Live data'}
        title="Content"
        description="앱 안 문구와 로고를 운영에서 직접 바꾸는 CMS 영역이야. 하드코딩 대신 설정값으로 관리하는 첫 단계야."
      />

      <div className="section sectionGrid twoCol">
        <div className="card">
          <h2 className="panelTitle">브랜딩</h2>
          <div className="formGrid">
            {field('logoType', '로고 타입', 'text 또는 image')}
            {field('logoText', '로고 텍스트')}
            {field('logoImageUrl', '로고 이미지 URL', 'https://... 또는 CDN 경로')}
            {field('homeSubtitle', 'Home subtitle')}
            {field('savedSubtitle', 'Saved subtitle')}
            {field('mySubtitle', 'My subtitle')}
            {field('loginSubtitle', 'Login subtitle')}
            {field('saveCompleteTitle', '저장 완료 제목')}
            {field('saveCompleteSubtitle', '저장 완료 부제')}
          </div>
          <div className="buttonRow">
            <button className="primaryBtn" disabled={saving} onClick={onSave}>
              {saving ? '저장 중...' : '브랜딩 저장'}
            </button>
            {message ? <div className="saveMessage">{message}</div> : null}
          </div>
        </div>

        <div className="card">
          <h2 className="panelTitle">미리보기 규칙</h2>
          <ul className="inlineList">
            <li><strong>logoType=text</strong> 이면 `logoText`를 쓴다.</li>
            <li><strong>logoType=image</strong> 이면 `logoImageUrl`를 쓴다.</li>
            <li>subtitle은 짧고 강하게 유지한다.</li>
            <li>홈/저장/내정보 문구는 admin에서 수시 수정 가능해야 한다.</li>
            <li>앱은 이 값을 런타임에 읽는 구조로 정리해간다.</li>
          </ul>
          <div className="metaRow">
            <div className="metaPill">logo: {form.logoType}</div>
            <div className="metaPill">home: {form.homeSubtitle}</div>
            <div className="metaPill">saved: {form.savedSubtitle}</div>
          </div>
        </div>
      </div>
    </div>
  )
}
