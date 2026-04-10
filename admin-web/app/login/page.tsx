import LoginScreen from '../../components/LoginScreen'

export default async function LoginPage({
  searchParams,
}: {
  searchParams?: Promise<{ reason?: string; next?: string }>
}) {
  const params = (await searchParams) ?? {}

  return <LoginScreen nextPath={params.next} reason={params.reason} />
}
