// scores.js
const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function toArray(data) {
  if (Array.isArray(data)) return data
  if (Array.isArray(data?.data)) return data.data
  if (Array.isArray(data?.results)) return data.results
  if (data && typeof data === 'object') return [data]
  return []
}

export async function getCountryScores(iso3) {
  const res = await fetch(`${API}/api/v2/scores/${iso3}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.history || []
}

export async function getCountryPillarScores(iso3) {
  const res = await fetch(`${API}/opendata/pillars/${iso3}`)
  if (!res.ok) throw new Error('pillar scores fetch failed')
  const data = await res.json()
  return toArray(data)
}

export async function getAllScores(year) {
  const res = await fetch(`${API}/api/v2/scores?year=${year || 2024}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.scores || []
}

export async function getCountryHistory(iso3) {
  const res = await fetch(`${API}/opendata/countries/history/${iso3}`)
  if (!res.ok) throw new Error('history fetch failed')
  const data = await res.json()
  return toArray(data)
}