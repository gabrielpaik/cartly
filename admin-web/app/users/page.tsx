import PageHeader from '../../components/PageHeader'
import StatCard from '../../components/StatCard'
import { fetchJsonSafe } from '../../lib/api'
import { formatDate } from '../../lib/format'
import { mockUsers } from '../../lib/mock'

type UserRow = {
  id: string
  displayName: string
  email: string | null
  provider: string
  isGuest: boolean
  createdAt: string | null
  lastSeenAt: string | null
}

export default async function UsersPage() {
  const res = await fetchJsonSafe<{ ok: boolean; data: { users: UserRow[] } }>('/admin/users', {
    ok: true,
    data: { users: mockUsers },
  })
  const users = res.data.data.users
  const guests = users.filter((u) => u.isGuest).length
  const members = users.length - guests

  return (
    <div>
      <PageHeader
        badge={res.usingFallback ? 'Fallback data' : 'Live data'}
        title="Users"
        description="게스트, 멤버, 최근 활동 사용자를 빠르게 보고 전환 상태를 점검하는 운영 화면이야."
      />

      <div className="kpiGrid">
        <StatCard label="Visible users" value={`${users.length}`} note="현재 화면에 표시된 사용자 수" />
        <StatCard label="Guests" value={`${guests}`} note="즉시 가치 확인 중심의 top-of-funnel 사용자" />
        <StatCard label="Members" value={`${members}`} note="저장/히스토리 가치를 이해하고 전환한 사용자" />
        <StatCard label="Goal" value="Convert" note="로그인 강요가 아니라 가치 인지 후 전환이 핵심이야" />
      </div>

      <div className="section">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Provider</th>
              <th>Type</th>
              <th>Created</th>
              <th>Last Seen</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td style={{ fontWeight: 700 }}>{u.displayName}</td>
                <td>{u.email ?? '-'}</td>
                <td>{u.provider}</td>
                <td>
                  <span className={`badge ${u.isGuest ? 'blue' : 'green'}`}>{u.isGuest ? 'guest' : 'member'}</span>
                </td>
                <td>{formatDate(u.createdAt)}</td>
                <td>{formatDate(u.lastSeenAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
