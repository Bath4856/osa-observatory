// oim.js — Vision stratégique OIM (mg.pillar_strategic_vision)
// Source : /api/v2/oim/visions

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getVisions(filters = {}) {
  const params = new URLSearchParams()
  if (filters.country_iso3) params.set('country_iso3', filters.country_iso3)
  if (filters.pillar_code) params.set('pillar_code', filters.pillar_code)
  if (filters.year) params.set('year', filters.year)
  if (filters.status) params.set('status', filters.status)
  const qs = params.toString()
  const res = await fetch(`${API}/api/v2/oim/visions${qs ? '?' + qs : ''}`)
  if (!res.ok) return { count: 0, items: [] }
  return await res.json()
}

export async function getVision(id) {
  const res = await fetch(`${API}/api/v2/oim/visions/${id}`)
  if (!res.ok) return null
  return await res.json()
}

export async function getVisionDeliverables(visionId) {
  const res = await fetch(`${API}/api/v2/oim/visions/${visionId}/deliverables`)
  if (!res.ok) return { count: 0, items: [] }
  return await res.json()
}
