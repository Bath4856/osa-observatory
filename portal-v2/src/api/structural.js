// structural.js — Observations Souveraines Autonomes (POA)
const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function toArray(data) {
  if (Array.isArray(data)) return data
  if (Array.isArray(data?.data)) return data.data
  if (Array.isArray(data?.results)) return data.results
  if (data && typeof data === 'object') return [data]
  return []
}

// Observations POA pour un pays -- endpoint Sprint 28 Lot A
export async function getStructuralObs(iso3) {
  const res = await fetch(`${API}/api/v2/sovereignty/structural-obs/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}

// Catalogue des metadonnees POA (libelles, descriptions, tendances) --
// independant du pays, remplace la configuration en dur du portail
// (Sprint 31, rf.poa_catalog)
export async function getPoaCatalog() {
  const res = await fetch(`${API}/api/v2/sovereignty/poa-catalog`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}
