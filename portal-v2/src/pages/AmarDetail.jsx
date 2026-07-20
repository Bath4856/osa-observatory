import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getAmarFactorsHistory } from '../api/alerts'
import { useLang } from '../i18n/useLang'
import { RISK_COLOR, RISK_LABEL } from '../constants/risk'
import { classifyVariation, generateAmarSummary, generateAmarResilience } from '../constants/amarContent'
import './AmarDetail.css'

// Labels publics des 6 facteurs AMAR
const FACTOR_LABELS = {
  structural_fragility_score: {
    fr: 'Fragilités structurelles',
    en: 'Structural fragility',
    desc_fr: "Niveau de fragilité des structures étatiques et institutionnelles — capacité de l'État à exercer ses fonctions souveraines de base.",
    desc_en: "Level of fragility of state and institutional structures — the state's capacity to exercise its basic sovereign functions.",
  },
  conflict_escalation_score: {
    fr: 'Pressions sécuritaires',
    en: 'Security pressures',
    desc_fr: "Intensité des dynamiques de conflit armé, des tensions sécuritaires et des facteurs d'escalade observés sur le territoire.",
    desc_en: "Intensity of armed conflict dynamics, security tensions, and observed escalation factors on the territory.",
  },
  governance_breakdown_score: {
    fr: 'Dégradation de la gouvernance',
    en: 'Governance breakdown',
    desc_fr: "Degré de dysfonctionnement des mécanismes de gouvernance — défaillances institutionnelles, impunité, absence de redevabilité.",
    desc_en: "Degree of dysfunction in governance mechanisms — institutional failures, impunity, absence of accountability.",
  },
  humanitarian_stress_score: {
    fr: 'Stress humanitaire',
    en: 'Humanitarian stress',
    desc_fr: "Niveau de pression sur les populations civiles — déplacements, accès aux services essentiels, vulnérabilité humanitaire.",
    desc_en: "Level of pressure on civilian populations — displacements, access to essential services, humanitarian vulnerability.",
  },
  resource_conflict_score: {
    fr: 'Conflits de ressources',
    en: 'Resource conflicts',
    desc_fr: "Tensions liées à l'accès, au contrôle et à la distribution des ressources naturelles et économiques stratégiques.",
    desc_en: "Tensions related to access, control and distribution of strategic natural and economic resources.",
  },
  information_polarization_score: {
    fr: 'Polarisation de l\'information',
    en: 'Information polarization',
    desc_fr: "Degré de fragmentation et de polarisation de l'espace informationnel — désinformation, narratifs conflictuels, manipulation.",
    desc_en: "Degree of fragmentation and polarization of the information space — disinformation, conflicting narratives, manipulation.",
  },
}

const FACTOR_KEYS = [
  'structural_fragility_score',
  'conflict_escalation_score',
  'governance_breakdown_score',
  'humanitarian_stress_score',
  'resource_conflict_score',
  'information_polarization_score',
]

function getFactorColor(score) {
  if (score == null) return 'var(--color-muted)'
  if (score >= 0.6) return '#B00020'
  if (score >= 0.4) return '#7D4800'
  return 'var(--color-primary)'
}

function FactorBar({ score }) {
  const pct = score != null ? Math.round(score * 100) : null
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{
        flex: 1, height: 8, background: 'var(--color-border)',
        borderRadius: 4, overflow: 'hidden'
      }}>
        {pct != null && (
          <div style={{
            width: `${pct}%`, height: '100%',
            background: getFactorColor(score),
            borderRadius: 4, transition: 'width .3s'
          }} />
        )}
      </div>
      <span style={{
        fontSize: '.85rem', fontWeight: 600, minWidth: 36,
        color: getFactorColor(score)
      }}>
        {pct != null ? `${pct}%` : '—'}
      </span>
    </div>
  )
}

