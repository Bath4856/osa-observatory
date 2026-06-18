const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getCountryScores(iso3) {
  const res = await fetch(`${API}/api/v2/scores/${iso3}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.history || []
}

export async function getCountryPillarScores(iso3) {
  const res = await fetch(`${API}/api/v2/sovereignty/swot?iso3=${iso3}`)
  if (!res.ok) throw new Error('pillar scores fetch failed')
  const data = await res.json()
  return Array.isArray(data) ? data : []
}

export async function getAllScores(year) {
  const res = await fetch(`${API}/api/v2/scores?year=${year || 2024}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.scores || []
}
