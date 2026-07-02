// alerts.js -- AMAR + GENECO via vues materialisees (2020-2024)
// Performance : ~40ms par endpoint
const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function toArray(data) {
  if (Array.isArray(data)) return data
  if (Array.isArray(data?.data)) return data.data
  if (Array.isArray(data?.results)) return data.results
  if (data && typeof data === 'object') return [data]
  return []
}

// ── AMAR -- 6 facteurs -- pub.mv_amar_dashboard (2020-2024) ──────────────────
export async function getAmarHistory(iso3) {
  const res = await fetch(`${API}/api/v2/early-warning/amar/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}

// ── GENECO -- 5 facteurs -- pub.mv_geneco_dashboard (2020-2024) ──────────────
export async function getConflictEconomyHistory(iso3) {
  const res = await fetch(`${API}/api/v2/early-warning/geneco/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}

// ── Composite AMAR+GENECO -- mv_p7i_amar_composite_dashboard (ScoreTable) ────
export async function getCompositeHistory(iso3) {
  const res = await fetch(`${API}/api/v2/early-warning/composite/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}

// ── Adaptateurs ScoreTable -- badges annee par annee ─────────────────────────
// ScoreTable attend { year, risk_band } pour afficher les badges
export async function getAmarBadges(iso3) {
  const data = await getCompositeHistory(iso3)
  return data.map(d => ({
    year:      d.year,
    risk_band: d.atrocity_risk_band || d.amar_composite_band,
    risk_score: d.atrocity_precursor_score,
  }))
}

export async function getConflictBadges(iso3) {
  const data = await getCompositeHistory(iso3)
  return data.map(d => ({
    year:      d.year,
    risk_band: d.geneco_risk_band || d.amar_composite_band,
    risk_score: d.geneco_exposure_score,
  }))
}

// ── Compatibilite AlertDetail.jsx ─────────────────────────────────────────────
export async function getAmarAlert(iso3) {
  const rows = await getAmarHistory(iso3)
  if (!rows || rows.length === 0) return null
  return rows[0] // annee la plus recente
}

export async function getConflictEconomy(iso3) {
  const rows = await getConflictEconomyHistory(iso3)
  if (!rows || rows.length === 0) return null
  return rows[0] // annee la plus recente
}
