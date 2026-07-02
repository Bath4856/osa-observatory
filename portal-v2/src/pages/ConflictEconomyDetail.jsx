import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getConflictEconomyHistory } from '../api/alerts'
import { useLang } from '../i18n/useLang'
import { RISK_COLOR, RISK_LABEL } from '../constants/risk'
import { classifyVariation, generateGenecoSummary, generateGenecoResilience } from '../constants/genecoContent'
import './AmarDetail.css'

// Labels publics des 5 facteurs GENECO
const FACTOR_LABELS = {
  resource_capture_risk: {
    fr: 'Captation de ressources',
    en: 'Resource capture',
    desc_fr: "Degré d'appropriation des ressources naturelles par des acteurs économiques liés à des dynamiques conflictuelles.",
    desc_en: "Degree of appropriation of natural resources by economic actors linked to conflict dynamics.",
  },
  logistics_enabling_risk: {
    fr: 'Facilitation logistique',
    en: 'Logistics enabling',
    desc_fr: "Présence de réseaux de transport, de stockage ou de transit facilitant les flux économiques liés au conflit.",
    desc_en: "Presence of transport, storage or transit networks facilitating conflict-related economic flows.",
  },
  institutional_capture_risk: {
    fr: 'Captation institutionnelle',
    en: 'Institutional capture',
    desc_fr: "Détournement des structures étatiques ou réglementaires au profit d'intérêts économiques liés au conflit.",
    desc_en: "Diversion of state or regulatory structures to the benefit of conflict-related economic interests.",
  },
  civilian_exploitation_risk: {
    fr: 'Exploitation civile',
    en: 'Civilian exploitation',
    desc_fr: "Utilisation économique des populations civiles — travail forcé, taxation illicite, extorsion — dans un contexte de conflit.",
    desc_en: "Economic use of civilian populations — forced labor, illicit taxation, extortion — in a conflict context.",
  },
  narrative_weaponization_risk: {
    fr: 'Instrumentalisation narrative',
    en: 'Narrative weaponization',
    desc_fr: "Manipulation de l'information économique pour légitimer, dissimuler ou amplifier des mécanismes de conflit économique.",
    desc_en: "Manipulation of economic information to legitimize, conceal or amplify conflict economy mechanisms.",
  },
}

const FACTOR_KEYS = [
  'resource_capture_risk',
  'logistics_enabling_risk',
  'institutional_capture_risk',
  'civilian_exploitation_risk',
  'narrative_weaponization_risk',
]

function getRiskColor(score) {
  if (score == null) return 'var(--color-muted)'
  if (score >= 0.6) return '#B00020'
  if (score >= 0.4) return '#7D4800'
  return 'var(--color-primary)'
}