function readingText(lang, variationPct) {
  const trend = classifyVariation(variationPct)
  if (trend === 'STABLE') {
    return lang === 'fr'
      ? "La stabilité du niveau de vigilance sur la période observée suggère une situation globalement maîtrisée, sans aggravation notable du risque observé."
      : "The stability of the vigilance level over the observed period suggests a generally controlled situation, with no notable worsening of the observed risk."
  }
  if (trend === 'STRONG_INCREASE' || trend === 'MODERATE_INCREASE') {
    return lang === 'fr'
      ? "L'évolution du niveau de vigilance traduit une dégradation progressive des facteurs suivis, justifiant une attention accrue."
      : "The evolution of the vigilance level reflects a progressive deterioration of the tracked factors, warranting increased attention."
  }
  return lang === 'fr'
    ? "L'évolution du niveau de vigilance traduit une amélioration progressive des facteurs suivis."
    : "The evolution of the vigilance level reflects a progressive improvement of the tracked factors."
}

export default function AmarDetail() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const [history, setHistory] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    getAmarFactorsHistory(iso3)
      .then(d => setHistory(d))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error)   return <div className="page-error">{t('common.error')}: {error}</div>

  if (!history || history.length === 0) {
    return (
      <div className="amar-detail-page">
        <div className="amar-detail-header">
          <h1 className="amar-detail-title">AMAR — {iso3}</h1>
          <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
        </div>
        <p className="amar-detail-empty">
          {lang === 'fr' ? 'Aucune donnée disponible pour ce pays.' : 'No data available for this country.'}
        </p>
      </div>
    )
  }

  const sorted = [...history].sort((a, b) => a.year - b.year)
  const latest = sorted[sorted.length - 1]
  const first  = sorted[0]
  const variationPct = first.risk_score
    ? ((latest.risk_score - first.risk_score) / first.risk_score) * 100
    : 0
  const band = latest.risk_band

  const summaryText = generateAmarSummary({
    year: latest.year, country: iso3, band, variationPct,
    confidenceScore: latest.confidence_score, lang
  })
  const resilienceData = generateAmarResilience({ band, variationPct, lang })

  return (
    <div className="amar-detail-page">
      <div className="amar-detail-header">
        <h1 className="amar-detail-title">AMAR — {iso3}</h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      {/* À propos */}
      <div className="amar-block amar-block-about">
        <h2 className="amar-block-title">{lang === 'fr' ? "À propos d'AMAR" : 'About AMAR'}</h2>
        <p className="amar-block-text">
          {lang === 'fr'
            ? "AMAR (African Monitoring and Alert Radar) est le moteur d'alerte précoce de l'OSA. Il identifie des signaux faibles ou émergents susceptibles de nécessiter une attention particulière des décideurs et institutions. AMAR est un outil d'aide à l'analyse — il ne remplace pas les évaluations des autorités compétentes."
            : "AMAR (African Monitoring and Alert Radar) is the OSA early-warning engine. It identifies weak or emerging signals that may warrant particular attention from decision-makers and institutions. AMAR is a decision-support tool — it does not replace assessments by competent authorities."}
        </p>
      </div>

      {/* Situation actuelle */}
      <div className="amar-block amar-block-situation" style={{ borderColor: RISK_COLOR[band] || '#888' }}>
        <div className="amar-situation-top">
          <span className="risk-badge-lg" style={{ background: RISK_COLOR[band] || '#888' }}>
            {RISK_LABEL[lang]?.[band] || band}
          </span>
          <span className="amar-detail-year">{latest.year}</span>
        </div>
        <div className="amar-situation-metrics">
          <div className="metric">
            <span className="metric-label">{lang === 'fr' ? 'Score' : 'Score'}</span>
            <span className="metric-value">{latest.risk_score?.toFixed(3)}</span>
          </div>
          <div className="metric">
            <span className="metric-label">{lang === 'fr' ? 'Confiance' : 'Confidence'}</span>
            <span className="metric-value">{Math.round((latest.confidence_score || 0) * 100)}%</span>
          </div>
        </div>
        {latest.recommended_action && (
          <p style={{ marginTop: 12, fontSize: '.88rem', color: 'var(--color-muted)', fontStyle: 'italic' }}>
            {latest.recommended_action}
          </p>
        )}
      </div>

      {/* Résumé analytique */}
      {(summaryText || latest.public_narrative) && (
        <div className="amar-block">
          <h2 className="amar-block-title">{lang === 'fr' ? 'Résumé analytique' : 'Analytical summary'}</h2>
          <p className="amar-block-text">{summaryText || latest.public_narrative}</p>
        </div>
      )}

      {/* 6 Facteurs d'alerte -- données réelles */}
      <div className="amar-block">
        <h2 className="amar-block-title">
          {lang === 'fr' ? `Facteurs d'alerte observés — ${latest.year}` : `Observed alert factors — ${latest.year}`}
        </h2>
        <p className="amar-block-text" style={{ marginBottom: 20 }}>
          {lang === 'fr'
            ? "Six dimensions sont suivies pour documenter les dynamiques de vigilance souveraine. Ces facteurs sont issus de données primaires observées."
            : "Six dimensions are tracked to document sovereign vigilance dynamics. These factors are derived from observed primary data."}
        </p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {FACTOR_KEYS.map(key => {
            const lbl = FACTOR_LABELS[key]
            const score = latest[key]
            return (
              <div key={key} style={{
                padding: '14px 16px', background: 'var(--color-bg-light)',
                borderRadius: 6, borderLeft: `3px solid ${getFactorColor(score)}`
              }}>
                <div style={{ fontWeight: 700, color: 'var(--color-primary-dk)', fontSize: '.95rem', marginBottom: 8 }}>
                  {lbl[lang]}
                </div>
                <FactorBar score={score} />
                <p style={{ fontSize: '.82rem', color: 'var(--color-muted)', marginTop: 6, lineHeight: 1.5 }}>
                  {lbl[`desc_${lang}`]}
                </p>
              </div>
            )
          })}
        </div>
        <p style={{ fontSize: '.8rem', color: 'var(--color-muted)', marginTop: 14, fontStyle: 'italic' }}>
          {lang === 'fr'
            ? "Ces facteurs constituent un signal d'alerte précoce — ils ne désignent aucune responsabilité et ne constituent pas une qualification juridique."
            : "These factors constitute an early-warning signal — they assign no responsibility and do not constitute a legal qualification."}
        </p>
      </div>

      {/* Trajectoire 2020-2024 */}
      <div className="amar-block">
        <h2 className="amar-block-title">
          {lang === 'fr'
            ? `Trajectoire ${sorted[0].year}–${latest.year}`
            : `Trajectory ${sorted[0].year}–${latest.year}`}
        </h2>
        <table className="amar-trajectory-table">
          <thead>
            <tr>
              <th>{lang === 'fr' ? 'Année' : 'Year'}</th>
              <th>{lang === 'fr' ? 'Niveau' : 'Level'}</th>
              <th>{lang === 'fr' ? 'Score' : 'Score'}</th>
            </tr>
          </thead>
          <tbody>
            {sorted.map(row => (
              <tr key={row.year}>
                <td>{row.year}</td>
                <td>
                  <span className="risk-badge-sm" style={{ background: RISK_COLOR[row.risk_band] || '#888' }}>
                    {RISK_LABEL[lang]?.[row.risk_band] || row.risk_band}
                  </span>
                </td>
                <td>{row.risk_score?.toFixed(3)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="amar-variation">
          {lang === 'fr' ? 'Variation sur la période : ' : 'Variation over the period: '}
          <strong>{variationPct >= 0 ? '+' : ''}{variationPct.toFixed(1)}%</strong>
        </p>
        <p className="amar-block-text">{readingText(lang, variationPct)}</p>
      </div>

      {/* Résilience / vulnérabilité */}
      {resilienceData && (
        <div className="amar-block">
          <h2 className="amar-block-title">
            {lang === 'fr' ? 'Résilience et vulnérabilité' : 'Resilience and vulnerability'}
          </h2>
          <div className="amar-rv-grid">
            <div className="amar-rv-col amar-rv-resilience">
              <h3>{lang === 'fr' ? 'Facteurs de résilience' : 'Resilience factors'}</h3>
              <p>{resilienceData.resilience}</p>
            </div>
            <div className="amar-rv-col amar-rv-vulnerability">
              <h3>{lang === 'fr' ? 'Facteurs de vulnérabilité' : 'Vulnerability factors'}</h3>
              <p>{resilienceData.vulnerability}</p>
            </div>
          </div>
        </div>
      )}

      <p className="amar-disclaimer">
        {lang === 'fr'
          ? "AMAR est un outil d'alerte précoce et non un mécanisme de qualification juridique, diplomatique ou judiciaire."
          : "AMAR is an early-warning tool and not a mechanism for legal, diplomatic, or judicial qualification."}
      </p>
    </div>
  )
}
