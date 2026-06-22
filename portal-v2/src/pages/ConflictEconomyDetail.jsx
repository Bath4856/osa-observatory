import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getConflictEconomyHistory } from '../api/alerts'
import { useLang } from '../i18n/useLang'
import { RISK_COLOR, RISK_LABEL } from '../constants/risk'
import { GENECO_FACTORS, classifyVariation, generateGenecoSummary, generateGenecoResilience } from '../constants/genecoContent'
import './AmarDetail.css'

function readingText(lang, variationPct) {
  const trend = classifyVariation(variationPct)
  if (trend === 'STABLE') {
    return lang === 'fr'
      ? "La stabilité du niveau d'exposition sur la période observée suggère une situation globalement maîtrisée, sans aggravation notable du risque observé."
      : "The stability of the exposure level over the observed period suggests a generally controlled situation, with no notable worsening of the observed risk."
  }
  if (trend === 'STRONG_INCREASE' || trend === 'MODERATE_INCREASE') {
    return lang === 'fr'
      ? "L'évolution du niveau d'exposition sur la période observée traduit une dégradation progressive des dimensions suivies, justifiant une attention accrue."
      : "The evolution of the exposure level over the observed period reflects a progressive deterioration of the tracked dimensions, warranting increased attention."
  }
  return lang === 'fr'
    ? "L'évolution du niveau d'exposition sur la période observée traduit une amélioration progressive des dimensions suivies."
    : "The evolution of the exposure level over the observed period reflects a progressive improvement of the tracked dimensions."
}

export default function ConflictEconomyDetail() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const [history, setHistory] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    getConflictEconomyHistory(iso3)
      .then(d => setHistory(d))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error) return <div className="page-error">{t('common.error')}: {error}</div>

  const title = lang === 'fr' ? 'Économie de conflit' : 'Conflict economy'

  if (!history || history.length === 0) {
    return (
      <div className="amar-detail-page">
        <div className="amar-detail-header">
          <h1 className="amar-detail-title">{title} — {iso3}</h1>
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

  const summaryText = generateGenecoSummary({
    year: latest.year,
    country: iso3,
    band,
    variationPct,
    confidenceScore: latest.confidence_score,
    lang
  })
  const resilienceData = generateGenecoResilience({ band, variationPct, lang })

  return (
    <div className="amar-detail-page">
      <div className="amar-detail-header">
        <h1 className="amar-detail-title">{title} — {iso3}</h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      <div className="amar-block amar-block-about">
        <h2 className="amar-block-title">{lang === 'fr' ? 'À propos de Conflict Economy (GENECO)' : 'About Conflict Economy (GENECO)'}</h2>
        <p className="amar-block-text">
          {lang === 'fr'
            ? "Conflict Economy (GENECO) est le moteur d'analyse développé par l'Observatoire Africain de la Souveraineté (OSA) pour suivre les dynamiques économiques susceptibles d'alimenter ou de prolonger des situations de conflit — captation de ressources, facilitation logistique, captation institutionnelle, exploitation des populations civiles et instrumentalisation narrative. Il constitue un outil d'aide à l'analyse et ne remplace pas les évaluations réalisées par les autorités compétentes ou les organisations internationales."
            : "Conflict Economy (GENECO) is the analytical engine developed by the African Sovereignty Observatory (OSA) to track economic dynamics likely to fuel or prolong conflict situations — resource capture, logistics enabling, institutional capture, civilian exploitation, and narrative weaponization. It is a decision-support tool and does not replace assessments conducted by competent authorities or international organizations."}
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
        <h2 className="amar-block-title">{lang === 'fr' ? "Facteurs d'exposition suivis" : 'Monitored exposure factors'}</h2>
        <ul className="amar-factors-list">
          {GENECO_FACTORS[lang].map(f => <li key={f}>{f}</li>)}
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

      <p className="amar-disclaimer">
        {lang === 'fr'
          ? "Conflict Economy est un signal d'exposition économique et non un mécanisme d'attribution juridique, diplomatique ou judiciaire."
          : "Conflict Economy is an economic exposure signal and not a mechanism for legal, diplomatic, or judicial attribution."}
      </p>
    </div>
  )
}