function FactorBar({ score, lang }) {
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
            background: getRiskColor(score),
            borderRadius: 4, transition: 'width .3s'
          }} />
        )}
      </div>
      <span style={{
        fontSize: '.85rem', fontWeight: 600, minWidth: 36,
        color: getRiskColor(score)
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
      ? "La stabilité du niveau d'exposition sur la période observée suggère une situation globalement maîtrisée, sans aggravation notable du risque observé."
      : "The stability of the exposure level over the observed period suggests a generally controlled situation, with no notable worsening of the observed risk."
  }
  if (trend === 'STRONG_INCREASE' || trend === 'MODERATE_INCREASE') {
    return lang === 'fr'
      ? "L'évolution du niveau d'exposition traduit une dégradation progressive des mécanismes suivis, justifiant une attention accrue."
      : "The evolution of the exposure level reflects a progressive deterioration of the tracked mechanisms, warranting increased attention."
  }
  return lang === 'fr'
    ? "L'évolution du niveau d'exposition traduit une amélioration progressive des mécanismes suivis."
    : "The evolution of the exposure level reflects a progressive improvement of the tracked mechanisms."
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
  if (error)   return <div className="page-error">{t('common.error')}: {error}</div>

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
  const first  = sorted[0]
  const variationPct = first.risk_score
    ? ((latest.risk_score - first.risk_score) / first.risk_score) * 100
    : 0
  const band = latest.risk_band

  const summaryText = generateGenecoSummary({
    year: latest.year, country: iso3, band, variationPct,
    confidenceScore: latest.confidence_score, lang
  })
  const resilienceData = generateGenecoResilience({ band, variationPct, lang })

  return (
    <div className="amar-detail-page">
      <div className="amar-detail-header">
        <h1 className="amar-detail-title">{title} — {iso3}</h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      {/* À propos */}
      <div className="amar-block amar-block-about">
        <h2 className="amar-block-title">
          {lang === 'fr' ? 'À propos de l\'économie de conflit (GENECO)' : 'About Conflict Economy (GENECO)'}
        </h2>
        <p className="amar-block-text">
          {lang === 'fr'
            ? "GENECO détecte des configurations économiques susceptibles de fragiliser durablement l'exercice de la souveraineté dans un contexte de conflit. Il identifie des mécanismes — pas des responsabilités. Chaque configuration détectée documente une réalité observable dont l'analyse peut conduire à des décisions souveraines."
            : "GENECO detects economic configurations likely to durably undermine the exercise of sovereignty in a conflict context. It identifies mechanisms — not responsibilities. Each detected configuration documents an observable reality whose analysis can lead to sovereign decisions."}
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
            <span className="metric-label">{lang === 'fr' ? 'Exposition' : 'Exposure'}</span>
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
      {summaryText && (
        <div className="amar-block">
          <h2 className="amar-block-title">{lang === 'fr' ? 'Résumé analytique' : 'Analytical summary'}</h2>
          <p className="amar-block-text">{summaryText}</p>
        </div>
      )}

      {/* 5 Facteurs d'exposition -- données réelles */}
      <div className="amar-block">
        <h2 className="amar-block-title">
          {lang === 'fr' ? `Facteurs d'exposition observés — ${latest.year}` : `Observed exposure factors — ${latest.year}`}
        </h2>
        <p className="amar-block-text" style={{ marginBottom: 20 }}>
          {lang === 'fr'
            ? "Cinq dimensions économiques sont suivies pour documenter les mécanismes de conflit économique. Les valeurs sont issues de données primaires observées — elles documentent des configurations, pas des certitudes."
            : "Five economic dimensions are tracked to document conflict economy mechanisms. Values are derived from observed primary data — they document configurations, not certainties."}
        </p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {FACTOR_KEYS.map(key => {
            const lbl = FACTOR_LABELS[key]
            const score = latest[key]
            return (
              <div key={key} style={{ padding: '14px 16px', background: 'var(--color-bg-light)', borderRadius: 6, borderLeft: `3px solid ${getRiskColor(score)}` }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
                  <span style={{ fontWeight: 700, color: 'var(--color-primary-dk)', fontSize: '.95rem' }}>
                    {lbl[lang]}
                  </span>
                </div>
                <FactorBar score={score} lang={lang} />
                <p style={{ fontSize: '.82rem', color: 'var(--color-muted)', marginTop: 6, lineHeight: 1.5 }}>
                  {lbl[`desc_${lang}`]}
                </p>
              </div>
            )
          })}
        </div>
        <p style={{ fontSize: '.8rem', color: 'var(--color-muted)', marginTop: 14, fontStyle: 'italic' }}>
          {lang === 'fr'
            ? "Ces indicateurs ne constituent pas une attribution de responsabilité. Ils documentent des configurations économiques observables dans un contexte de conflit."
            : "These indicators do not constitute attribution of responsibility. They document observable economic configurations in a conflict context."}
        </p>
      </div>

      {/* Trajectoire */}
      <div className="amar-block">
        <h2 className="amar-block-title">
          {lang === 'fr'
            ? `Trajectoire d'exposition ${sorted[0].year}–${latest.year}`
            : `Exposure trajectory ${sorted[0].year}–${latest.year}`}
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
          ? "GENECO est un signal d'exposition économique dans un contexte de conflit. Il ne constitue pas un mécanisme d'attribution juridique, diplomatique ou judiciaire."
          : "GENECO is an economic exposure signal in a conflict context. It does not constitute a mechanism for legal, diplomatic, or judicial attribution."}
      </p>
    </div>
  )
}
