// osoa.js — Opportunités OSOA (osoa.opportunities)
// Source : /api/v2/osoa/opportunities

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getOpportunities(filters = {}) {
  const params = new URLSearchParams()
  if (filters.status) params.set('status', filters.status)
  if (filters.origin_type) params.set('origin_type', filters.origin_type)
  if (filters.participation_mode) params.set('participation_mode', filters.participation_mode)
  if (filters.country_iso3) params.set('country_iso3', filters.country_iso3)
  if (filters.principal_pillar_code) params.set('principal_pillar_code', filters.principal_pillar_code)
  const qs = params.toString()
  const res = await fetch(`${API}/api/v2/osoa/opportunities${qs ? '?' + qs : ''}`)
  if (!res.ok) return { count: 0, items: [], disclaimer: null }
  return await res.json()
}

export async function getOpportunity(id) {
  const res = await fetch(`${API}/api/v2/osoa/opportunities/${id}`)
  if (!res.ok) return null
  return await res.json()
}
