const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getCountryScores(iso3) {
  const res = await fetch(`${API}/api/v2/scores/${iso3}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.history || []
}

export async function getCountryPillarScores(iso3) {
  const res = await fetch(`${API}/opendata/pillars`)
  if (!res.ok) throw new Error('pillar scores fetch failed')
  const data = await res.json()
  const arr = Array.isArray(data) ? data : data.data || []
  return arr.filter(d => d.country_iso3 === iso3)
}

export async function getAllScores(year) {
  const res = await fetch(`${API}/api/v2/scores?year=${year || 2024}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.scores || []
}

export async function getCountryHistory(iso3) {
  const res = await fetch(`${API}/opendata/countries/history`)
  if (!res.ok) throw new Error('history fetch failed')
  const data = await res.json()
  const arr = Array.isArray(data) ? data : data.data || []
  return arr.filter(d => d.country_iso3 === iso3)
}
