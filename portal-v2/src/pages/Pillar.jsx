import { useEffect, useState } from 'react'
import { useParams, useSearchParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import { PILLAR_DATA } from '../data/pillarData'
import { getVisions, getVisionDeliverables } from '../api/oim'
import './Pillar.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

const STATUS_LABEL = {
  DRAFT:     { fr: 'Brouillon', en: 'Draft' },
  VALIDATED: { fr: 'Validée',   en: 'Validated' },
  ARCHIVED:  { fr: 'Archivée',  en: 'Archived' },
}

export default function Pillar() {
  const { code } = useParams()
  const [searchParams] = useSearchParams()
  const iso3 = searchParams.get('country')
  const { t, lang } = useLang()
  const [indicators, setIndicators] = useState([])
  const [loadingInd, setLoadingInd] = useState(true)
  const [vision, setVision] = useState(null)
  const [deliverables, setDeliverables] = useState(null)
  const [loadingVision, setLoadingVision] = useState(false)

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

  // Vision stratégique OIM -- uniquement si un pays est en contexte
  // (navigation depuis la fiche pays). Integree directement (plus de
  // page separee -- decision du 2 aout 2026, evite le doublon de
  // navigation entre Pillar.jsx et une VisionDetail.jsx desormais retiree).
  useEffect(() => {
    if (!code || !iso3) {
      setVision(null)
      setDeliverables(null)
      return
    }
    setLoadingVision(true)
    getVisions({ country_iso3: iso3, pillar_code: code })
      .then(async (d) => {
        const latest = d.items?.[0] || null
        setVision(latest)
        if (latest) {
          const del = await getVisionDeliverables(latest.id)
          setDeliverables(del.items || [])
        } else {
          setDeliverables([])
        }
      })
      .catch(() => { setVision(null); setDeliverables([]) })
      .finally(() => setLoadingVision(false))
  }, [code, iso3])

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
        <span className="pillar-code-badge">
          {code} · {lang === 'fr' ? 'Pilier ISA' : 'ISA Pillar'}
        </span>
        <h1 className="pillar-title">{pillar.name[lang]}</h1>
        <Link to={iso3 ? `/country/${iso3}` : '/pillars'} className="back-link">
          {iso3 ? (lang === 'fr' ? '← Retour au pays' : '← Back to country') : t('pillar.back')}
        </Link>
      </div>

      {/* Opportunite strategique -- affichee EN PREMIER quand un pays est
          en contexte (decision du 2 aout 2026) : l'utilisateur qui arrive
          ici depuis la fiche pays a deja choisi ce pilier, il cherche la
          suite, pas une reintroduction. Aucun score numerique rendu (doctrine). */}
      {iso3 && (
        <section className="pillar-section">
          <h2>{lang === 'fr' ? 'Opportunité stratégique' : 'Strategic opportunity'}</h2>
          {loadingVision ? (
            <p style={{color:'var(--color-muted)', fontSize:'.9rem'}}>
              {lang === 'fr' ? 'Chargement...' : 'Loading...'}
            </p>
          ) : !vision ? (
            <p className="reco-no-project">
              {lang === 'fr'
                ? "Aucune vision stratégique disponible pour ce pays et ce pilier."
                : 'No strategic vision available for this country and pillar.'}
            </p>
          ) : (
            <>
              <div className="vision-detail-meta">
                <span className="vision-detail-year">{vision.year}</span>
              </div>
              {(() => {
                const etudeOpportunite = deliverables?.find(d => d.deliverable_type === 'ETUDE_OPPORTUNITE')
                const hasValidatedSummary = etudeOpportunite?.summary_status === 'HUMAN_VALIDATED'
                return hasValidatedSummary ? (
                  <p className="vision-detail-summary">
                    {lang === 'fr' ? etudeOpportunite.public_summary_fr : etudeOpportunite.public_summary_en}
                  </p>
                ) : (
                  <p className="vision-detail-pending">
                    {lang === 'fr'
                      ? "Cette étude est en cours de rédaction et n'a pas encore été validée pour publication."
                      : 'This study is currently being drafted and has not yet been validated for publication.'}
                  </p>
                )
              })()}
              <div className="vision-detail-premium-grid" style={{ marginTop: '16px' }}>
                <div className="vision-detail-premium-card">
                  <h3>{lang === 'fr' ? 'Schéma directeur' : 'Master plan'}</h3>
                  <p>{lang === 'fr' ? 'Architecture cible et gouvernance détaillées.' : 'Detailed target architecture and governance.'}</p>
                  <span className="vision-detail-premium-tag">
                    {lang === 'fr' ? 'Disponible sur demande institutionnelle' : 'Available on institutional request'}
                  </span>
                </div>
                <div className="vision-detail-premium-card">
                  <h3>{lang === 'fr' ? "Plan d'actions" : 'Action plan'}</h3>
                  <p>{lang === 'fr' ? 'Actions concrètes et projets dérivés.' : 'Concrete actions and derived projects.'}</p>
                  <span className="vision-detail-premium-tag">
                    {lang === 'fr' ? 'Disponible sur demande institutionnelle' : 'Available on institutional request'}
                  </span>
                </div>
              </div>
            </>
          )}
        </section>
      )}

      {/* Definition -- reservee a la navigation methodologique pure (sans
          pays en contexte). Redondante pour qui arrive deja cible sur
          l'opportunite d'un pays (decision du 2 aout 2026). */}
      {!iso3 && (
        <section className="pillar-section">
          <h2>{t('pillar.definition')}</h2>
          <p>{pillar.definition[lang]}</p>
        </section>
      )}

      <section className="pillar-section">
        <h2>{t('pillar.indicators')}</h2>
        {loadingInd ? (
          <p style={{color:'var(--color-muted)', fontSize:'.9rem'}}>
            {lang === 'fr' ? 'Chargement...' : 'Loading...'}
          </p>
        ) : iso3 ? (
          // Contexte opportunite strategique -- seulement les indicateurs
          // avec donnees reelles (jamais "a collecter", donne un gout
          // d'inacheve juste apres avoir invite a commander une intervention).
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
          </>
        ) : (
          // Contexte methodologique pur (page pilier sans pays) -- TOUS les
          // indicateurs OSA du pilier, decrits, y compris ceux en collecte.
          <div className="indicators-detailed-list">
            {indicators.map(ind => (
              <div key={ind.code} className="indicator-detail-row">
                <div className="indicator-detail-header">
                  <span className="indicator-detail-code">{ind.code}</span>
                  <span className="indicator-detail-name">{lang === 'fr' ? ind.name_fr : ind.name_en}</span>
                  {!ind.has_data && (
                    <span className="indicator-detail-pending-tag">
                      {lang === 'fr' ? 'Collecte en cours' : 'Collection in progress'}
                    </span>
                  )}
                </div>
                {ind.description && (
                  <p className="indicator-detail-description">{ind.description}</p>
                )}
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="pillar-section">
        <h2>{t('pillar.sources')}</h2>
        <ul className="sources-list">
          {pillar.sources.map(src => <li key={src}>{src}</li>)}
        </ul>
      </section>

      {!iso3 && (
        <section className="pillar-section">
          <h2>{t('pillar.doctrine')}</h2>
          <p>{t('pillar.doctrine_text')}</p>
        </section>
      )}
    </div>
  )
}
