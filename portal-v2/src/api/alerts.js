// alerts.js
const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function toArray(data) {
  if (Array.isArray(data)) return data
  if (Array.isArray(data?.data)) return data.data
  if (Array.isArray(data?.results)) return data.results
  if (data && typeof data === 'object') return [data]
  return []
}

// Historique AMAR (civilian protection), 2020-2024 -- perimetre doctrinal
// (le SWOT, intrant du moteur AMAR, n'existe pas avant 2020).
// Vue persistee mg.v_public_p7i_amar_alerts -- rapide.
export async function getAmarHistory(iso3) {
  const res = await fetch(`${API}/opendata/alerts/amar/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}

// Historique Conflict Economy (GENECO), 2020-2024 -- meme perimetre doctrinal.
// Vue persistee mg.v_public_p7i_amar_geneco_alerts -- rapide.
export async function getConflictEconomyHistory(iso3) {
  const res = await fetch(`${API}/opendata/alerts/geneco/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}
