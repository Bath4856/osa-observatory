import { useEffect, useState } from 'react'
import { useParams, useSearchParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import { PILLAR_DATA } from '../data/pillarData'
import './Pillar.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

// Libellés bilingues -- jamais de score numérique affiché a l'usager (doctrine
// : le score sert uniquement au tri interne cote API, jamais a l'interface).
const SWOT_ROLE_LABEL = {
  THREAT_TO_MITIGATE:        { fr: 'Menace à atténuer',        en: 'Threat to mitigate' },
  WEAKNESS_TO_FIX:           { fr: 'Faiblesse à corriger',     en: 'Weakness to address' },
  OPPORTUNITY_TO_ACCELERATE: { fr: 'Opportunité à accélérer',  en: 'Opportunity to accelerate' },
  STRENGTH_TO_SCALE:         { fr: 'Force à consolider',       en: 'Strength to scale' },
}
const RECOMMENDATION_ACTION_LABEL = {
  MITIGATE_THREAT:        { fr: 'Atténuer la menace identifiée',        en: 'Mitigate the identified threat' },
  ATTENUATE_WEAKNESS:     { fr: 'Corriger la faiblesse identifiée',     en: 'Address the identified weakness' },
  ACCELERATE_OPPORTUNITY: { fr: 'Accélérer l\'opportunité identifiée',  en: 'Accelerate the identified opportunity' },
  SCALE_STRENGTH:         { fr: 'Consolider la force identifiée',      en: 'Scale the identified strength' },
  MONITOR_AND_DOCUMENT:   { fr: 'Surveiller et documenter',            en: 'Monitor and document' },
}
const PROJECT_ORIENTATION_LABEL = {
  ACCELERATION_PROJECT: { fr: "Projet d'accélération", en: 'Acceleration project' },
  ATTENUATION_PROJECT:  { fr: "Projet d'atténuation",  en: 'Attenuation project' },
  MONITORING_PROJECT:   { fr: 'Projet de suivi',        en: 'Monitoring project' },
}

export default function Pillar() {
  const { code } = useParams()
  const [searchParams] = useSearchParams()
  const iso3 = searchParams.get('country')
  const { t, lang } = useLang()
  const [indicators, setIndicators] = useState([])
  const [loadingInd, setLoadingInd] = useState(true)
  const [recommendation, setRecommendation] = useState(null)
  const [loadingReco, setLoadingReco] = useState(false)

  const pillar = PILLAR_DATA[code]

  useEffect(() => {
    if (!code) return
    setLoadingInd(true)
    fetch(`${API}/opendata/indicators/${code}`)
      .then(r => r.ok ? r.json() : null)
      .then(data => setIndicators(data?.indicators || []))
      .catch(() => setIndicators([]))
      .finally(() => setLoadingInd(false))
  }, [code])

  // Recommandation stratégique -- uniquement si un pays est en contexte
  // (navigation depuis la fiche pays). Sans pays, cette section n'a pas
  // de sens : un pilier seul n'a pas de diagnostic stratégique.
  useEffect(() => {
    if (!code || !iso3) {
      setRecommendation(null)
      return
    }
    setLoadingReco(true)
    fetch(`${API}/api/v2/sovereign-projects/recommendation/${iso3}/${code}?lang=${lang}`)
      .then(r => r.ok ? r.json() : null)
      .then(data => setRecommendation(data))
      .catch(() => setRecommendation(null))
      .finally(() => setLoadingReco(false))
  }, [code, iso3, lang])

  if (!pillar) return (
    <div className="pillar-page">
      <p>Pillar not found: {code}</p>
      <Link to="/pillars">{t('pillar.back')}</Link>
    </div>
  )

  const withData    = indicators.filter(i => i.has_data)
  const withoutData = indicators.filter(i => !i.has_data)

  return (
    <div className="pillar-page">
      <div className="pillar-header">
        <span className="pillar-code-badge">{code}</span>
        <h1 className="pillar-title">{pillar.name[lang]}</h1>
        <Link to="/pillars" className="back-link">{t('pillar.back')}</Link>
      </div>

      <section className="pillar-section">
        <h2>{t('pillar.definition')}</h2>
        <p>{pillar.definition[lang]}</p>
      </section>

      <section className="pillar-section">
        <h2>{t('pillar.indicators')}</h2>
        {loadingInd ? (
          <p style={{color:'var(--color-muted)', fontSize:'.9rem'}}>
            {lang === 'fr' ? 'Chargement...' : 'Loading...'}
          </p>
        ) : (
          <>
            {withData.length > 0 && (
              <>
                <p className="ind-section-label">
                  {lang === 'fr'
                    ? `${withData.length} indicateur${withData.length > 1 ? 's' : ''} avec données observées`
                    : `${withData.length} indicator${withData.length > 1 ? 's' : ''} with observed data`}
                </p>
                <div className="indicators-list">
                  {withData.map(ind => (
                    <span key={ind.code} className="indicator-tag indicator-tag--active" title={lang === 'fr' ? ind.name_fr : ind.name_en}>
                      {ind.code}
                    </span>
                  ))}
                </div>
              </>
            )}
            {withoutData.length > 0 && (
              <>
                <p className="ind-section-label ind-section-label--muted" style={{marginTop:'12px'}}>
                  {lang === 'fr'
                    ? `${withoutData.length} indicateur${withoutData.length > 1 ? 's' : ''} définis — collecte en cours`
                    : `${withoutData.length} indicator${withoutData.length > 1 ? 's' : ''} defined — collection in progress`}
                </p>
                <div className="indicators-list">
                  {withoutData.map(ind => (
                    <span key={ind.code} className="indicator-tag indicator-tag--pending" title={lang === 'fr' ? ind.name_fr : ind.name_en}>
                      {ind.code}
                    </span>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </section>

      {/* Analyse stratégique -> Diagnostic -> Recommandation -> Projet structurant
          Uniquement affichée si un pays est en contexte ET qu'un diagnostic
          existe reellement pour ce pays+pilier. Aucun score numerique n'est
          rendu -- le score sert uniquement au tri cote API (doctrine). */}
      {iso3 && (
        <section className="pillar-section">
          <h2>{lang === 'fr' ? 'Analyse stratégique' : 'Strategic analysis'}</h2>
          {loadingReco ? (
            <p style={{color:'var(--color-muted)', fontSize:'.9rem'}}>
              {lang === 'fr' ? 'Chargement...' : 'Loading...'}
            </p>
          ) : recommendation?.diagnosis ? (
            <div className="strategic-reco">
              <div className="reco-step">
                <span className="reco-step-label">
                  {lang === 'fr' ? 'Diagnostic stratégique' : 'Strategic diagnosis'}
                </span>
                <span className="reco-step-value">
                  {SWOT_ROLE_LABEL[recommendation.diagnosis.swot_strategic_role]?.[lang]
                    || (lang === 'fr' ? 'Non déterminé' : 'Not determined')}
                </span>
              </div>

              <div className="reco-step">
                <span className="reco-step-label">
                  {lang === 'fr' ? 'Recommandation stratégique' : 'Strategic recommendation'}
                </span>
                <span className="reco-step-value">
                  {RECOMMENDATION_ACTION_LABEL[recommendation.diagnosis.strategic_recommendation_action]?.[lang]
                    || recommendation.diagnosis.strategic_recommendation_action}
                </span>
              </div>

              {recommendation.recommended_project ? (
                <div className="reco-project">
                  <div className="reco-project-header">
                    <span className="reco-project-tag">
                      {PROJECT_ORIENTATION_LABEL[recommendation.diagnosis.project_orientation]?.[lang]
                        || (lang === 'fr' ? 'Projet structurant' : 'Structural project')}
                    </span>
                    <h3 className="reco-project-name">
                      {recommendation.recommended_project.project_name}
                      {recommendation.recommended_project.project_acronym &&
                        ` (${recommendation.recommended_project.project_acronym})`}
                    </h3>
                  </div>
                  <p className="reco-project-desc">
                    {recommendation.recommended_project.project_description}
                  </p>
                  <div className="reco-contribution">
                    <span className="reco-step-label">
                      {lang === 'fr' ? 'Contribution stratégique attendue' : 'Expected strategic contribution'}
                    </span>
                    <p className="reco-contribution-text">
                      {recommendation.recommended_project.deliverable_public}
                    </p>
                  </div>
                  <Link
                    to={`/country/${iso3}/projects?pillar=${code}`}
                    className="reco-projects-link"
                  >
                    {lang === 'fr' ? 'Voir tous les projets structurants du pilier →' : 'View all structural projects for this pillar →'}
                  </Link>
                </div>
              ) : (
                <p className="reco-no-project">
                  {lang === 'fr'
                    ? "Aucun projet structurant nommé n'est encore rattaché à ce pilier."
                    : 'No named structural project is attached to this pillar yet.'}
                </p>
              )}

              <p className="reco-disclaimer">
                {lang === 'fr'
                  ? "Ce projet est proposé parce que l'analyse stratégique identifie une pertinence sur ce pilier — il ne s'agit pas d'un impact chiffré sur l'ISA."
                  : 'This project is proposed because the strategic analysis identifies relevance to this pillar — it is not a quantified impact on the ISA.'}
              </p>
            </div>
          ) : (
            <p className="reco-no-project">
              {lang === 'fr'
                ? "Aucun diagnostic stratégique disponible pour ce pays sur ce pilier."
                : 'No strategic diagnosis available for this country on this pillar.'}
            </p>
          )}
          <Link
            to={`/country/${iso3}/vision/${code}`}
            className="reco-projects-link"
            style={{ marginTop: '12px', display: 'inline-block' }}
          >
            {lang === 'fr' ? 'Voir la vision stratégique OIM →' : 'View OIM strategic vision →'}
          </Link>
        </section>
      )}

      <section className="pillar-section">
        <h2>{t('pillar.sources')}</h2>
        <ul className="sources-list">
          {pillar.sources.map(src => <li key={src}>{src}</li>)}
        </ul>
      </section>

      <section className="pillar-section">
        <h2>{t('pillar.doctrine')}</h2>
        <p>{t('pillar.doctrine_text')}</p>
      </section>
    </div>
  )
}
