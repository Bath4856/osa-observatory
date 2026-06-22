import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getAmarHistory } from '../api/alerts'
import { useLang } from '../i18n/useLang'
import { RISK_COLOR, RISK_LABEL } from '../constants/risk'
import { AMAR_FACTORS, classifyVariation, generateAmarSummary, generateAmarResilience } from '../constants/amarContent'
import './AmarDetail.css'

function readingText(lang, variationPct) {
  const trend = classifyVariation(variationPct)
  if (trend === 'STABLE') {
    return lang === 'fr'
      ? "La stabilité du niveau de vigilance sur plusieurs années suggère une situation globalement maîtrisée, sans aggravation notable du risque observé."
      : "The stability of the vigilance level over several years suggests a generally controlled situation, with no notable worsening of the observed risk."
  }
  if (trend === 'STRONG_INCREASE' || trend === 'MODERATE_INCREASE') {
    return lang === 'fr'
      ? "L'évolution du niveau de vigilance sur la période observée traduit une dégradation progressive des facteurs suivis, justifiant une attention accrue."
      : "The evolution of the vigilance level over the observed period reflects a progressive deterioration of the tracked factors, warranting increased attention."
  }
  return lang === 'fr'
    ? "L'évolution du niveau de vigilance sur la période observée traduit une amélioration progressive des facteurs suivis."
    : "The evolution of the vigilance level over the observed period reflects a progressive improvement of the tracked factors."
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
    getAmarHistory(iso3)
      .then(d => setHistory(d))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error) return <div className="page-error">{t('common.error')}: {error}</div>
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
  const first = sorted[0]
  const variationPct = first.risk_score ? ((latest.risk_score - first.risk_score) / first.risk_score) * 100 : 0
  const band = latest.risk_band

  const summaryText = generateAmarSummary({
    year: latest.year,
    country: iso3,
    band,
    variationPct,
    confidenceScore: latest.confidence_score,
    lang
  })
  const resilienceData = generateAmarResilience({ band, variationPct, lang })

  return (
    <div className="amar-detail-page">
      <div className="amar-detail-header">
        <h1 className="amar-detail-title">AMAR — {iso3}</h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      <div className="amar-block amar-block-about">
        <h2 className="amar-block-title">{lang === 'fr' ? "À propos d'AMAR" : 'About AMAR'}</h2>
        <p className="amar-block-text">
          {lang === 'fr'
            ? "AMAR (African Monitoring and Alert Radar) est le moteur d'analyse et d'alerte précoce développé par l'Observatoire Africain de la Souveraineté (OSA). Son objectif est d'identifier des signaux faibles ou émergents susceptibles de nécessiter une attention particulière des chercheurs, décideurs publics et partenaires institutionnels. AMAR constitue un outil d'aide à l'analyse et ne remplace pas les évaluations réalisées par les autorités compétentes ou les organisations internationales."
            : "AMAR (African Monitoring and Alert Radar) is the early-warning analytical engine developed by the African Sovereignty Observatory (OSA). Its purpose is to identify weak or emerging signals that may warrant particular attention from researchers, policymakers, and institutional partners. AMAR is a decision-support tool and does not replace assessments conducted by competent authorities or international organizations."}
        </p>
      </div>

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
            <span className="metric-value">{Math.round(latest.confidence_score * 100)}%</span>
          </div>
        </div>
      </div>

      <div className="amar-block">
        <h2 className="amar-block-title">{lang === 'fr' ? 'Résumé analytique' : 'Analytical summary'}</h2>
        <p className="amar-block-text">{summaryText || latest.public_narrative}</p>
      </div>

      <div className="amar-block">
        <h2 className="amar-block-title">{lang === 'fr' ? "Facteurs d'alerte suivis" : 'Monitored alert factors'}</h2>
        <ul className="amar-factors-list">
          {AMAR_FACTORS[lang].map(f => <li key={f}>{f}</li>)}
        </ul>
        <p className="amar-factors-note">
          {lang === 'fr'
            ? "Les résultats publiés ne détaillent pas l'ensemble des variables utilisées par le moteur analytique."
            : "Published results do not detail all variables used by the analytical engine."}
        </p>
      </div>

      <div className="amar-block">
        <h2 className="amar-block-title">{lang === 'fr' ? `Trajectoire ${sorted[0].year}–${latest.year}` : `Trajectory ${sorted[0].year}–${latest.year}`}</h2>
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

      {resilienceData && (
        <div className="amar-block">
          <h2 className="amar-block-title">{lang === 'fr' ? 'Résilience et vulnérabilité' : 'Resilience and vulnerability'}</h2>
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

      <div className="amar-block">
        <h2 className="amar-block-title">{lang === 'fr' ? 'Lecture souveraine' : 'Sovereign reading'}</h2>
        <p className="amar-block-text">
          {lang === 'fr'
            ? "Les signaux observés ne remettent pas en cause la souveraineté nationale mais justifient un suivi continu de certaines vulnérabilités."
            : "Observed signals do not call national sovereignty into question but warrant continued monitoring of certain vulnerabilities."}
        </p>
      </div>

      <p className="amar-disclaimer">
        {lang === 'fr'
          ? "AMAR est un outil d'alerte précoce et non un mécanisme de qualification juridique, diplomatique ou judiciaire."
          : "AMAR is an early-warning tool and not a mechanism for legal, diplomatic, or judicial qualification."}
      </p>
    </div>
  )
}
