const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getProjects(iso3, pillar) {
  const url = iso3
    ? `${API}/api/v2/sovereign-projects/country/${iso3}`
    : `${API}/api/v2/sovereign-projects`
  const params = pillar ? `?pillar=${pillar}` : ''
  const res = await fetch(`${url}${params}`)
  if (!res.ok) throw new Error('projects fetch failed')
  return res.json()
}
