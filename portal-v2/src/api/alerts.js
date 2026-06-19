const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getAmarAlert(iso3) {
  const res = await fetch(`${API}/opendata/alerts/amar`)
  if (!res.ok) return null
  const data = await res.json()
  const arr = Array.isArray(data) ? data : data.data || []
  return arr.find(d => d.country_iso3 === iso3 && d.year === 2024) || null
}

export async function getConflictEconomy(iso3) {
  const res = await fetch(`${API}/api/v2/early-warning/conflict-economy?iso3=${iso3}`)
  if (!res.ok) return null
  const data = await res.json()
  const arr = Array.isArray(data) ? data : []
  return arr.find(d => d.country_iso3 === iso3) || null
}
