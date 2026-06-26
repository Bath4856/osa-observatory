// alerts.js — AMAR + GENECO via endpoint composite (vue materialisee)
// Source : ma.mv_p7i_amar_composite_dashboard (~86ms vs ~48s pour les vues simples)
const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function toArray(data) {
  if (Array.isArray(data)) return data
  if (Array.isArray(data?.data)) return data.data
  if (Array.isArray(data?.results)) return data.results
  if (data && typeof data === 'object') return [data]
  return []
}

// Composite AMAR + GENECO -- vue materialisee, 54 pays x 2010-2024
// Contient : atrocity_precursor_score, geneco_exposure_score,
//            amar_composite_score, amar_composite_confidence,
//            atrocity_risk_band, geneco_risk_band, amar_composite_band,
//            resource_capture_risk, logistics_enabling_risk,
//            institutional_capture_risk, civilian_exploitation_risk,
//            narrative_weaponization_risk, composite_recommended_action
export async function getCompositeHistory(iso3) {
  const res = await fetch(`${API}/api/v2/early-warning/composite/${iso3}`)
  if (!res.ok) return []
  const data = await res.json()
  return toArray(data)
}

// Adaptateurs pour compatibilite avec ScoreTable et pages existantes
// ScoreTable attend { year, risk_band } pour AMAR et GENECO

export async function getAmarHistory(iso3) {
  const composite = await getCompositeHistory(iso3)
  return composite.map(d => ({
    year:           d.year,
    risk_band:      d.atrocity_risk_band || d.amar_composite_band,
    risk_score:     d.atrocity_precursor_score,
    confidence_score: d.amar_composite_confidence,
  }))
}

export async function getConflictEconomyHistory(iso3) {
  const composite = await getCompositeHistory(iso3)
  return composite.map(d => ({
    year:                         d.year,
    risk_band:                    d.geneco_risk_band || d.amar_composite_band,
    risk_score:                   d.geneco_exposure_score,
    confidence_score:             d.amar_composite_confidence,
    resource_capture_risk:        d.resource_capture_risk,
    logistics_enabling_risk:      d.logistics_enabling_risk,
    institutional_capture_risk:   d.institutional_capture_risk,
    civilian_exploitation_risk:   d.civilian_exploitation_risk,
    narrative_weaponization_risk: d.narrative_weaponization_risk,
    recommended_action:           d.composite_recommended_action,
  }))
}
